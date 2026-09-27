#import "LRAppDelegate.h"
#import "LRAWGProfiles.h"
#import "LRSkin.h"
#import "LRDraw.h"
#import "LRPrefs.h"
#import "LRTunnel.h"
#import "LRCatalog.h"
#import "LRDaemonClient.h"
#import "LRDaemonSettings.h"
#import "LRActivityLog.h"
#import "LRImporter.h"
#import "LRUpdateChecker.h"
#import "LRAlert.h"
#import "LRToast.h"
#import "LRConsoleScreen.h"
#import "LRRootController.h"
#import "LRScreen.h"
#include "crash_report.h"
#import "LRVersion.h"

@implementation LRAppDelegate
@synthesize window = _window;

static LRAppDelegate *gShared = nil;

+ (LRAppDelegate *)shared {
    return gShared;
}

- (UIViewController *)makeRoot {
    if (LRIsPad()) return [[[LRRootController alloc] init] autorelease];
    LRConsoleScreen *console = [[[LRConsoleScreen alloc] init] autorelease];
    return LRNavigationWithRoot(console);
}

- (void)installRoot {
    [_root release];
    _root = [[self makeRoot] retain];
    if ([_window respondsToSelector:@selector(setRootViewController:)]) {
        _window.rootViewController = _root;
    } else {
        for (UIView *v in [_window subviews]) [v removeFromSuperview];
        [_window addSubview:_root.view];
    }
    LRApplyStatusBarStyle();
    /* ios 7 tints what little stock ui is left (text cursors, the keyboard's
       accessory) with the skin's colour */
    if ([_window respondsToSelector:@selector(setTintColor:)]) [_window setTintColor:SKIN->tint];
}

- (void)rebuildInterface {
    UIViewController *root = _window.rootViewController;
    UIViewController *presented = [root respondsToSelector:@selector(presentedViewController)]
        ? [root presentedViewController] : [root modalViewController];
    if (presented) LRDismissModal(root, NO);
    LRFlushSkinCaches();
    [LRSkin reload];
    [self installRoot];
    [[NSNotificationCenter defaultCenter] postNotificationName:LRTunnelDidChangeNotification object:nil];
}

- (void)startServices {
    LRTunnel *tunnel = [LRTunnel shared];
    [tunnel start];
    [[LRDaemonClient shared] ensureDaemon:^(BOOL up, NSString *detail) {
        if (!up) {
            LRLogFail(@"daemon", @"%@", detail ? detail : @"daemon offline");
            [[LRCatalog shared] reload];
            return;
        }
        [[LRDaemonSettings shared] refresh];
        [[LRCatalog shared] reload:^(BOOL ok) {
            if (ok && [LRPrefs refreshSubscriptionsOnOpen] && [[LRCatalog shared].subscriptions count])
                [[LRCatalog shared] refreshAllSubscriptions:nil];
        }];
        [tunnel pollNow];
        [LRUpdateChecker checkIfDue:^(LRRelease *release) {
            LRAlert *a = [LRAlert alertWithTitle:L(@"Update Available")
                                         message:[NSString stringWithFormat:L(@"Version %@ is available.\nCurrently installed: %@."),
                                                  release.version, @LR_VERSION]];
            [a addButton:L(@"Later") style:LRButtonMetal action:nil];
            [a addButton:L(@"View Release") style:LRButtonGreen action:^(LRAlert *alert) {
                [LRUpdateChecker openRelease:release];
            }];
            [a show];
        }];
    }];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    gShared = self;
    SenkoCrashStage("launch");
    [LRAWGProfiles migrate];
    [LRSkin reload];
    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _window.backgroundColor = [UIColor blackColor];
    [self installRoot];
    [_window makeKeyAndVisible];
    LRLog(@"app", @"application launched");
    [self startServices];
    NSURL *url = [options objectForKey:UIApplicationLaunchOptionsURLKey];
    if (url) [LRImporter performSelector:@selector(handleOpenURL:) withObject:url afterDelay:1.0];
    if ([LRPrefs consumeFirstLaunch])
        [self performSelector:@selector(welcome) withObject:nil afterDelay:0.8];
    SenkoCrashLaunchComplete();
    return YES;
}

- (void)welcome {
    [LRAlert showTitle:L(@"Welcome to LegacyRay")
               message:L(@"Press IMPORT to add a server or a subscription, then turn the POWER knob. Long press stations and plates for more.")];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    /* the classic automatic theme follows the clock */
    BOOL nightNow = [LRPrefs nightSkinActive], flatNow = [LRPrefs flatSkinActive];
    LRSkin *s = [LRSkin current];
    if (s->night != nightNow || s->flat != flatNow) [self rebuildInterface];
    [[LRTunnel shared] start];
    [[LRCatalog shared] reload];
    [[LRDaemonSettings shared] refresh];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [[LRTunnel shared] stop];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[LRTunnel shared] stop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    if ([LRPrefs refreshSubscriptionsOnOpen] && [[LRCatalog shared].subscriptions count])
        [[LRCatalog shared] refreshAllSubscriptions:nil];
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [LRImporter handleOpenURL:url];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    LRLog(@"import", @"opened by another application");
    return [LRImporter handleOpenURL:url];
}

- (void)dealloc {
    [_window release];
    [_root release];
    [super dealloc];
}
@end
