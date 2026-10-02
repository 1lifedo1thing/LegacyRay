#import "LRStationScreen.h"
#import "LRCatalog.h"
#import "LRTunnel.h"
#import "LRPrefs.h"
#import "LRDaemonClient.h"
#import "LRActivityLog.h"
#import "LRAlert.h"
#import "LRToast.h"
#import "LRDraw.h"
#import "LRSimpleScreens.h"

@implementation LRStationScreen

- (id)initWithServer:(LRServer *)server {
    if ((self = [super init])) {
        _server = [server retain];
        _results = [[NSMutableDictionary alloc] init];
        _running = [[NSMutableSet alloc] init];
        self.title = [[LRCatalog shared] displayNameForServer:server];
    }
    return self;
}

- (void)dealloc {
    [_server release];
    [_results release];
    [_stages release];
    [_stagesMode release];
    [_running release];
    [super dealloc];
}

- (NSString *)checkDetail:(NSString *)mode {
    if ([_running containsObject:mode]) return L(@"checking...");
    NSString *r = [_results objectForKey:mode];
    return r ? r : L(@"Not checked");
}

- (void)runCheck:(NSString *)mode {
    if ([_running containsObject:mode]) return;
    [_running addObject:mode];
    [self reloadSections];
    __block LRStationScreen *me = self;
    [self retain];
    [[LRDaemonClient shared] checkIndex:_server.index mode:mode
                                 stages:^(NSArray *stages, int ms, NSString *error) {
        [me->_running removeObject:mode];
        [me->_results setObject:ms >= 0 ? [NSString stringWithFormat:@"%d ms", ms]
                                        : (error ? error : L(@"Failed")) forKey:mode];
        [me->_stages release];
        me->_stages = [stages retain];
        [me->_stagesMode release];
        me->_stagesMode = [mode copy];
        LRLog(@"ping", @"%@ check: %@", mode, ms >= 0 ? [NSString stringWithFormat:@"%d ms", ms] : @"failed");
        [me reloadSections];
        [me release];
    }];
}

