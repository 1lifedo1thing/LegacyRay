/* the base of every screen: a background, the header bar and a content area
   under it. screens live in a UINavigationController whose own bar stays
   hidden, so push and pop keep the native animation */
#import <UIKit/UIKit.h>
#import "LRHeaderBar.h"

typedef enum {
    LRBackgroundGrouped = 0,  /* the ios 6 pinstripes (flat: ios 7 grey) */
    LRBackgroundDenim         /* the main screen (flat: near white) */
} LRBackgroundStyle;

@interface LRScreen : UIViewController {
    LRHeaderBar *_header;
    UIView *_contentView;
    UIImageView *_backdrop;
    UIImageView *_vignette;
    LRBackgroundStyle _backgroundStyle;
    BOOL _hidesHeader;
    BOOL _manualLeftButton;
    CGFloat _headerCoverage;
}
@property (nonatomic, readonly) LRHeaderBar *header;
@property (nonatomic, readonly) UIView *contentView;
@property (nonatomic, assign) LRBackgroundStyle backgroundStyle;
@property (nonatomic, assign) BOOL hidesHeader;
/* set when the screen puts its own key on the left of the header (or none);
   otherwise Back / Done is added automatically */
@property (nonatomic, assign) BOOL manualLeftButton;

/* flat on ios 7: the content runs under a frosted header and scroll views
   inset their content by headerCoverage. subclasses with a scroll view say yes */
- (BOOL)wantsContentUnderHeader;
@property (nonatomic, readonly) CGFloat headerCoverage;

/* the denim is lit from here, in view coordinates (default: 40% down) */
- (CGFloat)backdropFocus;

/* back, or done when this is the root of a modal */
- (void)close;
- (BOOL)isModalRoot;
/* subclasses: build views in -viewDidLoad after super, lay out here */
- (void)layoutContent;
/* lay everything out again for the current bounds (containers call this on
   ios 4, which has no viewDidLayoutSubviews) */
- (void)relayout;
/* wrap in the app's navigation controller */
- (UINavigationController *)wrappedInNavigation;
/* push when inside a navigation controller, present otherwise */
- (void)openScreen:(UIViewController *)screen;
/* present as a form sheet on the ipad, full screen on the iphone */
- (void)presentSheet:(UIViewController *)screen;
@end

UINavigationController *LRNavigationWithRoot(UIViewController *root);

/* give a scroll view room for a header lying over it, keeping it at the top
   the first time */
void LRApplyHeaderCoverage(UIScrollView *scroll, CGFloat coverage);
