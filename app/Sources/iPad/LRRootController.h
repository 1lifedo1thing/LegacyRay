/* the ipad: a split view like ios 6 settings, the stations on the left and
   the main screen on the right, in both orientations. child view
   controllers are managed by hand on ios 4, which has no containment api */
#import <UIKit/UIKit.h>

@class LRConsoleScreen, LRStationsScreen;

@interface LRRootController : UIViewController {
    LRConsoleScreen *_console;
    LRStationsScreen *_stations;
    UINavigationController *_logNav;
    UIView *_consoleFrame;
    UIView *_logFrame;
    BOOL _containment;
}
@end
