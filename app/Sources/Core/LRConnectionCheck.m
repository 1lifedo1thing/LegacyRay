#import "LRConnectionCheck.h"
#import "LRDaemonClient.h"
#import "LRDaemonSettings.h"
#import "LRNetInfo.h"
#import "LRTunnel.h"
#import "LRCatalog.h"
#import "LRActivityLog.h"
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <mach/mach_time.h>

static long LRNowMs(void) {
    static mach_timebase_info_data_t tb;
    if (!tb.denom) mach_timebase_info(&tb);
    return (long)((double)mach_absolute_time() * tb.numer / tb.denom / 1000000.0);
}

static void LRSocketTimeouts(int fd, int ms) {
    struct timeval tv = { ms / 1000, (ms % 1000) * 1000 };
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof tv);
    int on = 1;
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof on);
}

/* a tcp connect with a deadline; -1 and *err on failure */
static int LRConnect(const char *host, int port, int timeoutMs, NSString **err) {
    struct addrinfo hints, *res = NULL;
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    char portText[8];
    snprintf(portText, sizeof portText, "%d", port);
    if (getaddrinfo(host, portText, &hints, &res) != 0 || !res) {
        if (err) *err = @"name resolution failed";
        return -1;
    }
    int fd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (fd < 0) {
        freeaddrinfo(res);
        if (err) *err = @"no socket";
        return -1;
    }
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    int rc = connect(fd, res->ai_addr, res->ai_addrlen);
    freeaddrinfo(res);
    if (rc != 0 && errno != EINPROGRESS) {
        close(fd);
        if (err) *err = [NSString stringWithFormat:@"connect failed (%s)", strerror(errno)];
        return -1;
    }
    if (rc != 0) {
        fd_set w;
        FD_ZERO(&w);
        FD_SET(fd, &w);
        struct timeval tv = { timeoutMs / 1000, (timeoutMs % 1000) * 1000 };
        if (select(fd + 1, NULL, &w, NULL, &tv) <= 0) {
            close(fd);
            if (err) *err = @"connect timed out";
            return -1;
        }
        int soerr = 0;
        socklen_t len = sizeof soerr;
        getsockopt(fd, SOL_SOCKET, SO_ERROR, &soerr, &len);
        if (soerr) {
            close(fd);
            if (err) *err = [NSString stringWithFormat:@"connect failed (%s)", strerror(soerr)];
            return -1;
        }
    }
    fcntl(fd, F_SETFL, flags);
    LRSocketTimeouts(fd, timeoutMs);
    return fd;
}

static int LRSendAll(int fd, const void *buf, size_t len) {
    const char *p = buf;
    while (len) {
        ssize_t n = send(fd, p, len, 0);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return -1;
        p += n;
        len -= (size_t)n;
    }
    return 0;
}

static int LRRecvExact(int fd, unsigned char *buf, size_t len) {
    size_t got = 0;
    while (got < len) {
        ssize_t n = recv(fd, buf + got, len - got, 0);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return -1;
        got += (size_t)n;
    }
    return 0;
}

/* socks5, no auth, CONNECT by domain name */
static int LRSocksConnect(int fd, const char *host, int port, NSString **err) {
    unsigned char hello[3] = { 5, 1, 0 }, reply[10];
    if (LRSendAll(fd, hello, 3) != 0 || LRRecvExact(fd, reply, 2) != 0 || reply[0] != 5 || reply[1] != 0) {
        if (err) *err = @"the local proxy refused the greeting";
        return -1;
    }
    size_t hl = strlen(host);
    if (hl > 255) hl = 255;
    unsigned char req[262];
    size_t n = 0;
    req[n++] = 5; req[n++] = 1; req[n++] = 0; req[n++] = 3; req[n++] = (unsigned char)hl;
    memcpy(req + n, host, hl);
    n += hl;
    req[n++] = (unsigned char)(port >> 8);
    req[n++] = (unsigned char)(port & 0xff);
    if (LRSendAll(fd, req, n) != 0 || LRRecvExact(fd, reply, 4) != 0) {
        if (err) *err = @"the local proxy did not answer";
        return -1;
    }
    if (reply[1] != 0) {
        if (err) *err = [NSString stringWithFormat:@"the tunnel could not reach %s (socks %d)", host, reply[1]];
        return -1;
    }
    size_t rest = reply[3] == 1 ? 6 : (reply[3] == 4 ? 18 : 0);
    if (reply[3] == 3) {
        unsigned char l;
        if (LRRecvExact(fd, &l, 1) != 0) return -1;
        rest = (size_t)l + 2;
    }
    unsigned char skip[300];
    if (rest && LRRecvExact(fd, skip, rest) != 0) return -1;
    return 0;
}

