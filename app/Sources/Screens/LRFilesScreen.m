#import "LRFilesScreen.h"
#import "LRImporter.h"
#import "LRAlert.h"

@implementation LRFilesScreen

- (id)init {
    if ((self = [super init])) self.title = L(@"Import Files");
    return self;
}

- (void)dealloc {
    [_files release];
    [super dealloc];
}

- (NSArray *)scan {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *docs = [LRImporter documentsPath];
    NSMutableArray *out = [NSMutableArray array];
    NSArray *dirs = [NSArray arrayWithObjects:docs, [docs stringByAppendingPathComponent:@"Inbox"], nil];
    for (NSString *dir in dirs) {
        for (NSString *name in [fm contentsOfDirectoryAtPath:dir error:NULL]) {
            if ([name hasPrefix:@"."]) continue;
            NSString *path = [dir stringByAppendingPathComponent:name];
            BOOL isDir = NO;
            if (![fm fileExistsAtPath:path isDirectory:&isDir] || isDir) continue;
            [out addObject:path];
        }
    }
    [out sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSDate *da = [[fm attributesOfItemAtPath:a error:NULL] fileModificationDate];
        NSDate *db = [[fm attributesOfItemAtPath:b error:NULL] fileModificationDate];
        return [db compare:da];
    }];
    return out;
}

- (NSArray *)buildSections {
    [_files release];
    _files = [[self scan] retain];
    NSMutableArray *rows = [NSMutableArray array];
    __block LRFilesScreen *me = self;
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
    [f setDateStyle:NSDateFormatterShortStyle];
    [f setTimeStyle:NSDateFormatterShortStyle];
    for (NSString *path in _files) {
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
        LRRow *row = [LRRow value:[path lastPathComponent] detail:LRBytes([attrs fileSize])
                           action:^(LRRow *r, UIView *cell) { [me pick:path]; }];
        row.subtitle = [f stringFromDate:[attrs fileModificationDate]];
        [rows addObject:row];
    }
    if (![rows count])
        [rows addObject:[LRRow text:L(@"No files yet. Copy .txt, .json, .yaml, .conf, .vpn, .zip, .lray or .deb files into LegacyRay with iTunes file sharing, or open them in LegacyRay from another app.")]];
    return [NSArray arrayWithObject:[LRSectionSpec header:L(@"Documents") rows:rows
                                                   footer:[_files count] ? L(@"Tap a file to import it. Long press to delete.") : nil]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UILongPressGestureRecognizer *lp = [[[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(longPress:)] autorelease];
    [self.tableView addGestureRecognizer:lp];
}

- (void)longPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:[g locationInView:self.tableView]];
    NSInteger i = ip.row - 1;
    if (!ip || i < 0 || i >= (NSInteger)[_files count]) return;
    NSString *path = [_files objectAtIndex:(NSUInteger)i];
    __block LRFilesScreen *me = self;
    [LRAlert confirmTitle:L(@"Delete File") message:[path lastPathComponent] button:L(@"Delete")
              destructive:YES action:^{
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        [me reloadSections];
    }];
}

- (void)pick:(NSString *)path {
    NSString *copy = [[path copy] autorelease];
    [self close];
    [LRImporter importFileAtPath:copy];
}
@end
