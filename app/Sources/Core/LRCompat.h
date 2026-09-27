/* one place for the differences between ios 4.0 and ios 7 that the app has to
   care about. the app links against the ios 6.1 sdk, so ios 7 runs it in the
   legacy (ios 6 style) compatibility mode: no full-screen layout, no tint
   colors, status bar outside the window. what is left are apis that did not
   exist yet on ios 4 */
#import <UIKit/UIKit.h>

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