NSString *LRHTTPGetText(NSString *host, NSString *path, int socksPort, int timeoutMs,
                        int *elapsedMs, NSString **error) {
    long start = LRNowMs();
    NSString *err = nil;
    const char *h = [host UTF8String];
    int fd = socksPort > 0 ? LRConnect("127.0.0.1", socksPort, timeoutMs, &err)
                           : LRConnect(h, 80, timeoutMs, &err);
    if (fd < 0) {
        if (error) *error = socksPort > 0 ? @"the local proxy is not listening" : err;
        return nil;
    }
    if (socksPort > 0 && LRSocksConnect(fd, h, 80, &err) != 0) {
        close(fd);
        if (error) *error = err;
        return nil;
    }
    NSString *req = [NSString stringWithFormat:@"GET %@ HTTP/1.0\r\nHost: %@\r\nUser-Agent: curl/7.30\r\n"
                     "Accept: */*\r\nConnection: close\r\n\r\n", path, host];
    NSData *reqData = [req dataUsingEncoding:NSUTF8StringEncoding];
    if (LRSendAll(fd, [reqData bytes], [reqData length]) != 0) {
        close(fd);
        if (error) *error = @"the request could not be sent";
        return nil;
    }
    NSMutableData *acc = [NSMutableData data];
    char buf[4096];
    for (;;) {
        ssize_t n = recv(fd, buf, sizeof buf, 0);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) break;
        [acc appendBytes:buf length:(NSUInteger)n];
        if ([acc length] > 65536) break;
    }
    close(fd);
    if (elapsedMs) *elapsedMs = (int)(LRNowMs() - start);
    NSString *text = [[[NSString alloc] initWithData:acc encoding:NSUTF8StringEncoding] autorelease];
    NSRange split = [text rangeOfString:@"\r\n\r\n"];
    if (![text hasPrefix:@"HTTP/"] || split.location == NSNotFound) {
        if (error) *error = [acc length] ? @"not an http answer" : @"no answer";
        return nil;
    }
    NSString *status = [[text componentsSeparatedByString:@"\r\n"] objectAtIndex:0];
    NSArray *parts = [status componentsSeparatedByString:@" "];
    int code = [parts count] > 1 ? [[parts objectAtIndex:1] intValue] : 0;
    if (code < 200 || code >= 300) {
        if (error) *error = [NSString stringWithFormat:@"http %d", code];
        return nil;
    }
    NSString *body = LRTrim([text substringFromIndex:split.location + 4]);
    return body ? body : @"";
}

@implementation LRCheckStep
@synthesize name = _name, detail = _detail, result = _result, ms = _ms;
- (void)dealloc {
    [_name release];
    [_detail release];
    [super dealloc];
}
@end

@implementation LRConnectionCheck
@synthesize steps = _steps, verdict = _verdict, overall = _overall, running = _running;

- (id)init {
    if ((self = [super init])) {
        _steps = [[NSMutableArray alloc] init];
        NSArray *names = [NSArray arrayWithObjects:L(@"Daemon"), L(@"Network"), L(@"DNS"),
                          L(@"Server handshake"), L(@"HTTP through the tunnel"),
                          L(@"Device network path"), nil];
        for (NSString *n in names) {
            LRCheckStep *s = [[[LRCheckStep alloc] init] autorelease];
            s.name = n;
            [_steps addObject:s];
        }
    }
    return self;
}

- (void)dealloc {
    [_steps release];
    [_verdict release];
    [_update release];
    [_tunnelIP release];
    [_directIP release];
    [super dealloc];
}

- (void)fire {
    if (_update) _update(self);
}

- (LRCheckStep *)step:(NSUInteger)i {
    return [_steps objectAtIndex:i];
}

- (void)finishStep:(NSUInteger)i result:(LRCheckResult)r detail:(NSString *)detail ms:(int)ms {
    LRCheckStep *s = [self step:i];
    s.result = r;
    s.detail = detail;
    s.ms = ms;
    [self fire];
}

- (void)begin:(NSUInteger)i {
    [self step:i].result = LRCheckRunning;
    [self fire];
}

- (void)cancel {
    _cancelled = YES;
}

