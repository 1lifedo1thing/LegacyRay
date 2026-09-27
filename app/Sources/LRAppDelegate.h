#import <UIKit/UIKit.h>

@interface LRAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *_window;
    UIViewController *_root;
}
@property (nonatomic, retain) UIWindow *window;
+ (LRAppDelegate *)shared;
/* throw the interface away and build it again: after a theme or language
   change every view picks up the new finish in one go */
- (void)rebuildInterface;
@end
