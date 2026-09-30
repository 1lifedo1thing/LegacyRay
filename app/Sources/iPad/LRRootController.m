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
    [_consoleFrame release];
    [_logFrame release];
    [super dealloc];
}

- (void)loadView {
    UIView *root = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]] autorelease];
    root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    /* the divider between the panes */
    root.backgroundColor = SKIN->flat ? SKIN->separator : [UIColor blackColor];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _logFrame = [[UIView alloc] init];
    _logFrame.clipsToBounds = YES;
    _consoleFrame = [[UIView alloc] init];
    _consoleFrame.clipsToBounds = YES;
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

- (void)layoutPanes {
    CGRect b = self.view.bounds;
    CGFloat divider = SKIN->flat ? LRHairline() : 1;
    /* the panes run to the top; on ios 7 their bars grow under the status bar */
    CGFloat logW = 320;
    _logFrame.frame = CGRectMake(0, 0, logW, b.size.height);
    _consoleFrame.frame = CGRectMake(logW + divider, 0, b.size.width - logW - divider, b.size.height);
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
