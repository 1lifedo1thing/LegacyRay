#import "LRTunnel.h"
#import "LRDaemonClient.h"
#import "LRCatalog.h"
#import "LRActivityLog.h"
#import <fcntl.h>
#import <unistd.h>

NSString * const LRTunnelDidChangeNotification = @"LRTunnelDidChangeNotification";
NSString * const LRTunnelTickNotification = @"LRTunnelTickNotification";

/* springboard's vpn badge reads this file; the daemon writes it while it runs
   and the app clears it when a tunnel ends badly */
static void LRClearStatusBadge(void) {
    int fd = open("/var/mobile/Library/Preferences/com.legacyray.status.state",
                  O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd >= 0) {
        (void)write(fd, "0\n", 2);
        close(fd);
    }
}

@implementation LRTunnel
@synthesize state = _state, activeBackend = _activeBackend, uptime = _uptime,
            bytesUp = _bytesUp, bytesDown = _bytesDown, speedUp = _speedUp,
            speedDown = _speedDown, busy = _busy, lastError = _lastError;

+ (LRTunnel *)shared {
    static LRTunnel *tunnel = nil;
    if (!tunnel) tunnel = [[LRTunnel alloc] init];
    return tunnel;
}

- (id)init {
    if ((self = [super init])) {
        _state = LRTunnelOffline;
        _activeBackend = LRBackendServer;
    }
    return self;
}

- (void)dealloc {
    [_timer invalidate];
    [_timer release];
    [_lastError release];
    [super dealloc];
}

- (void)notifyChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:LRTunnelDidChangeNotification
                                                        object:self];
}

- (void)setState:(LRTunnelState)state {
    if (state == _state) return;
    LRTunnelState old = _state;
    _state = state;
    if (state == LRTunnelConnected && old != LRTunnelConnected) {
        _lastSampleTime = 0;
        _peakDown = 0;
        LRServer *sv = [[LRCatalog shared] selectedServer];
        LRLog(@"tunnel", @"connected%@", sv && _activeBackend == LRBackendServer
              ? [@" · " stringByAppendingString:[sv protocolSummary]] : @" · AmneziaWG");
    } else if (state == LRTunnelIdle && old == LRTunnelConnected) {
        LRLog(@"tunnel", @"disconnected");
    }
    if (state != LRTunnelConnected) {
        _speedUp = _speedDown = 0;
        _uptime = 0;
    }
    [self notifyChange];
}

#pragma mark polling

- (void)start {
    if (_timer) return;
    _timer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                                             selector:@selector(timerFired:)
                                             userInfo:nil repeats:YES] retain];
    [self pollNow];
}

- (void)stop {
    [_timer invalidate];
    [_timer release];
    _timer = nil;
}

- (void)timerFired:(NSTimer *)timer {
    [self pollNow];
    [[NSNotificationCenter defaultCenter] postNotificationName:LRTunnelTickNotification object:self];
}

- (LRTunnelState)stateFromName:(NSString *)name {
    if ([name isEqualToString:@"connected"]) return LRTunnelConnected;
    if ([name isEqualToString:@"connecting"]) return LRTunnelConnecting;
    if ([name isEqualToString:@"error"]) return LRTunnelError;
    return LRTunnelIdle;
}

- (void)applySampleUp:(uint64_t)up down:(uint64_t)down {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (_lastSampleTime > 0 && up >= _lastSampleUp && down >= _lastSampleDown) {
        double dt = now - _lastSampleTime;
        if (dt > 0.2) {
            double su = (double)(up - _lastSampleUp) / dt;
            double sd = (double)(down - _lastSampleDown) / dt;
            /* light smoothing so the needles settle instead of twitching */
            _speedUp = _speedUp * 0.35 + su * 0.65;
            _speedDown = _speedDown * 0.35 + sd * 0.65;
            if (_speedDown > _peakDown) _peakDown = _speedDown;
        }
    }
    _lastSampleTime = now;
    _lastSampleUp = up;
    _lastSampleDown = down;
    _bytesUp = up;
    _bytesDown = down;
}

- (void)pollNow {
    if (_polling) return;
    _polling = YES;
    if (_activeBackend == LRBackendAmneziaWG || [LRPrefs selectedBackend] == LRBackendAmneziaWG) {
        [[LRDaemonClient shared] awgStatus:^(NSString *status) {
            NSString *s = LRTrim(status);
            if ([s hasPrefix:@"connected"] || [s hasPrefix:@"connecting"]) {
                _polling = NO;
                _activeBackend = LRBackendAmneziaWG;
                if ([s hasPrefix:@"connected"] && _state != LRTunnelConnected) _uptimeBase = [NSDate timeIntervalSinceReferenceDate];
                if (!_busy) [self setState:[s hasPrefix:@"connected"] ? LRTunnelConnected
                                                                    : LRTunnelConnecting];
                return;
            }
            if (_activeBackend == LRBackendAmneziaWG) _activeBackend = LRBackendServer;
            [self pollDaemon];
        }];
        return;
    }
    [self pollDaemon];
}

- (void)pollDaemon {
    [[LRDaemonClient shared] status:^(NSString *stateName, long uptime, BOOL known,
                                      uint64_t up, uint64_t down) {
        _polling = NO;
        if (_busy) return;
        if (!stateName) {
            [self setState:LRTunnelOffline];
            return;
        }
        LRTunnelState st = [self stateFromName:stateName];
        if (st == LRTunnelConnected) {
            _uptime = uptime;
            _uptimeBase = [NSDate timeIntervalSinceReferenceDate] - uptime;
            if (known) [self applySampleUp:up down:down];
        }
        [self setState:st];
    }];
}

