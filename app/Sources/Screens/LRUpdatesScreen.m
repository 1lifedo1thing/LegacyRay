#import "LRUpdatesScreen.h"
#import "LRPrefs.h"
#import "LRImporter.h"
#import "LRVersion.h"
#import "LRSimpleScreens.h"
#import "LRToast.h"

@implementation LRUpdatesScreen

- (id)init {
    if ((self = [super init])) self.title = L(@"Updates");
    return self;
}

- (void)dealloc {
    [_release release];
    [_status release];
    [super dealloc];
}

- (void)check {
    if (_checking) return;
    _checking = YES;
    [self reloadSections];
    [LRUpdateChecker checkNow:^(LRRelease *release, NSString *error) {
        self->_checking = NO;
        [self->_release release];
        self->_release = [release retain];
        [self->_status release];
        if (!release) self->_status = [[NSString stringWithFormat:L(@"Update Check Failed: %@"), error] copy];
        else if ([release isNewer]) self->_status = [[NSString stringWithFormat:L(@"Version %@ is available"), release.version] copy];
        else self->_status = [[NSString stringWithFormat:L(@"Version %@ is the latest release."), @LR_VERSION] copy];
        [self reloadSections];
    }];
}

- (NSArray *)debFiles {
    NSMutableArray *out = [NSMutableArray array];
    NSString *docs = [LRImporter documentsPath];
    for (NSString *dir in [NSArray arrayWithObjects:docs, [docs stringByAppendingPathComponent:@"Inbox"], nil])
        for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:NULL])
            if ([[[name pathExtension] lowercaseString] isEqualToString:@"deb"])
                [out addObject:[dir stringByAppendingPathComponent:name]];
    return out;
}

- (NSArray *)buildSections {
    __block LRUpdatesScreen *me = self;
    NSMutableArray *status = [NSMutableArray array];
    [status addObject:[LRRow value:L(@"Installed version") detail:@LR_VERSION action:nil]];
    NSDate *last = [LRPrefs lastUpdateCheck];
    if (last) {
        NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
        [f setDateStyle:NSDateFormatterMediumStyle];
        [f setTimeStyle:NSDateFormatterShortStyle];
        [status addObject:[LRRow value:L(@"Last checked") detail:[f stringFromDate:last] action:nil]];
    }
    if (_status) [status addObject:[LRRow text:_status]];
    [status addObject:[LRRow button:_checking ? L(@"Checking GitHub Releases...") : L(@"Check for Updates")
                              style:LRRowStyleAccent action:^(LRRow *r, UIView *c) { [me check]; }]];
    if ([_release isNewer]) {
        [status addObject:[LRRow button:L(@"View Release") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [LRUpdateChecker openRelease:me->_release];
        }]];
        if ([_release.notes length])
            [status addObject:[LRRow value:L(@"Release notes") detail:nil action:^(LRRow *r, UIView *c) {
                [me openScreen:[[[LRTextScreen alloc] initWithTitle:me->_release.version text:me->_release.notes] autorelease]];
            }]];
    }
    NSArray *prefs = [NSArray arrayWithObjects:
        [LRRow toggle:L(@"Check for new releases once a day") on:[LRPrefs automaticUpdateChecks]
              changed:^(BOOL on) { [LRPrefs setAutomaticUpdateChecks:on]; }],
        [LRRow toggle:L(@"Prefer GitHub Legacy") on:[LRPrefs preferGitHubLegacy]
              changed:^(BOOL on) { [LRPrefs setPreferGitHubLegacy:on]; }], nil];
    NSMutableArray *install = [NSMutableArray array];
    for (NSString *path in [self debFiles])
        [install addObject:[LRRow value:[path lastPathComponent] detail:nil action:^(LRRow *r, UIView *c) {
            [LRImporter importFileAtPath:path];
        }]];
    if (![install count])
        [install addObject:[LRRow text:L(@"Copy a LegacyRay .deb into Documents with iTunes file sharing, or open it in LegacyRay, to install it from here.")]];
    return [NSArray arrayWithObjects:
            [LRSectionSpec header:nil rows:status footer:L(@"Releases are read through the daemon, which speaks TLS that old iOS no longer can.")],
            [LRSectionSpec header:L(@"Automatic checks") rows:prefs
                           footer:L(@"GitHub Legacy opens GitHub links in the app before the browser.")],
            [LRSectionSpec header:L(@"Install a package") rows:install footer:nil], nil];
}
@end
