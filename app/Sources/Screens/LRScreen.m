#import "LRScreen.h"
#import "LRDraw.h"
#import <objc/runtime.h>

/* swipe from the left edge to go back, the ios 7 way; the delegate keeps it
   from starting on the root, which would wedge the navigation controller */
@interface LRPopGestureDelegate : NSObject <UIGestureRecognizerDelegate> {
    UINavigationController *_nav;
}
@end

@implementation LRPopGestureDelegate
- (id)initWithNavigation:(UINavigationController *)nav {
    if ((self = [super init])) _nav = nav;
    return self;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g {
    return [_nav.viewControllers count] > 1;
}
@end

UINavigationController *LRNavigationWithRoot(UIViewController *root) {
    UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:root]
                                   autorelease];
    nav.navigationBarHidden = YES;
    if (LRIsIOS7Native() && [nav respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        UIGestureRecognizer *g = [nav interactivePopGestureRecognizer];
        LRPopGestureDelegate *d = [[LRPopGestureDelegate alloc] initWithNavigation:nav];
        /* the recognizer does not retain its delegate; tie it to the controller */
        objc_setAssociatedObject(nav, "lr-pop", d, OBJC_ASSOCIATION_RETAIN);
        [d release];
        g.delegate = d;
        g.enabled = YES;
    }
    return nav;
}

void LRApplyHeaderCoverage(UIScrollView *scroll, CGFloat coverage) {
    UIEdgeInsets in = scroll.contentInset;
    if (in.top == coverage) return;
    BOOL atTop = scroll.contentOffset.y <= -in.top + 1;
    in.top = coverage;
    scroll.contentInset = in;
    UIEdgeInsets si = scroll.scrollIndicatorInsets;
    si.top = coverage;
    scroll.scrollIndicatorInsets = si;
    if (atTop) scroll.contentOffset = CGPointMake(scroll.contentOffset.x, -coverage);
}

@implementation LRScreen
@synthesize header = _header, contentView = _contentView, backgroundStyle = _backgroundStyle,
            hidesHeader = _hidesHeader, manualLeftButton = _manualLeftButton,
            headerCoverage = _headerCoverage;

- (id)initWithNibName:(NSString *)nib bundle:(NSBundle *)bundle {
    if ((self = [super initWithNibName:nib bundle:bundle])) {
        /* the header is ours; ios 7 must not pad scroll views for a bar it
           does not know about */
        if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)])
            [self setAutomaticallyAdjustsScrollViewInsets:NO];
    }
    return self;
}

- (BOOL)wantsContentUnderHeader {
    return NO;
}

- (void)dealloc {
    [_header release];
    [_contentView release];
    [_backdrop release];
    [_vignette release];
    [super dealloc];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [_header release];
    _header = nil;
    [_contentView release];
    _contentView = nil;
    [_backdrop release];
    _backdrop = nil;
    [_vignette release];
    _vignette = nil;
}

- (void)loadView {
    UIView *root = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]] autorelease];
    root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    root.backgroundColor = [UIColor blackColor];
    root.clipsToBounds = YES;
    self.view = root;
}

- (BOOL)isModalRoot {
    UINavigationController *nav = self.navigationController;
    if (nav && [nav.viewControllers count] && [nav.viewControllers objectAtIndex:0] != self) return NO;
    UIViewController *top = nav ? (UIViewController *)nav : self;
    if ([top respondsToSelector:@selector(presentingViewController)])
        return [top presentingViewController] != nil;
    /* ios 4: a presented controller's parent is its presenter, and the
       presenter's modalViewController points back at it. a child of the
       ipad container has no parent there, so it is not mistaken for one */
    UIViewController *parent = [top parentViewController];
    return parent != nil && [parent modalViewController] == top;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _backdrop = [[UIImageView alloc] initWithFrame:self.view.bounds];
    _backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_backdrop];
    _contentView = [[UIView alloc] initWithFrame:self.view.bounds];
    _contentView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_contentView];
    _header = [[LRHeaderBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width,
                                                             LR_HEADER_HEIGHT)];
    _header.title = self.title;
    [self.view addSubview:_header];
    [self configureLeftButton];
    _header.hidden = _hidesHeader;
}

/* Back inside a stack, Done at the root of a modal. called again when the
   screen appears: on ios 4 the presentation link may not exist yet while the
   view loads */
