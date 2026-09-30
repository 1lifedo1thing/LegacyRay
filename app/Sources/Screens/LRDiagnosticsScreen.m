#import "LRDiagnosticsScreen.h"
#import "LRSimpleScreens.h"
#import "LRDaemonClient.h"
#import "LRDaemonSettings.h"
#import "LRTunnel.h"
#import "LRCatalog.h"
#import "LRPrefs.h"
#import "LRNetInfo.h"
#import "LRActivityLog.h"
#import "LRToast.h"
#import "LRAlert.h"
#import "LRVersion.h"
#include "crash_report.h"
#include <sys/sysctl.h>

static NSString *LRMachine(void) {
    size_t size = 0;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *buf = malloc(size + 1);
    if (!buf) return @"?";
    sysctlbyname("hw.machine", buf, &size, NULL, 0);
    buf[size] = 0;
    NSString *s = [NSString stringWithUTF8String:buf];
    free(buf);
    return s ? s : @"?";
}

static NSString *LRFact(NSArray *facts, NSString *key) {
    for (LRDiagFact *f in facts) if ([f.key isEqualToString:key]) return f.value;
    return nil;
}

void LRBuildDiagnosticReport(void (^done)(NSString *)) {
    void (^callback)(NSString *) = [[done copy] autorelease];
    LRDaemonClient *client = [LRDaemonClient shared];
    [client diagnostics:^(NSArray *facts) {
        [client daemonLogTail:^(NSString *log) {
            NSMutableString *r = [NSMutableString string];
            NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
            [f setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];
            UIDevice *d = [UIDevice currentDevice];
            [r appendFormat:@"LegacyRay diagnostic report\nGenerated: %@\n\n", [f stringFromDate:[NSDate date]]];
            [r appendString:@"Application\n-----------\n"];
            [r appendFormat:@"Version: %s (%s)\n", LR_VERSION, LR_BUILD_NUMBER];
            [r appendFormat:@"Device: %@ (%@)\nSystem: %@ %@\n", LRMachine(), [d model], [d systemName], [d systemVersion]];
            [r appendFormat:@"Theme: %@ · Language: %@\n", [LRPrefs flatSkinActive] ? @"flat" : @"classic",
                LRLanguageName(LRCurrentLanguage())];
            [r appendFormat:@"Stealth: %@\n\n", [LRPrefs stealthMode] ? @"on" : @"off"];
            [r appendString:@"Connection\n----------\n"];
            LRTunnel *t = [LRTunnel shared];
            [r appendFormat:@"State: %@\nBackend: %@\n", [t stateTitle],
             t.activeBackend == LRBackendAmneziaWG ? @"amneziawg" : @"vless daemon"];
            LRServer *sv = [[LRCatalog shared] selectedServer];
            if (sv) [r appendFormat:@"Station: %@\n", [sv protocolSummary]];
            if (t.lastError) [r appendFormat:@"Last error: %@\n", LRRedact(t.lastError)];
            [r appendFormat:@"Network: %@\n", [LRNetInfo interfaceKind]];
            [r appendFormat:@"Stations: %lu · Subscriptions: %lu\n\n",
             (unsigned long)[[LRCatalog shared].servers count], (unsigned long)[[LRCatalog shared].subscriptions count]];
            [r appendString:@"Daemon state\n------------\n"];
            if (facts) for (LRDiagFact *fact in facts) [r appendFormat:@"%@ = %@\n", fact.key, LRRedact(fact.value)];
            else [r appendString:@"(the daemon did not answer)\n"];
            [r appendString:@"\nActivity\n--------\n"];
            [r appendString:[[LRActivityLog shared] textDump]];
            NSString *crash = SenkoCrashLastReport();
            if ([crash length]) [r appendFormat:@"\nLast crash\n----------\n%@\n", crash];
            if ([log length]) {
                NSString *tail = [log length] > 12000 ? [log substringFromIndex:[log length] - 12000] : log;
                [r appendFormat:@"\nDaemon log (tail, redacted)\n---------------------------\n%@\n", LRRedact(tail)];
            }
            if (callback) callback(r);
        }];
    }];
}

@implementation LRDiagnosticsScreen