/* runs block on a background queue and continues on the main queue */
- (void)background:(id (^)(void))work then:(void (^)(id result))then {
    id (^w)(void) = [[work copy] autorelease];
    void (^t)(id) = [[then copy] autorelease];
    [self retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        id result = [w() retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!_cancelled) t(result);
            [result release];
            [self release];
        });
        [pool drain];
    });
}

- (void)startWithUpdate:(void (^)(LRConnectionCheck *))update {
    if (_running) return;
    [_update release];
    _update = [update copy];
    _running = YES;
    _cancelled = NO;
    for (LRCheckStep *s in _steps) { s.result = LRCheckPending; s.detail = nil; s.ms = 0; }
    [_verdict release];
    _verdict = nil;
    LRLog(@"check", @"connection check started");
    [self runDaemon];
}

- (void)runDaemon {
    [self begin:0];
    long t0 = LRNowMs();
    [[LRDaemonClient shared] status:^(NSString *state, long uptime, BOOL known, uint64_t up, uint64_t down) {
        if (_cancelled) return;
        if (state) [self finishStep:0 result:LRCheckPassed detail:state ms:(int)(LRNowMs() - t0)];
        else [self finishStep:0 result:LRCheckFailed detail:L(@"not answering") ms:0];
        [self runNetwork];
    }];
}

- (void)runNetwork {
    [self begin:1];
    NSString *kind = [LRNetInfo interfaceKind];
    NSString *ip = [LRNetInfo localIPv4];
    NSString *ssid = [LRNetInfo wifiName];
    NSString *detail = kind;
    if (ssid) detail = [detail stringByAppendingFormat:@" · %@", LRStealth(ssid)];
    if (ip) detail = [detail stringByAppendingFormat:@" · %@", LRStealth(ip)];
    [self finishStep:1 result:[LRNetInfo online] ? LRCheckPassed : LRCheckFailed detail:detail ms:0];
    [self runDNS];
}

- (void)runDNS {
    [self begin:2];
    [self background:^id {
        long t0 = LRNowMs();
        struct addrinfo hints, *res = NULL;
        memset(&hints, 0, sizeof hints);
        hints.ai_family = AF_INET;
        hints.ai_socktype = SOCK_STREAM;
        int rc = getaddrinfo("www.gstatic.com", "80", &hints, &res);
        NSString *ip = nil;
        if (rc == 0 && res) {
            char buf[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &((struct sockaddr_in *)res->ai_addr)->sin_addr, buf, sizeof buf);
            ip = [NSString stringWithUTF8String:buf];
            freeaddrinfo(res);
        }
        return [NSArray arrayWithObjects:ip ? ip : @"", [NSNumber numberWithLong:LRNowMs() - t0], nil];
    } then:^(id result) {
        NSString *ip = [result objectAtIndex:0];
        int ms = [[result objectAtIndex:1] intValue];
        if ([ip length]) [self finishStep:2 result:LRCheckPassed detail:L(@"Resolved successfully") ms:ms];
        else [self finishStep:2 result:LRCheckFailed detail:L(@"Resolution failed") ms:ms];
        [self runHandshake];
    }];
}

- (void)runHandshake {
    LRServer *sv = [[LRCatalog shared] selectedServer];
    if (!sv || [LRTunnel shared].activeBackend == LRBackendAmneziaWG) {
        [self finishStep:3 result:LRCheckSkipped detail:L(@"No station selected") ms:0];
        [self runTunnelHTTP];
        return;
    }
    [self begin:3];
    [[LRDaemonClient shared] checkIndex:sv.index mode:@"handshake" reply:^(int ms, NSString *error) {
        if (_cancelled) return;
        if (ms >= 0) [self finishStep:3 result:LRCheckPassed detail:[sv protocolSummary] ms:ms];
        else [self finishStep:3 result:LRCheckFailed detail:error ms:0];
        [self runTunnelHTTP];
    }];
}

