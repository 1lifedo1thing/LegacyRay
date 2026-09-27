#import "LRScreen.h"
#import "LRDraw.h"

UINavigationController *LRNavigationWithRoot(UIViewController *root) {
    UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:root]
                                   autorelease];
    nav.navigationBarHidden = YES;
    return nav;
}

@implementation LRScreen
@synthesize header = _header, contentView = _contentView, backgroundStyle = _backgroundStyle,
            hidesHeader = _hidesHeader, manualLeftButton = _manualLeftButton;

- (void)dealloc {
    [_header release];
    [_contentView release];
    [_backdrop release];
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
            [_header setLeftTitle:L(@"Done") style:LRButtonMetal action:^(LRButton *b) { [me close]; }];
    } else {
        _header.leftButton = nil;
    }
}

- (void)setTitle:(NSString *)title {
    [super setTitle:title];
    _header.title = title;
}

- (UIImage *)backdropImageForSize:(CGSize)size {
    switch (_backgroundStyle) {
        case LRBackgroundLeather: return LRLeatherImage(size);
        case LRBackgroundPlate: return LRFaceplateImage(size);
        case LRBackgroundLinen: break;
    }
    return LRLinenImage(size);
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
}

- (void)layoutEverything {
    CGRect b = self.view.bounds;
    if (!CGSizeEqualToSize(_backdrop.image.size, b.size))
        _backdrop.image = [self backdropImageForSize:b.size];
    _backdrop.frame = b;
    CGFloat top = _hidesHeader ? 0 : LR_HEADER_HEIGHT;
    _header.frame = CGRectMake(0, 0, b.size.width, LR_HEADER_HEIGHT);
    _contentView.frame = CGRectMake(0, top, b.size.width, b.size.height - top);
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