- (id)init {
    if ((self = [super init])) self.title = L(@"Diagnostics");
    return self;
}

- (void)dealloc {
    [_facts release];
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[LRDaemonClient shared] diagnostics:^(NSArray *facts) {
        [self->_facts release];
        self->_facts = [facts retain];
        [self reloadSections];
    }];
}

- (void)showText:(NSString *)title file:(NSString *)file loader:(void (^)(void (^)(NSString *)))loader {
    LRTextScreen *screen = [[[LRTextScreen alloc] initWithTitle:title text:L(@"Loading...")] autorelease];
    screen.fileName = file;
    void (^load)(void (^)(NSString *)) = [[loader copy] autorelease];
    screen.reload = ^(LRTextScreen *s) {
        load(^(NSString *text) { [s setText:text]; });
    };
    [self openScreen:screen];
    load(^(NSString *text) { [screen setText:text]; });
}

- (NSArray *)buildSections {
    __block LRDiagnosticsScreen *me = self;
    LRTunnel *t = [LRTunnel shared];
    NSMutableArray *live = [NSMutableArray array];
    [live addObject:[LRRow value:L(@"Daemon") detail:_facts ? L(@"Running and listening") : L(@"Not running") action:nil]];
    [live addObject:[LRRow value:L(@"VPN connection") detail:[t stateTitle] action:nil]];
    NSString *backend = LRFact(_facts, @"backend.active");
    if (!backend) backend = LRFact(_facts, @"backend.chosen");
    if (backend) [live addObject:[LRRow value:L(@"Traffic redirector") detail:backend action:nil]];
    NSString *pf = LRFact(_facts, @"firewall.pf_mode");
    if (pf) [live addObject:[LRRow value:L(@"PF routing") detail:pf action:nil]];
    NSString *ios = LRFact(_facts, @"ios.major");
    if (ios) [live addObject:[LRRow value:L(@"iOS major") detail:ios action:nil]];
    NSString *net = [LRNetInfo interfaceKind];
    NSString *ip = [LRNetInfo localIPv4];
    [live addObject:[LRRow value:L(@"Active network") detail:ip ? [NSString stringWithFormat:@"%@ · %@", net, LRStealth(ip)] : net action:nil]];
    [live addObject:[LRRow value:L(@"All facts") detail:[NSString stringWithFormat:@"%lu", (unsigned long)[_facts count]]
                          action:^(LRRow *r, UIView *c) {
        [me openScreen:[[[LRFactsScreen alloc] initWithFacts:me->_facts] autorelease]];
    }]];
    NSArray *tools = [NSArray arrayWithObjects:
        [LRRow value:L(@"Connection quality") detail:nil action:^(LRRow *r, UIView *c) {
            [me openScreen:[[[LRConnectionCheckScreen alloc] init] autorelease]];
        }],
        [LRRow value:L(@"Recent activity") detail:[NSString stringWithFormat:@"%lu",
                                                   (unsigned long)[[[LRActivityLog shared] entries] count]]
              action:^(LRRow *r, UIView *c) { [me openScreen:[[[LRActivityScreen alloc] init] autorelease]]; }],
        [LRRow value:L(@"Daemon log") detail:nil action:^(LRRow *r, UIView *c) {
            [me showText:L(@"Daemon log") file:@"legacyray-daemon.log" loader:^(void (^set)(NSString *)) {
                [[LRDaemonClient shared] daemonLogTail:^(NSString *text) {
                    set(text ? ([LRPrefs stealthMode] ? LRRedact(text) : text) : L(@"The daemon did not answer"));
                }];
            }];
        }],
        [LRRow value:L(@"Firewall rules") detail:nil action:^(LRRow *r, UIView *c) {
            [me showText:L(@"Firewall rules") file:@"legacyray-firewall.txt" loader:^(void (^set)(NSString *)) {
                [[LRDaemonClient shared] firewallConfig:^(NSString *text, NSString *error) {
                    set(text ? text : error);
                }];
            }];
        }],
        [LRRow toggle:L(@"Verbose TLS hook log") on:[LRPrefs tlsHookVerbose] changed:^(BOOL on) {
            [LRPrefs setTLSHookVerbose:on];
            if (on) [LRToast show:L(@"Apps started from now on log every redirected connection. Turn it off again when done: it costs battery.")];
        }],
        [LRRow value:L(@"Crash report") detail:[SenkoCrashLastReport() length] ? L(@"Present") : L(@"None")
              action:^(LRRow *r, UIView *c) {
            NSString *crash = SenkoCrashLastReport();
            LRTextScreen *screen = [[[LRTextScreen alloc] initWithTitle:L(@"Crash report")
                                                                   text:[crash length] ? crash : L(@"No crash recorded")] autorelease];
            screen.fileName = @"legacyray-crash.txt";
            [me openScreen:screen];
        }],
        [LRRow value:L(@"Create diagnostic report") detail:nil action:^(LRRow *r, UIView *c) {
            [LRToast show:L(@"Collecting...")];
            LRDiagnosticsScreen *strong = [me retain];
            LRBuildDiagnosticReport(^(NSString *report) {
                LRLog(@"diagnostics", @"diagnostic report created");
                LRTextScreen *screen = [[[LRTextScreen alloc] initWithTitle:L(@"Report") text:report] autorelease];
                screen.fileName = @"legacyray-diagnostics.txt";
                if (strong.view.window) [strong openScreen:screen];
                [strong release];
            });
        }], nil];
    NSArray *flush = [NSArray arrayWithObjects:
        [LRRow button:L(@"Flush DNS cache") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [[LRDaemonClient shared] flushTarget:@"dns" reply:^(NSString *reply) {
                if (LRReplyIsOK(reply)) [LRToast showSuccess:L(@"DNS cache flushed")];
                else [LRToast showError:LRErrorFromReply(reply)];
            }];
        }],
        [LRRow button:L(@"Flush bypass table") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [[LRDaemonClient shared] flushTarget:@"bypass" reply:^(NSString *reply) {
                if (LRReplyIsOK(reply)) [LRToast showSuccess:L(@"Bypass table flushed")];
                else [LRToast showError:LRErrorFromReply(reply)];
            }];
        }],
        [LRRow button:L(@"Restart the daemon") style:LRRowStyleDestructive action:^(LRRow *r, UIView *c) {
            [[LRDaemonClient shared] kickDaemon:^(BOOL ok, NSString *detail) {
                if (ok) [LRToast showSuccess:L(@"Daemon started")];
                else [LRToast showError:detail];
                [[LRCatalog shared] reload];
            }];
        }], nil];
    return [NSArray arrayWithObjects:
            [LRSectionSpec header:L(@"Live state") rows:live footer:nil],
            [LRSectionSpec header:L(@"Tools") rows:tools
                           footer:L(@"The report is privacy safe: links, IDs and addresses are replaced before it is written.")],
            [LRSectionSpec header:nil rows:flush footer:nil],
            nil];
}
@end

