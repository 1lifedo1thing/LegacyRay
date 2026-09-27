/* the ipad receiver: the station log and the console side by side in
   landscape, stacked in portrait, in a walnut case (classic) or on grey
   (flat). child view controllers are managed by hand on ios 4, which has no
   containment api */
#import <UIKit/UIKit.h>

@class LRConsoleScreen, LRStationsScreen;

@interface LRRootController : UIViewController {
    LRConsoleScreen *_console;
    LRStationsScreen *_stations;
    UINavigationController *_logNav;
    UIImageView *_cabinet;
    UIView *_consoleFrame;
    UIView *_logFrame;
    BOOL _containment;
}
@end