- (long)liveUptime {
    if (_state != LRTunnelConnected || _uptimeBase <= 0) return 0;
    return (long)([NSDate timeIntervalSinceReferenceDate] - _uptimeBase);
}

- (NSString *)stateTitle {
    switch (_state) {
        case LRTunnelOffline: return L(@"NO DAEMON");
        case LRTunnelIdle: return L(@"STANDBY");
        case LRTunnelConnecting: return L(@"TUNING...");
        case LRTunnelConnected: return L(@"CONNECTED");
        case LRTunnelError: return L(@"FAULT");
    }
    return @"";
}

#pragma mark control

- (BOOL)isOn {
    return _state == LRTunnelConnected || _state == LRTunnelConnecting;
}

- (void)setBusy:(BOOL)busy {
    _busy = busy;
    [self notifyChange];
}

- (void)failWith:(NSString *)reason {
    self.lastError = reason;
    if (reason) LRLogFail(@"tunnel", @"%@", reason);
    LRClearStatusBadge();
    _busy = NO;
    _state = LRTunnelIdle;
    [self setState:LRTunnelError];
}

- (void)toggle {
    if (_busy) return;
    if ([self isOn]) [self disconnect];
    else [self connect];
}

- (void)connect {
    if ([LRPrefs selectedBackend] == LRBackendAmneziaWG) {
        [self startAWG];
        return;
    }
    int idx = [LRCatalog shared].selectedIndex;
    if (idx < 0) {
        LRServer *first = [[LRCatalog shared] serverAfterSelected:0];
        if (!first) {
            [self failWith:L(@"No station selected. Import a server or a subscription first.")];
            return;
        }
        idx = first.index;
    }
    [self connectServerIndex:idx];
}

- (void)connectServerIndex:(int)index {
    if (_busy) return;
    self.lastError = nil;
    [LRPrefs setSelectedBackend:LRBackendServer];
    [LRCatalog shared].selectedIndex = index;
    _state = LRTunnelConnecting;
    [self setBusy:YES];
    LRDaemonClient *client = [LRDaemonClient shared];
    [client ensureDaemon:^(BOOL up, NSString *detail) {
        if (!up) {
            [self failWith:detail ? detail : L(@"The daemon is not running")];
            return;
        }
        /* amneziawg and the vless daemon both want the default route */
        [client stopAWG:^(NSString *stopReply) {
            NSString *stop = LRTrim(stopReply);
            if (!stop || [stop hasPrefix:@"error"]) {
                [self failWith:stop ? stop : @"could not stop amneziawg"];
                return;
            }
            _activeBackend = LRBackendServer;
            [client connectIndex:index reply:^(NSString *reply) {
                NSString *err = LRErrorFromReply(reply);
                NSString *finalState = LRStateFromReply(reply, NULL);
                BOOL stuck = [finalState isEqualToString:@"connecting"] && !err;
                if (!reply || stuck) {
                    /* a missing answer can leave routing half applied */
                    [client disconnect:^(NSString *r) {
                        [self failWith:L(@"Connection timed out")];
                    }];
                    return;
                }
                _busy = NO;
                if ([finalState isEqualToString:@"connected"]) {
                    _uptimeBase = [NSDate timeIntervalSinceReferenceDate];
                    [self setState:LRTunnelConnected];
                } else {
                    [self failWith:err ? err : L(@"The server did not accept the connection")];
                }
                [[LRCatalog shared] reload];
            }];
        }];
    }];
}

- (void)disconnect {
    if (_busy) return;
    [self setBusy:YES];
    LRDaemonClient *client = [LRDaemonClient shared];
    void (^finish)(void) = ^{
        _busy = NO;
        _activeBackend = LRBackendServer;
        self.lastError = nil;
        LRClearStatusBadge();
        [self setState:LRTunnelIdle];
        [self pollNow];
    };
    if (_activeBackend == LRBackendAmneziaWG) {
        [client stopAWG:^(NSString *status) { finish(); }];
        return;
    }
    [client disconnect:^(NSString *reply) { finish(); }];
}

- (void)seek:(NSInteger)step {
    if (_busy) return;
    LRServer *next = [[LRCatalog shared] serverAfterSelected:step];
    if (!next) return;
    [LRCatalog shared].selectedIndex = next.index;
    [self notifyChange];
    if ([self isOn] && _activeBackend == LRBackendServer) [self connectServerIndex:next.index];
}

- (void)startAWG {
    if (_busy) return;
    NSString *path = [LRPrefs awgProfilePath];
    if (![LRPrefs hasAWGProfile]) {
        [self failWith:L(@"No AmneziaWG profile is saved")];
        return;
    }
    [LRPrefs setSelectedBackend:LRBackendAmneziaWG];
    self.lastError = nil;
    _state = LRTunnelConnecting;
    [self setBusy:YES];
    LRDaemonClient *client = [LRDaemonClient shared];
    [client disconnect:^(NSString *reply) {
        [client startAWGAtPath:path reply:^(NSString *status) {
            NSString *s = LRTrim(status);
            if (!s || [s hasPrefix:@"error"]) {
                [self failWith:s ? s : @"could not start amneziawg"];
                return;
            }
            _activeBackend = LRBackendAmneziaWG;
            _busy = NO;
            [self setState:LRTunnelConnecting];
            LRLog(@"tunnel", @"amneziawg started");
            [self performSelector:@selector(pollNow) withObject:nil afterDelay:2.0];
        }];
    }];
}
@end