- (void)configureLeftButton {
    if (_manualLeftButton || !_header) return;
    UINavigationController *nav = self.navigationController;
    __block LRScreen *me = self;
    if (nav && [nav.viewControllers count] > 1 && [nav.viewControllers objectAtIndex:0] != self) {
        if (_header.leftButton.style != LRButtonBack)
            [_header setBackButtonWithTitle:L(@"Back") action:^(LRButton *b) { [me close]; }];
    } else if ([self isModalRoot]) {
        if (!_header.leftButton)
            [_header setLeftTitle:L(@"Done") style:LRButtonGreen action:^(LRButton *b) { [me close]; }];
    } else {
        _header.leftButton = nil;
    }
}

- (void)setTitle:(NSString *)title {
    [super setTitle:title];
    _header.title = title;
}

- (CGFloat)backdropFocus {
    return roundf(self.view.bounds.size.height * 0.4f);
}

/* the pinstripes are a pattern colour, so a table screen keeps no screen
   sized bitmap; only the denim page is drawn, once per size */
- (void)updateBackdrop {
    CGRect b = self.view.bounds;
    LRSkin *s = SKIN;
    if (_backgroundStyle == LRBackgroundDenim && !s->flat) {
        _backdrop.backgroundColor = LRDenimPageColor();
        if (!_vignette) {
            _vignette = [[UIImageView alloc] initWithImage:LRVignetteImage()];
            _vignette.userInteractionEnabled = NO;
            [self.view insertSubview:_vignette aboveSubview:_backdrop];
        }
        /* the light is a small gradient stretched round the focus */
        CGFloat r = MAX(b.size.width, b.size.height) * 0.85f;
        _vignette.frame = CGRectMake(roundf(b.size.width / 2 - r), roundf([self backdropFocus] - r), r * 2, r * 2);
        return;
    }
    if (_backgroundStyle == LRBackgroundDenim) _backdrop.backgroundColor = [UIColor colorWithWhite:0.97f alpha:1];
    else _backdrop.backgroundColor = s->flat ? s->background : LRPinstripeColor();
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
}

- (void)layoutEverything {
    CGRect b = self.view.bounds;
    _backdrop.frame = b;
    /* on ios 7 the status bar lies over the top of the screen: the header
       grows under it, or the content starts below it when there is none */
    CGFloat inset = LRStatusBarOverlap(self.view);
    CGFloat headerH = LR_HEADER_HEIGHT + inset;
    BOOL under = !_hidesHeader && SKIN->flat && LRIsIOS7Native() && [self wantsContentUnderHeader];
    _header.topInset = inset;
    _header.translucent = under;
    _header.frame = CGRectMake(0, 0, b.size.width, headerH);
    CGFloat top = _hidesHeader ? inset : headerH;
    if (under) {
        _contentView.frame = b;
        _headerCoverage = headerH;
        [self.view bringSubviewToFront:_header];
    } else {
        _contentView.frame = CGRectMake(0, top, b.size.width, b.size.height - top);
        _headerCoverage = 0;
    }
    [self updateBackdrop];
    [self layoutContent];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self configureLeftButton];
    [self layoutEverything];
}

/* ios 4 has no viewWillLayoutSubviews; a view that resizes (rotation, the
   ipad split changing) reaches layoutContent through this instead */
- (void)viewDidLayoutSubviewsCompat {
    [self layoutEverything];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)o duration:(NSTimeInterval)d {
    [super willAnimateRotationToInterfaceOrientation:o duration:d];
    [self layoutEverything];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutEverything];
}

- (void)layoutContent {
}

- (void)relayout {
    if ([self isViewLoaded]) [self layoutEverything];
}

- (void)close {
    UINavigationController *nav = self.navigationController;
    if (nav && [nav.viewControllers count] > 1 && [nav.viewControllers lastObject] == self) {
        [nav popViewControllerAnimated:YES];
        return;
    }
    LRDismissModal(nav ? (UIViewController *)nav : self, YES);
}

- (UINavigationController *)wrappedInNavigation {
    return LRNavigationWithRoot(self);
}

- (void)openScreen:(UIViewController *)screen {
    if (self.navigationController) [self.navigationController pushViewController:screen animated:YES];
    else [self presentSheet:screen];
}

- (void)presentSheet:(UIViewController *)screen {
    UIViewController *vc = [screen isKindOfClass:[UINavigationController class]]
        ? screen : LRNavigationWithRoot(screen);
    if (LRIsPad()) vc.modalPresentationStyle = UIModalPresentationFormSheet;
    /* present from the top of the stack: a child of the ipad container is not
       a presenter ios 4 knows how to rotate */
    LRPresentModal(LRTopViewController(), vc, YES);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o {
    return LRIsPad() || o == UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotate {
    return LRIsPad();
}

- (NSUInteger)supportedInterfaceOrientations {
    return LRIsPad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}
@end