@implementation LRFactsScreen

- (id)initWithFacts:(NSArray *)facts {
    if ((self = [super init])) {
        self.title = L(@"Live state");
        _facts = [facts retain];
    }
    return self;
}

- (void)dealloc {
    [_facts release];
    [super dealloc];
}

- (NSArray *)buildSections {
    NSMutableArray *order = [NSMutableArray array];
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];
    for (LRDiagFact *f in _facts) {
        NSRange dot = [f.key rangeOfString:@"."];
        NSString *group = dot.location == NSNotFound ? @"misc" : [f.key substringToIndex:dot.location];
        NSString *name = dot.location == NSNotFound ? f.key : [f.key substringFromIndex:dot.location + 1];
        NSMutableArray *rows = [groups objectForKey:group];
        if (!rows) {
            rows = [NSMutableArray array];
            [groups setObject:rows forKey:group];
            [order addObject:group];
        }
        LRRow *row = [LRRow value:name detail:nil action:nil];
        row.subtitle = [LRPrefs stealthMode] ? LRRedact(f.value) : f.value;
        [rows addObject:row];
    }
    NSMutableArray *sections = [NSMutableArray array];
    for (NSString *g in order)
        [sections addObject:[LRSectionSpec header:[g uppercaseString] rows:[groups objectForKey:g] footer:nil]];
    if (![sections count])
        [sections addObject:[LRSectionSpec header:nil rows:[NSArray arrayWithObject:
                                [LRRow text:L(@"The daemon did not answer")]] footer:nil]];
    return sections;
}
@end

