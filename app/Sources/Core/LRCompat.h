/* one place for the differences between ios 4.0 and ios 7 that the app has to
   care about. the app is compiled against the ios 6.1 sdk, but the build marks
   the binary as made for ios 7 (scripts/set_sdk_version.py), so ios 7 runs it
   natively: views go full screen under a transparent status bar, and the
   keyboard, swipe-back and blur are the ios 7 ones. ios 4-6 ignore the mark */
#import <UIKit/UIKit.h>

/* ios 7 methods the 6.1 sdk does not declare; every call checks
   respondsToSelector first */
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
@interface UIViewController (LRiOS7)
- (void)setAutomaticallyAdjustsScrollViewInsets:(BOOL)on;
@end
@interface UIView (LRiOS7)
- (void)setTintColor:(UIColor *)color;
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
     usingSpringWithDamping:(CGFloat)damping initialSpringVelocity:(CGFloat)velocity
                    options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
                 completion:(void (^)(BOOL finished))completion;
@end
@interface UINavigationController (LRiOS7)
- (UIGestureRecognizer *)interactivePopGestureRecognizer;
@end
#endif

#define LR_SYSTEM_AT_LEAST(v) \
    ([[[UIDevice currentDevice] systemVersion] compare:(v) options:NSNumericSearch] != NSOrderedAscending)

static inline BOOL LRIsPad(void) {
    static int cached = -1;
    if (cached < 0) {
        UIDevice *device = [UIDevice currentDevice];
        cached = [device respondsToSelector:@selector(userInterfaceIdiom)] &&
                 [device userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    }
    return cached == 1;
}

static inline CGFloat LRScreenScale(void) {
    UIScreen *screen = [UIScreen mainScreen];
    return [screen respondsToSelector:@selector(scale)] ? [screen scale] : 1.0f;
}

/* iphone 5 / ipod 5: 568 point tall screens */
static inline BOOL LRIsTallPhone(void) {
    return !LRIsPad() && [UIScreen mainScreen].bounds.size.height >= 568.0f;
}

/* hairline in points: one device pixel */
static inline CGFloat LRHairline(void) {
    return 1.0f / LRScreenScale();
}

static inline CGFloat LRRoundPixel(CGFloat v) {
    CGFloat s = LRScreenScale();
    return roundf(v * s) / s;
}

/* ios 7 or later running this binary natively (not in the ios 6 compatibility
   mode an unmarked binary gets) */
BOOL LRIsIOS7Native(void);

/* how far the status bar reaches into a view from its top, 0 when it does not
   (older systems, a form sheet, a view further down the screen) */
CGFloat LRStatusBarOverlap(UIView *view);

/* the status bar style that fits the current skin */
void LRApplyStatusBarStyle(void);

/* the flat skin on ios 7 springs things into place the way ios 7 does; the
   rest ease out as before */
void LRAnimateIn(NSTimeInterval duration, void (^animations)(void));

/* modal presentation spelled for ios 4 (presentModalViewController) and for
   ios 5+ (presentViewController:animated:completion:) */
void LRPresentModal(UIViewController *host, UIViewController *vc, BOOL animated);
void LRDismissModal(UIViewController *vc, BOOL animated);

/* the controller currently at the top of the modal stack, for code that is
   not itself a view controller (toasts, alerts, the import pipeline) */
UIViewController *LRTopViewController(void);

/* UIImage from a block of core graphics drawing, at screen scale */
UIImage *LRImageWithSize(CGSize size, BOOL opaque, void (^draw)(CGContextRef ctx, CGRect rect));

/* a stretchable image; ios 5's resizableImageWithCapInsets does not exist on
   ios 4, and stretchableImageWithLeftCapWidth works everywhere */
UIImage *LRStretchable(UIImage *image, CGFloat left, CGFloat top);

/* trimmed string or nil */
NSString *LRTrim(NSString *s);

/* human readable byte counts, "12.4 MB" */
NSString *LRBytes(unsigned long long bytes);
/* speed: "340 KB/s" */
NSString *LRSpeed(double bytesPerSecond);
/* "01:24:07" or "3d 04:10" */
NSString *LRDuration(long seconds);