- (void)runTunnelHTTP {
    LRTunnel *tunnel = [LRTunnel shared];
    if (tunnel.state != LRTunnelConnected || tunnel.activeBackend == LRBackendAmneziaWG) {
        [self finishStep:4 result:LRCheckSkipped
                  detail:tunnel.activeBackend == LRBackendAmneziaWG ? L(@"AmneziaWG has no local proxy")
                                                                    : L(@"VPN is disconnected") ms:0];
        [self runDirect];
        return;
    }
    [self begin:4];
    int port = (int)[[LRDaemonSettings shared] integerForKey:@"socks_port" fallback:11080];
    [self background:^id {
        int ms = 0;
        NSString *err = nil;
        NSString *ip = LRHTTPGetText(@"api.ipify.org", @"/", port, 8000, &ms, &err);
        if (!ip) ip = LRHTTPGetText(@"icanhazip.com", @"/", port, 8000, &ms, &err);
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        if (ip) [d setObject:ip forKey:@"ip"];
        if (err) [d setObject:err forKey:@"error"];
        [d setObject:[NSNumber numberWithInt:ms] forKey:@"ms"];
        return d;
    } then:^(id d) {
        NSString *ip = [d objectForKey:@"ip"];
        [_tunnelIP release];
        _tunnelIP = [ip copy];
        if (ip) [self finishStep:4 result:LRCheckPassed
                          detail:[NSString stringWithFormat:L(@"Exit %@"), LRStealth(ip)]
                              ms:[[d objectForKey:@"ms"] intValue]];
        else [self finishStep:4 result:LRCheckFailed detail:[d objectForKey:@"error"] ms:0];
        [self runDirect];
    }];
}

- (void)runDirect {
    [self begin:5];
    [self background:^id {
        int ms = 0;
        NSString *err = nil;
        NSString *ip = LRHTTPGetText(@"api.ipify.org", @"/", 0, 8000, &ms, &err);
        if (!ip) ip = LRHTTPGetText(@"icanhazip.com", @"/", 0, 8000, &ms, &err);
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        if (ip) [d setObject:ip forKey:@"ip"];
        if (err) [d setObject:err forKey:@"error"];
        [d setObject:[NSNumber numberWithInt:ms] forKey:@"ms"];
        return d;
    } then:^(id d) {
        NSString *ip = [d objectForKey:@"ip"];
        [_directIP release];
        _directIP = [ip copy];
        if (ip) [self finishStep:5 result:LRCheckPassed
                          detail:[NSString stringWithFormat:L(@"Exit %@"), LRStealth(ip)]
                              ms:[[d objectForKey:@"ms"] intValue]];
        else [self finishStep:5 result:LRCheckFailed detail:[d objectForKey:@"error"] ms:0];
        [self conclude];
    }];
}

- (void)conclude {
    BOOL connected = [LRTunnel shared].state == LRTunnelConnected;
    NSString *v;
    LRCheckResult r;
    if ([self step:0].result == LRCheckFailed) {
        v = L(@"The daemon is not running: reinstall the package or reboot");
        r = LRCheckFailed;
    } else if ([self step:1].result == LRCheckFailed) {
        v = L(@"No network: check Wi-Fi or cellular data");
        r = LRCheckFailed;
    } else if (!connected) {
        v = _directIP ? L(@"The internet works; the VPN is off") : L(@"No internet access");
        r = _directIP ? LRCheckWarning : LRCheckFailed;
    } else if (_tunnelIP && _directIP) {
        if ([_tunnelIP isEqualToString:_directIP]) {
            v = L(@"Working through VPN: the device leaves through the tunnel");
            r = LRCheckPassed;
        } else {
            v = L(@"Traffic leak: the device and the tunnel leave through different addresses");
            r = LRCheckFailed;
        }
    } else if (_tunnelIP) {
        v = L(@"The tunnel works; the device path could not be verified");
        r = LRCheckWarning;
    } else if (_directIP) {
        v = L(@"The tunnel does not carry traffic, but the network works");
        r = LRCheckFailed;
    } else {
        v = L(@"Nothing gets through: check the server and the network");
        r = LRCheckFailed;
    }
    [_verdict release];
    _verdict = [v copy];
    _overall = r;
    _running = NO;
    if (r == LRCheckFailed) LRLogFail(@"check", @"%@", v);
    else LRLog(@"check", @"%@", v);
    [self fire];
}

- (NSString *)textReport {
    NSMutableString *s = [NSMutableString string];
    NSArray *marks = [NSArray arrayWithObjects:@"…", @"…", @"OK", @"WARN", @"FAIL", @"skip", nil];
    for (LRCheckStep *st in _steps)
        [s appendFormat:@"%-28s %-5s %@%@\n", [st.name UTF8String], [[marks objectAtIndex:st.result] UTF8String],
         st.detail ? LRRedact(st.detail) : @"", st.ms > 0 ? [NSString stringWithFormat:@" (%d ms)", st.ms] : @""];
    if (_verdict) [s appendFormat:@"verdict: %@\n", _verdict];
    return s;
}
@end
