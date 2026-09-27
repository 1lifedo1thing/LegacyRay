#import "LRRootController.h"
#import "LRConsoleScreen.h"
#import "LRStationsScreen.h"
#import "LRScreen.h"
#import "LRDraw.h"

@implementation LRRootController

- (id)init {
    if ((self = [super init])) {
        _containment = [self respondsToSelector:@selector(addChildViewController:)];
        _console = [[LRConsoleScreen alloc] init];
        _console.embedded = YES;
        _stations = [[LRStationsScreen alloc] init];
        _stations.embedded = YES;
        _logNav = [LRNavigationWithRoot(_stations) retain];
    }
    return self;
}

- (void)dealloc {
    [_console release];
    [_stations release];
    [_logNav release];
    [_cabinet release];
    [_consoleFrame release];
    [_logFrame release];
    [super dealloc];
}

- (void)loadView {
    UIView *root = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]] autorelease];
    root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    root.backgroundColor = SKIN->flat ? SKIN->separator : [UIColor blackColor];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _cabinet = [[UIImageView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_cabinet];
    _logFrame = [[UIView alloc] init];
    _logFrame.clipsToBounds = YES;
    _consoleFrame = [[UIView alloc] init];
    _consoleFrame.clipsToBounds = YES;
    if (!SKIN->flat) {
        _consoleFrame.layer.cornerRadius = 4;
        _logFrame.layer.cornerRadius = 4;
    }
    [self.view addSubview:_logFrame];
    [self.view addSubview:_consoleFrame];
    if (_containment) {
        [self addChildViewController:_logNav];
        [self addChildViewController:_console];
    }
    _logNav.view.frame = _logFrame.bounds;
    _console.view.frame = _consoleFrame.bounds;
    [_logFrame addSubview:_logNav.view];
    [_consoleFrame addSubview:_console.view];
    if (_containment) {
        [_logNav didMoveToParentViewController:self];
        [_console didMoveToParentViewController:self];
    }
    [self layoutPanes];
}

- (UIImage *)cabinetImage:(CGSize)size {
    return LRImageWithSize(size, YES, ^(CGContextRef ctx, CGRect rect) {
        if (SKIN->flat) {
            [SKIN->separator setFill];
            CGContextFillRect(ctx, rect);
            return;
        }
        LRDrawWalnut(ctx, rect);
    });
}

- (void)layoutPanes {
    CGRect b = self.view.bounds;
    BOOL flat = SKIN->flat;
    BOOL landscape = b.size.width > b.size.height;
    if (!CGSizeEqualToSize(_cabinet.image.size, b.size)) _cabinet.image = [self cabinetImage:b.size];
    _cabinet.frame = b;
    CGFloat gap = flat ? 0.5f : 10;
    CGFloat edge = flat ? 0 : 10;
    /* ios 7 lays the status bar over the cabinet: the wood shows through it,
       and the panes start below it. flat panes run under it with their headers */
    CGFloat top = edge + (flat ? 0 : LRStatusBarOverlap(self.view));
    if (landscape) {
        CGFloat logW = roundf(MIN(390.0f, b.size.width * 0.39f));
        _logFrame.frame = CGRectMake(edge, top, logW - edge, b.size.height - top - edge);
        _consoleFrame.frame = CGRectMake(logW + gap, top, b.size.width - logW - gap - edge,
                                         b.size.height - top - edge);
    } else {
        CGFloat consoleH = roundf(MIN(600.0f, b.size.height * 0.58f));
        _consoleFrame.frame = CGRectMake(edge, top, b.size.width - edge * 2, consoleH - top);
        _logFrame.frame = CGRectMake(edge, consoleH + gap, b.size.width - edge * 2,
                                     b.size.height - consoleH - gap - edge);
    }
    _logNav.view.frame = _logFrame.bounds;
    _console.view.frame = _consoleFrame.bounds;
    [_console relayout];
    [_stations relayout];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self layoutPanes];
    if (!_containment) {
        [_logNav viewWillAppear:animated];
        [_console viewWillAppear:animated];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!_containment) {
        [_logNav viewDidAppear:animated];
        [_console viewDidAppear:animated];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutPanes];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)o duration:(NSTimeInterval)d {
    [super willAnimateRotationToInterfaceOrientation:o duration:d];
    [self layoutPanes];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o {
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}
@end