- (NSArray *)buildSections {
    LRServer *sv = _server;
    __block LRStationScreen *me = self;
    LRCatalog *catalog = [LRCatalog shared];
    LRTunnel *tunnel = [LRTunnel shared];
    LRSection *sec = [catalog sectionForServer:sv];
    NSMutableArray *sections = [NSMutableArray array];

    LRRow *name = [LRRow value:L(@"Name") detail:[catalog displayNameForServer:sv] action:nil];
    name.flagCode = [sv countryCode];
    NSMutableArray *info = [NSMutableArray arrayWithObjects:name,
        [LRRow value:L(@"Protocol") detail:[sv.proto uppercaseString] action:nil],
        [LRRow value:L(@"Transport") detail:[sv.net uppercaseString] action:nil],
        [LRRow value:L(@"Security") detail:[sv.security uppercaseString] action:nil],
        [LRRow value:L(@"Address") detail:LRStealth(sv.host) action:nil],
        [LRRow value:L(@"Port") detail:[NSString stringWithFormat:@"%d", sv.port] action:nil], nil];
    if (sec) [info addObject:[LRRow value:L(@"Source") detail:sec.title action:nil]];
    if (!sv.supported) {
        LRRow *warn = [LRRow text:L(@"This build cannot dial this protocol on this device (hysteria2 needs the iOS 12+ core).")];
        [info addObject:warn];
    }
    [sections addObject:[LRSectionSpec header:L(@"Server") rows:info footer:nil]];

    NSArray *modes = [NSArray arrayWithObjects:@"tcp", @"handshake", @"proxy", nil];
    NSArray *names = [NSArray arrayWithObjects:L(@"TCP connect"), L(@"TLS / Reality handshake"),
                      L(@"Real delay (HTTP through the server)"), nil];
    NSMutableArray *checks = [NSMutableArray array];
    for (NSUInteger i = 0; i < [modes count]; ++i) {
        NSString *mode = [modes objectAtIndex:i];
        LRRow *r = [LRRow value:[names objectAtIndex:i] detail:[self checkDetail:mode]
                         action:^(LRRow *row, UIView *cell) { [me runCheck:mode]; }];
        r.chevron = NO;
        [checks addObject:r];
    }
    for (LRCheckStage *st in _stages) {
        LRRow *r = [LRRow value:[NSString stringWithFormat:@"  %@", st.name]
                         detail:[NSString stringWithFormat:@"%@ %d ms", st.ok ? @"✓" : @"✕", st.ms] action:nil];
        r.style = LRRowStyleMuted;
        r.detailColor = st.ok ? SKIN->good : SKIN->bad;
        [checks addObject:r];
    }
    [sections addObject:[LRSectionSpec header:L(@"Latency") rows:checks
                                       footer:L(@"Tap a line to measure. The real delay goes through the server to a test page.")]];

    NSMutableArray *actions = [NSMutableArray array];
    BOOL current = [LRPrefs selectedBackend] == LRBackendServer && catalog.selectedIndex == sv.index;
    BOOL live = current && tunnel.state == LRTunnelConnected;
    if (!live)
        [actions addObject:[LRRow button:[tunnel isOn] ? L(@"Switch to this server") : L(@"Connect")
                                   style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [LRPrefs setSelectedBackend:LRBackendServer];
            [[LRTunnel shared] connectServerIndex:sv.index];
            [me close];
        }]];
    if (!current)
        [actions addObject:[LRRow button:L(@"Tune in without connecting") style:LRRowStyleAccent
                                  action:^(LRRow *r, UIView *c) {
            [LRPrefs setSelectedBackend:LRBackendServer];
            [LRCatalog shared].selectedIndex = sv.index;
            [[NSNotificationCenter defaultCenter] postNotificationName:LRTunnelDidChangeNotification object:nil];
            [me reloadSections];
        }]];
    [actions addObject:[LRRow button:L(@"Copy link") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
        [[LRDaemonClient shared] serverLinkIndex:sv.index reply:^(NSString *link) {
            if (!link) { [LRToast showError:L(@"The link could not be read")]; return; }
            [UIPasteboard generalPasteboard].string = link;
            [LRToast showSuccess:L(@"Link copied")];
        }];
    }]];
    if (sv.group < 0) {
        [actions addObject:[LRRow button:L(@"Edit link") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [me editLink];
        }]];
        [actions addObject:[LRRow button:L(@"Delete") style:LRRowStyleDestructive action:^(LRRow *r, UIView *c) {
            [LRAlert confirmTitle:L(@"Delete Server") message:me.title button:L(@"Delete") destructive:YES action:^{
                [[LRDaemonClient shared] deleteServerIndex:sv.index reply:^(NSString *reply) {
                    [[LRCatalog shared] reload];
                    [me close];
                }];
            }];
        }]];
    }
    [sections addObject:[LRSectionSpec header:nil rows:actions footer:nil]];
    return sections;
}

- (void)editLink {
    int idx = _server.index;
    [[LRDaemonClient shared] serverLinkIndex:idx reply:^(NSString *link) {
        LRStationScreen *me = self;
        LRTextEditScreen *edit = [[[LRTextEditScreen alloc] initWithTitle:L(@"Edit link") text:link
                                                                     save:^(NSString *text, LRTextEditScreen *screen) {
            NSString *clean = LRTrim(text);
            if (!clean) return;
            [[LRDaemonClient shared] replaceServerIndex:idx link:clean reply:^(NSString *reply) {
                if (LRReplyIsOK(reply)) {
                    [LRToast showSuccess:L(@"Server saved")];
                    [[LRCatalog shared] reload];
                    [screen close];
                } else {
                    [LRToast showError:LRErrorFromReply(reply) ? LRErrorFromReply(reply) : L(@"Invalid configuration link")];
                }
            }];
        }] autorelease];
        [me openScreen:edit];
    }];
}
@end