@implementation LRConnectionCheckScreen

- (id)init {
    if ((self = [super init])) {
        self.title = L(@"Connection quality");
        _check = [[LRConnectionCheck alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_check cancel];
    [_check release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self run];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (![self.navigationController.viewControllers containsObject:self]) [_check cancel];
}

- (void)run {
    __block LRConnectionCheckScreen *me = self;
    [_check startWithUpdate:^(LRConnectionCheck *check) { [me reloadSections]; }];
}

- (NSArray *)buildSections {
    LRSkin *s = SKIN;
    NSMutableArray *rows = [NSMutableArray array];
    for (LRCheckStep *step in _check.steps) {
        NSString *mark;
        UIColor *color;
        switch (step.result) {
            case LRCheckRunning: mark = L(@"checking..."); color = s->groupMuted; break;
            case LRCheckPassed: mark = step.ms > 0 ? [NSString stringWithFormat:@"%d ms", step.ms] : @"OK"; color = s->good; break;
            case LRCheckWarning: mark = L(@"Warning"); color = s->warn; break;
            case LRCheckFailed: mark = L(@"Failed"); color = s->bad; break;
            case LRCheckSkipped: mark = L(@"Skipped"); color = s->groupMuted; break;
            default: mark = @"—"; color = s->groupMuted; break;
        }
        LRRow *row = [LRRow value:step.name detail:mark action:nil];
        row.detailColor = color;
        row.subtitle = step.detail;
        [rows addObject:row];
    }
    NSMutableArray *sections = [NSMutableArray arrayWithObject:
        [LRSectionSpec header:L(@"Test DNS, proxy HTTP and the device path") rows:rows footer:nil]];
    __block LRConnectionCheckScreen *me = self;
    NSMutableArray *end = [NSMutableArray array];
    if (_check.verdict) {
        LRRow *v = [LRRow text:_check.verdict];
        [end addObject:v];
    }
    if (!_check.running)
        [end addObject:[LRRow button:L(@"Run connection check") style:LRRowStyleAccent
                              action:^(LRRow *r, UIView *c) { [me run]; }]];
    if (_check.verdict)
        [end addObject:[LRRow button:L(@"Copy result") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [UIPasteboard generalPasteboard].string = [me->_check textReport];
            [LRToast showSuccess:L(@"Copied to the clipboard")];
        }]];
    if ([end count]) [sections addObject:[LRSectionSpec header:_check.verdict ? L(@"Result") : nil rows:end footer:nil]];
    return sections;
}
@end

@implementation LRActivityScreen

- (id)init {
    if ((self = [super init])) self.title = L(@"Recent activity");
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSections)
                                                 name:LRActivityDidChangeNotification object:nil];
    [self.header setRightTitle:L(@"Clear") style:LRButtonMetal action:^(LRButton *b) {
        [LRAlert confirmTitle:L(@"Clear Activity?") message:nil button:L(@"Clear") destructive:YES action:^{
            [[LRActivityLog shared] clear];
        }];
    }];
}

- (NSArray *)buildSections {
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
    [f setDateStyle:NSDateFormatterShortStyle];
    [f setTimeStyle:NSDateFormatterMediumStyle];
    NSMutableArray *rows = [NSMutableArray array];
    for (LRActivityEntry *e in [[LRActivityLog shared] entries]) {
        LRRow *row = [LRRow value:e.message detail:nil action:nil];
        row.subtitle = [NSString stringWithFormat:@"%@ · %@", [f stringFromDate:e.date], e.category];
        if (e.failure) row.style = LRRowStyleDestructive;
        [rows addObject:row];
        if ([rows count] >= 250) break;
    }
    if (![rows count])
        [rows addObject:[LRRow text:[LRPrefs activityLogging] ? L(@"Privacy-safe user and system actions will appear here")
                                                              : L(@"Activity recording is off in Setup > Privacy.")]];
    return [NSArray arrayWithObject:[LRSectionSpec header:nil rows:rows footer:nil]];
}
@end
