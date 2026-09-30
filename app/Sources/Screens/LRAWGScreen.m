#import "LRAWGScreen.h"
#import "LRAWGProfiles.h"
#import "LRPrefs.h"
#import "LRTunnel.h"
#import "LRImporter.h"
#import "LRAlert.h"
#import "LRToast.h"
#import "LRCatalog.h"
#import "LRSimpleScreens.h"
#import "LRShareScreen.h"
#import "LRActivityLog.h"
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;

NSString *LRAWGSetField(NSString *config, NSString *key, NSString *value) {
    NSMutableArray *lines = [NSMutableArray arrayWithArray:
                             [config componentsSeparatedByString:@"\n"]];
    NSString *want = [key lowercaseString];
    BOOL inInterface = NO;
    NSInteger interfaceEnd = -1;
    for (NSUInteger i = 0; i < [lines count]; ++i) {
        NSString *t = LRTrim([lines objectAtIndex:i]);
        if ([t hasPrefix:@"["]) {
            if (inInterface && interfaceEnd < 0) interfaceEnd = (NSInteger)i;
            inInterface = [[t lowercaseString] hasPrefix:@"[interface]"];
            continue;
        }
        NSRange eq = [t rangeOfString:@"="];
        if (eq.location == NSNotFound) continue;
        if (![[LRTrim([t substringToIndex:eq.location]) lowercaseString] isEqualToString:want]) continue;
        if ([value length])
            [lines replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%@ = %@", key, value]];
        else
            [lines removeObjectAtIndex:i];
        return [lines componentsJoinedByString:@"\n"];
    }
    if (![value length]) return config;
    if (interfaceEnd < 0) {
        /* no [Peer] after [Interface]: append to the end of the interface */
        interfaceEnd = (NSInteger)[lines count];
        while (interfaceEnd > 0 && ![LRTrim([lines objectAtIndex:(NSUInteger)interfaceEnd - 1]) length])
            --interfaceEnd;
    } else {
        while (interfaceEnd > 0 && ![LRTrim([lines objectAtIndex:(NSUInteger)interfaceEnd - 1]) length])
            --interfaceEnd;
    }
    [lines insertObject:[NSString stringWithFormat:@"%@ = %@", key, value] atIndex:(NSUInteger)interfaceEnd];
    return [lines componentsJoinedByString:@"\n"];
}

@implementation LRAWGScreen

- (id)init {
    if ((self = [super init])) self.title = @"AmneziaWG";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(reloadSections) name:LRTunnelDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(reloadSections) name:LRAWGProfilesDidChangeNotification object:nil];
    __block LRAWGScreen *me = self;
    [self.header setRightGlyph:LRGlyphPlus(16, [LRHeaderBar glyphColor]) action:^(LRButton *b) {
        [LRImporter showMenuFrom:b host:me];
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (NSArray *)buildSections {
    __block LRAWGScreen *me = self;
    NSMutableArray *sections = [NSMutableArray array];
    NSArray *profiles = [LRAWGProfiles profiles];
    LRAWGProfile *active = [LRAWGProfiles active];
    LRTunnel *t = [LRTunnel shared];
    BOOL useAWG = [LRPrefs selectedBackend] == LRBackendAmneziaWG;
    BOOL live = t.activeBackend == LRBackendAmneziaWG && [t isOn];
    NSMutableArray *rows = [NSMutableArray array];
    for (LRAWGProfile *p in profiles) {
        BOOL isActive = [p.path isEqualToString:active.path];
        LRRow *row = [LRRow value:p.name detail:isActive && live ? [t stateTitle] : nil
                           action:^(LRRow *r, UIView *c) {
            [me openScreen:[[[LRAWGProfileScreen alloc] initWithProfile:p] autorelease]];
        }];
        row.subtitle = [p summary];
        row.chevron = YES;
        if (isActive && useAWG) row.detailColor = SKIN->good;
        if (isActive) row.icon = nil;
        [rows addObject:row];
    }
    if ([rows count])
        [sections addObject:[LRSectionSpec header:L(@"Profiles") rows:rows
                                           footer:L(@"The big button starts the chosen profile while AmneziaWG is in use. Tap a profile for its settings.")]];
    if ([profiles count])
        [sections addObject:[LRSectionSpec header:nil rows:[NSArray arrayWithObjects:
            [LRRow toggle:L(@"Use AmneziaWG") on:useAWG changed:^(BOOL on) {
                [LRPrefs setSelectedBackend:on ? LRBackendAmneziaWG : LRBackendServer];
                [[NSNotificationCenter defaultCenter] postNotificationName:LRTunnelDidChangeNotification object:nil];
            }], nil] footer:nil]];
    [sections addObject:[LRSectionSpec header:nil rows:[NSArray arrayWithObjects:
        [LRRow button:L(@"Import from Clipboard") style:LRRowStyleAccent
               action:^(LRRow *r, UIView *c) { [LRImporter pasteFromClipboard]; }],
        [LRRow button:L(@"More ways to add") style:LRRowStyleAccent
               action:^(LRRow *r, UIView *c) { [LRImporter showMenuFrom:c host:me]; }], nil]
                                       footer:L(@"A .conf with [Interface] and [Peer] (WireGuard or AmneziaWG 1.0, 1.5 and 2.0), or an Amnezia vpn:// key.")]];
    return sections;
}
@end

@implementation LRAWGProfileScreen

- (id)initWithProfile:(LRAWGProfile *)profile {
    if ((self = [super init])) {
        _profile = [profile retain];
        self.title = profile.name;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_profile release];
    [_check release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(reloadSections) name:LRTunnelDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(reloadSections) name:LRAWGProfilesDidChangeNotification object:nil];
}

- (BOOL)isActiveAndLive {
    LRTunnel *t = [LRTunnel shared];
    return t.activeBackend == LRBackendAmneziaWG && [t isOn] &&
           [[[LRAWGProfiles active] path] isEqualToString:_profile.path];
}

/* the helper's own handshake probe, run as the mobile user: it needs nothing
   more than a udp socket, so no setuid step is involved */
- (void)checkHandshake {
    if (_checking) return;
    _checking = YES;
    [_check release];
    _check = [L(@"Checking...") retain];
    [self reloadSections];
    NSString *path = [[_profile.path copy] autorelease];
    [self retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        const char *bin = "/usr/bin/legacyrayawgd";
        char *argv[] = { (char *)bin, (char *)"--handshake", (char *)[path fileSystemRepresentation],
                         (char *)"5000", NULL };
        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
        pid_t pid = 0;
        int status = -1;
        if (posix_spawn(&pid, bin, NULL, NULL, argv, environ) == 0)
            while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {}
        int ms = (int)(([NSDate timeIntervalSinceReferenceDate] - start) * 1000);
        BOOL ok = pid > 0 && WIFEXITED(status) && WEXITSTATUS(status) == 0;
        dispatch_async(dispatch_get_main_queue(), ^{
            _checking = NO;
            [_check release];
            _check = [(ok ? [NSString stringWithFormat:L(@"Handshake in %d ms"), ms]
                          : L(@"No handshake")) retain];
            if (ok) LRLog(@"amneziawg", @"handshake ok");
            else LRLogFail(@"amneziawg", @"handshake failed");
            [self reloadSections];
            [self release];
        });
    });
}

- (void)editField:(NSString *)key title:(NSString *)title current:(NSString *)current {
    __block LRAWGProfileScreen *me = self;
    [LRAlert promptTitle:title message:L(@"Leave empty to remove the key.") placeholder:key
                    text:current button:L(@"Save") done:^(NSString *value) {
        NSString *config = LRAWGSetField([me->_profile config], key, LRTrim(value));
        [LRAWGProfiles updateProfile:me->_profile config:config done:^(BOOL ok, NSString *error) {
            if (ok) [LRToast showSuccess:L(@"Saved. Reconnect to apply.")];
            else [LRToast showError:error];
            [me reloadSections];
        }];
    }];
}

- (NSArray *)buildSections {
    __block LRAWGProfileScreen *me = self;
    NSMutableArray *sections = [NSMutableArray array];
    NSDictionary *f = [_profile fields];
    LRTunnel *t = [LRTunnel shared];
    BOOL live = [self isActiveAndLive];
    BOOL chosen = [[[LRAWGProfiles active] path] isEqualToString:_profile.path] &&
                  [LRPrefs selectedBackend] == LRBackendAmneziaWG;

    NSMutableArray *state = [NSMutableArray array];
    [state addObject:[LRRow value:L(@"Type") detail:[_profile isAmnezia] ? @"AmneziaWG" : @"WireGuard" action:nil]];
    if ([f objectForKey:@"endpoint"])
        [state addObject:[LRRow value:L(@"Endpoint") detail:LRStealth([f objectForKey:@"endpoint"]) action:nil]];
    if ([f objectForKey:@"address"])
        [state addObject:[LRRow value:L(@"Address") detail:LRStealth([f objectForKey:@"address"]) action:nil]];
    if ([f objectForKey:@"dns"])
        [state addObject:[LRRow value:@"DNS" detail:[f objectForKey:@"dns"] action:nil]];
    NSString *allowed = [f objectForKey:@"allowedips"];
    if (allowed) {
        NSUInteger n = [[allowed componentsSeparatedByString:@","] count];
        BOOL full = [allowed rangeOfString:@"0.0.0.0/0"].location != NSNotFound;
        [state addObject:[LRRow value:L(@"Routes") detail:full ? L(@"All traffic")
                                      : [NSString stringWithFormat:L(@"%lu networks"), (unsigned long)n] action:nil]];
    }
    [state addObject:[LRRow value:L(@"State") detail:live ? [t stateTitle] : (_check ? _check : L(@"Not Connected"))
                           action:nil]];
    [sections addObject:[LRSectionSpec header:_profile.name rows:state footer:nil]];

    NSMutableArray *actions = [NSMutableArray array];
    [actions addObject:[LRRow button:live ? L(@"Disconnect") : L(@"Connect") style:LRRowStyleAccent
                              action:^(LRRow *r, UIView *c) {
        if (live) { [[LRTunnel shared] disconnect]; return; }
        [LRAWGProfiles setActive:me->_profile];
        [LRPrefs setSelectedBackend:LRBackendAmneziaWG];
        LRTunnel *tunnel = [LRTunnel shared];
        if ([tunnel isOn]) {
            [tunnel disconnect];
            [tunnel performSelector:@selector(startAWG) withObject:nil afterDelay:1.5];
        } else {
            [tunnel startAWG];
        }
    }]];
    if (!chosen)
        [actions addObject:[LRRow button:L(@"Use this profile") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [LRAWGProfiles setActive:me->_profile];
            [LRPrefs setSelectedBackend:LRBackendAmneziaWG];
            [[NSNotificationCenter defaultCenter] postNotificationName:LRTunnelDidChangeNotification object:nil];
        }]];
    [actions addObject:[LRRow button:_checking ? L(@"Checking...") : L(@"Check the handshake")
                               style:LRRowStyleAccent action:^(LRRow *r, UIView *c) { [me checkHandshake]; }]];
    [actions addObject:[LRRow button:L(@"Share") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
        LRShareScreen *share = [[[LRShareScreen alloc] initWithTitle:me->_profile.name
                                                             payload:[me->_profile config]] autorelease];
        NSString *safe = [[me->_profile.name componentsSeparatedByCharactersInSet:
                           [[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@"_"];
        share.fileName = [([safe length] ? safe : @"amneziawg") stringByAppendingString:@".conf"];
        share.subtitle = [me->_profile summary];
        [me openScreen:share];
    }]];
    [sections addObject:[LRSectionSpec header:nil rows:actions footer:nil]];

    /* the obfuscation knobs amnezia's protocol settings expose */
    NSArray *keys = [NSArray arrayWithObjects:@"Jc", @"Jmin", @"Jmax", @"S1", @"S2", @"S3", @"S4",
                     @"H1", @"H2", @"H3", @"H4", nil];
    NSMutableArray *obf = [NSMutableArray array];
    for (NSString *k in keys) {
        NSString *v = [f objectForKey:[k lowercaseString]];
        if (!v && ([k isEqualToString:@"S3"] || [k isEqualToString:@"S4"])) continue;
        LRRow *row = [LRRow value:k detail:v ? v : @"—" action:^(LRRow *r, UIView *c) {
            [me editField:k title:k current:v];
        }];
        row.monospace = YES;
        [obf addObject:row];
    }
    NSUInteger signatures = 0;
    for (NSString *k in [NSArray arrayWithObjects:@"i1", @"i2", @"i3", @"i4", @"i5", nil])
        if ([[f objectForKey:k] length]) ++signatures;
    [obf addObject:[LRRow value:L(@"Signature packets (I1–I5)")
                         detail:signatures ? [NSString stringWithFormat:@"%lu", (unsigned long)signatures] : L(@"None")
                         action:nil]];
    NSString *ka = [f objectForKey:@"persistentkeepalive"];
    [obf addObject:[LRRow value:@"PersistentKeepalive" detail:ka ? [ka stringByAppendingString:@" s"] : L(@"Off")
                         action:^(LRRow *r, UIView *c) {
        [me editField:@"PersistentKeepalive" title:@"PersistentKeepalive" current:ka];
    }]];
    [obf addObject:[LRRow value:@"MTU" detail:[f objectForKey:@"mtu"] ? [f objectForKey:@"mtu"] : @"1420"
                         action:^(LRRow *r, UIView *c) {
        [me editField:@"MTU" title:@"MTU" current:[f objectForKey:@"mtu"]];
    }]];
    [sections addObject:[LRSectionSpec header:L(@"Obfuscation") rows:obf
                                       footer:L(@"Jc, Jmin and Jmax set the junk packets before a handshake; S and H must match the server. Change them only to what your server uses.")]];

    NSMutableArray *manage = [NSMutableArray array];
    [manage addObject:[LRRow button:L(@"Edit as text") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
        LRTextEditScreen *edit = [[[LRTextEditScreen alloc] initWithTitle:me->_profile.name
            text:[me->_profile config] save:^(NSString *text, LRTextEditScreen *screen) {
            [LRAWGProfiles updateProfile:me->_profile config:text done:^(BOOL ok, NSString *error) {
                if (ok) { [LRToast showSuccess:L(@"Saved. Reconnect to apply.")]; [screen close]; }
                else [LRToast showError:error];
            }];
        }] autorelease];
        [me openScreen:edit];
    }]];
    [manage addObject:[LRRow button:L(@"Rename") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
        [LRAlert promptTitle:L(@"Rename") message:nil placeholder:me->_profile.name text:me->_profile.name
                      button:L(@"Save") done:^(NSString *value) {
            [LRAWGProfiles renameProfile:me->_profile to:value];
            me.title = me->_profile.name;
            me.header.title = me->_profile.name;
            [me reloadSections];
        }];
    }]];
    [manage addObject:[LRRow button:L(@"Remove profile") style:LRRowStyleDestructive action:^(LRRow *r, UIView *c) {
        [LRAlert confirmTitle:L(@"Remove profile") message:me->_profile.name button:L(@"Remove")
                  destructive:YES action:^{
            if ([me isActiveAndLive]) [[LRTunnel shared] disconnect];
            [LRAWGProfiles deleteProfile:me->_profile];
            if (![LRAWGProfiles hasProfiles]) [LRPrefs setSelectedBackend:LRBackendServer];
            [[LRCatalog shared] reload];
            [me close];
        }];
    }]];
    [sections addObject:[LRSectionSpec header:nil rows:manage footer:nil]];
    return sections;
}
@end
