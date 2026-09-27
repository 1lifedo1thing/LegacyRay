#import "LRUpdateInstallScreen.h"
#import "LRDaemonClient.h"
#import "LRActivityLog.h"
#import "LRDraw.h"

@implementation LRUpdateInstallScreen

- (id)initWithPackagePath:(NSString *)path {
    if ((self = [super init])) {
        _path = [path copy];
        self.title = L(@"Install Update");
    }
    return self;
}

- (void)dealloc {
    [_path release];
    [_status release];
    [_log release];
    [_gauge release];
    [_done release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.manualLeftButton = YES;
    self.header.leftButton = nil;
    LRSkin *s = SKIN;
    _status = [[UILabel alloc] init];
    _status.backgroundColor = [UIColor clearColor];
    _status.font = [LRSkin boldFont:15];
    _status.numberOfLines = 2;
    _status.textColor = s->groupInk;
    _status.text = [NSString stringWithFormat:L(@"Installing %@..."), [_path lastPathComponent]];
    [self.contentView addSubview:_status];
    _gauge = [[LRTubeGauge alloc] initWithFrame:CGRectMake(0, 0, 200, 18)];
    _gauge.fraction = 0.05;
    [self.contentView addSubview:_gauge];
    _log = [[UITextView alloc] init];
    _log.editable = NO;
    _log.font = [LRSkin monoFont:11];
    _log.backgroundColor = s->flat ? [UIColor whiteColor] : [UIColor colorWithRed:0.98f green:0.96f blue:0.89f alpha:1];
    _log.textColor = [UIColor colorWithWhite:0.15f alpha:1];
    _log.layer.cornerRadius = 6;
    [self.contentView addSubview:_log];
    __block LRUpdateInstallScreen *me = self;
    _done = [[LRButton buttonWithStyle:LRButtonMetal title:L(@"Close") action:^(LRButton *b) { [me close]; }] retain];
    _done.frame = CGRectMake(0, 0, 100, 42);
    _done.enabled = NO;
    [self.contentView addSubview:_done];
    LRLog(@"update", @"installing package");
    [[LRDaemonClient shared] updatePackageAtPath:_path progress:^(NSString *line) {
        [self appendLine:line];
    } reply:^(NSString *status) {
        [self finished:status];
    }];
}

- (void)appendLine:(NSString *)line {
    _log.text = [_log.text length] ? [_log.text stringByAppendingFormat:@"\n%@", line] : line;
    ++_lines;
    _gauge.fraction = MIN(0.92, 0.05 + _lines * 0.06);
    [_log scrollRangeToVisible:NSMakeRange([_log.text length], 0)];
}

- (void)finished:(NSString *)status {
    _finished = YES;
    BOOL ok = [status hasPrefix:@"UPDATE OK"];
    _gauge.fraction = ok ? 1.0 : _gauge.fraction;
    _status.text = ok ? L(@"Update installed. LegacyRay restarts itself.")
                      : [NSString stringWithFormat:L(@"Update failed: %@"),
                         [status hasPrefix:@"UPDATE ERR "] ? [status substringFromIndex:11] : status];
    _status.textColor = ok ? SKIN->good : SKIN->bad;
    _done.enabled = YES;
    if (ok) LRLog(@"update", @"package installed");
    else LRLogFail(@"update", @"%@", status);
}

- (void)layoutContent {
    CGRect b = self.contentView.bounds;
    CGFloat pad = 16, w = b.size.width - pad * 2;
    _status.frame = CGRectMake(pad, 16, w, 44);
    _gauge.frame = CGRectMake(pad, 66, w, 18);
    _log.frame = CGRectMake(pad, 96, w, b.size.height - 96 - 70);
    _done.frame = CGRectMake(pad, b.size.height - 58, w, 42);
}
@end
