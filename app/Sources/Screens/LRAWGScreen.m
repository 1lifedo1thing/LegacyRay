#import "LRAWGScreen.h"
#import "LRPrefs.h"
#import "LRTunnel.h"
#import "LRImporter.h"
#import "LRAlert.h"
#import "LRToast.h"
#import "LRCatalog.h"
#import "LRSimpleScreens.h"

@implementation LRAWGScreen

- (id)init {
    if ((self = [super init])) self.title = @"AmneziaWG";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSections)
                                                 name:LRTunnelDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSections)
                                                 name:LRCatalogDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

static NSString *LRAWGEndpoint(NSString *config) {
    for (NSString *line in [config componentsSeparatedByString:@"\n"]) {
        NSString *t = LRTrim(line);
        if ([[t lowercaseString] hasPrefix:@"endpoint"]) {
            NSRange eq = [t rangeOfString:@"="];
            if (eq.location != NSNotFound) return LRTrim([t substringFromIndex:eq.location + 1]);
        }
    }
    return nil;
}

- (NSArray *)buildSections {
    __block LRAWGScreen *me = self;
    NSMutableArray *sections = [NSMutableArray array];
    BOOL has = [LRPrefs hasAWGProfile];
    NSString *config = has ? [NSString stringWithContentsOfFile:[LRPrefs awgProfilePath]
                                                        encoding:NSUTF8StringEncoding error:NULL] : nil;
    LRTunnel *t = [LRTunnel shared];
    BOOL active = t.activeBackend == LRBackendAmneziaWG && [t isOn];
    NSMutableArray *status = [NSMutableArray array];
    [status addObject:[LRRow value:L(@"Profile") detail:has ? L(@"Saved") : L(@"Not set") action:nil]];
    if (has) {
        NSString *endpoint = LRAWGEndpoint(config);
        if (endpoint) [status addObject:[LRRow value:L(@"Endpoint") detail:LRStealth(endpoint) action:nil]];
        [status addObject:[LRRow value:L(@"State") detail:active ? [t stateTitle] : L(@"STANDBY") action:nil]];
        [status addObject:[LRRow toggle:L(@"Use AmneziaWG") on:[LRPrefs selectedBackend] == LRBackendAmneziaWG
                                changed:^(BOOL on) {
            [LRPrefs setSelectedBackend:on ? LRBackendAmneziaWG : LRBackendServer];
            [[NSNotificationCenter defaultCenter] postNotificationName:LRTunnelDidChangeNotification object:nil];
        }]];
    }
    [sections addObject:[LRSectionSpec header:L(@"WireGuard / AmneziaWG") rows:status
                                       footer:L(@"The POWER knob starts this profile instead of a station while it is in use.")]];
    NSMutableArray *actions = [NSMutableArray array];
    if (has) {
        [actions addObject:[LRRow button:active ? L(@"Disconnect") : L(@"Connect") style:LRRowStyleAccent
                                  action:^(LRRow *r, UIView *c) {
            if (active) [[LRTunnel shared] disconnect];
            else [[LRTunnel shared] startAWG];
        }]];
        [actions addObject:[LRRow button:L(@"Edit profile") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            LRTextEditScreen *edit = [[[LRTextEditScreen alloc] initWithTitle:@"AmneziaWG" text:config
                                                                         save:^(NSString *text, LRTextEditScreen *screen) {
                [LRImporter importText:text];
                [screen close];
            }] autorelease];
            [me openScreen:edit];
        }]];
    }
    [actions addObject:[LRRow button:L(@"Import from Clipboard") style:LRRowStyleAccent
                              action:^(LRRow *r, UIView *c) { [LRImporter pasteFromClipboard]; }]];
    if (has)
        [actions addObject:[LRRow button:L(@"Remove profile") style:LRRowStyleDestructive action:^(LRRow *r, UIView *c) {
            [LRAlert confirmTitle:L(@"Remove profile") message:nil button:L(@"Remove") destructive:YES action:^{
                if (active) [[LRTunnel shared] disconnect];
                [[NSFileManager defaultManager] removeItemAtPath:[LRPrefs awgProfilePath] error:NULL];
                [LRPrefs setSelectedBackend:LRBackendServer];
                [[LRCatalog shared] reload];
                [me reloadSections];
            }];
        }]];
    [sections addObject:[LRSectionSpec header:nil rows:actions
                                       footer:L(@"Paste a .conf with [Interface] and [Peer], or an Amnezia vpn:// link.")]];
    return sections;
}
@end
