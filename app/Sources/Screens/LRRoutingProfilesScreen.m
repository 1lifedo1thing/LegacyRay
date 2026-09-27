#import "LRRoutingProfilesScreen.h"
#import "LRRoutingProfiles.h"
#import "LRDaemonClient.h"
#import "LRDaemonSettings.h"
#import "LRImporter.h"
#import "LRAlert.h"
#import "LRToast.h"
#import "LRMenu.h"
#import "LRShareScreen.h"
#import "LRSimpleScreens.h"
#import "LRActivityLog.h"

static LRDaemonSettings *DS(void) { return [LRDaemonSettings shared]; }

#pragma mark profiles

@implementation LRRoutingProfilesScreen

- (id)init {
    if ((self = [super init])) self.title = L(@"Routing profiles");
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_status release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSections)
                                                 name:LRRoutingProfilesDidChangeNotification object:nil];
}

- (void)setStatus:(NSString *)status {
    [_status release];
    _status = [status copy];
    [self reloadSections];
}

- (void)apply:(LRRoutingProfile *)p {
    __block LRRoutingProfilesScreen *me = self;
    [self setStatus:L(@"Applying...")];
    [LRRoutingProfiles apply:p progress:^(NSString *line) {
        [me setStatus:line];
    } done:^(BOOL ok, NSString *message) {
        [me setStatus:nil];
        if (message) [LRToast showError:message];
        else [LRToast showSuccess:L(@"Routing profile applied")];
    }];
}

- (void)showMenuFor:(LRRoutingProfile *)p from:(UIView *)anchor {
    __block LRRoutingProfilesScreen *me = self;
    LRMenu *menu = [LRMenu menuWithTitle:p.name];
    [menu addItem:L(@"Apply") action:^{ [me apply:p]; }];
    [menu addItem:L(@"Show rules") action:^{
        NSMutableArray *lines = [NSMutableArray array];
        [lines addObject:[p summary]];
        [lines addObject:@""];
        for (NSArray *r in p.rules) [lines addObject:[r componentsJoinedByString:@" "]];
        [me openScreen:[[[LRTextScreen alloc] initWithTitle:p.name text:[lines componentsJoinedByString:@"\n"]] autorelease]];
    }];
    [menu addItem:L(@"Share") action:^{
        NSString *link = [p happLink];
        if (!link) { [LRToast showError:L(@"The profile could not be encoded")]; return; }
        LRShareScreen *share = [[[LRShareScreen alloc] initWithTitle:p.name payload:link] autorelease];
        share.subtitle = [p summary];
        [me openScreen:share];
    }];
    [menu addDestructiveItem:L(@"Delete") action:^{
        [LRRoutingProfiles remove:p];
    }];
    [menu showFromView:anchor];
}

- (NSArray *)buildSections {
    __block LRRoutingProfilesScreen *me = self;
    NSMutableArray *sections = [NSMutableArray array];
    NSString *active = [LRRoutingProfiles activeName];
    NSMutableArray *rows = [NSMutableArray array];
    for (LRRoutingProfile *p in [LRRoutingProfiles profiles]) {
        LRRow *row = [LRRow check:p.name on:[p.name isEqualToString:active] action:^(LRRow *r, UIView *c) {
            [me showMenuFor:p from:c];
        }];
        row.subtitle = [p summary];
        [rows addObject:row];
    }
    if ([rows count])
        [sections addObject:[LRSectionSpec header:L(@"Saved profiles") rows:rows
                                           footer:_status ? _status : L(@"Applying a profile replaces the current rules. A connected tunnel is restarted for it.")]];
    [sections addObject:[LRSectionSpec header:L(@"Add") rows:[NSArray arrayWithObjects:
        [LRRow button:L(@"Paste a happ://routing link") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [LRImporter pasteFromClipboard];
        }],
        [LRRow button:L(@"Save the current rules as a profile") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [me saveCurrent];
        }], nil]
                                       footer:L(@"Happ routing links and profile JSON work, from the clipboard, a QR code or a file. Providers can also push one with their subscription.")]];
    return sections;
}

- (void)saveCurrent {
    [LRAlert promptTitle:L(@"Save as a profile") message:nil placeholder:L(@"Name") text:nil
                  button:L(@"Save") done:^(NSString *value) {
        NSString *name = LRTrim(value);
        if (![name length]) return;
        [[LRDaemonClient shared] listRules:^(NSArray *rules) {
            NSMutableArray *specs = [NSMutableArray array];
            for (LRRule *r in rules) {
                if ([r.type isEqualToString:@"port"]) continue;
                [specs addObject:[NSArray arrayWithObjects:r.action, r.type, r.value, nil]];
            }
            LRRoutingProfile *p = [[[LRRoutingProfile alloc] init] autorelease];
            p.name = name;
            p.rules = specs;
            p.defaultAction = [[DS() stringForKey:@"rules_default"] isEqualToString:@"direct"] ? @"direct" : @"proxy";
            [LRRoutingProfiles save:p];
            [LRToast showSuccess:L(@"Profile saved")];
        }];
    }];
}
@end

#pragma mark sites

@implementation LRSitesScreen

- (id)init {
    if ((self = [super init])) self.title = L(@"Split tunneling");
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_rules release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSections)
                                                 name:LRDaemonSettingsDidChangeNotification object:nil];
    [self load];
}

- (void)load {
    [[LRDaemonClient shared] listRules:^(NSArray *rules) {
        [self->_rules release];
        self->_rules = [rules retain];
        [self reloadSections];
    }];
}

- (BOOL)onlyListed {
    return [[DS() stringForKey:@"rules_default"] isEqualToString:@"direct"];
}

/* the action a listed site carries in the current mode */
- (NSString *)listAction {
    return [self onlyListed] ? @"proxy" : @"direct";
}

- (NSArray *)siteRules {
    NSMutableArray *out = [NSMutableArray array];
    NSString *want = [self listAction];
    for (LRRule *r in _rules) {
        if (![r.action isEqualToString:want]) continue;
        if ([r.type isEqualToString:@"domain-suffix"] || [r.type isEqualToString:@"domain"] ||
            [r.type isEqualToString:@"ip-cidr"])
            [out addObject:r];
    }
    return out;
}

- (void)addSpecs:(NSArray *)specs done:(void (^)(NSUInteger failed))done {
    void (^callback)(NSUInteger) = [[done copy] autorelease];
    __block NSUInteger failed = 0;
    __block NSUInteger i = 0;
    __block void (^step)(void) = nil;
    step = [^{
        if (i >= [specs count]) { callback(failed); [step release]; return; }
        NSArray *spec = [specs objectAtIndex:i++];
        [[LRDaemonClient shared] addRuleAction:[spec objectAtIndex:0] type:[spec objectAtIndex:1]
                                         value:[spec objectAtIndex:2] reply:^(NSString *reply) {
            if (!LRReplyIsOK(reply)) ++failed;
            step();
        }];
    } copy];
    step();
}

- (void)addEntries:(NSArray *)entries {
    NSMutableArray *specs = [NSMutableArray array];
    for (NSString *e in entries) {
        NSArray *spec = [LRRoutingProfiles ruleSpecForEntry:e action:[self listAction]];
        if (spec) [specs addObject:spec];
    }
    if (![specs count]) { [LRToast showError:L(@"No sites found")]; return; }
    _busy = YES;
    [self reloadSections];
    [LRRoutingProfiles changeRules:^(void (^finish)(void)) {
        [self addSpecs:specs done:^(NSUInteger failed) {
            self->_busy = NO;
            [self load];
            finish();
            if (failed) [LRToast showError:[NSString stringWithFormat:L(@"%lu sites were not accepted"), (unsigned long)failed]];
            else [LRToast showSuccess:[NSString stringWithFormat:L(@"%lu sites added"), (unsigned long)[specs count]]];
            LRLog(@"routing", @"%lu sites added to the split tunnel list", (unsigned long)[specs count]);
        }];
    }];
}

- (void)setOnlyListed:(BOOL)only {
    if (only == [self onlyListed]) return;
    NSArray *sites = [self siteRules];
    NSString *newAction = only ? @"proxy" : @"direct";
    _busy = YES;
    [self reloadSections];
    [LRRoutingProfiles changeRules:^(void (^finish)(void)) {
        [[LRDaemonClient shared] setSetting:@"rules_enabled" value:@"1" reply:nil];
        [DS() setValue:only ? @"direct" : @"proxy" forKey:@"rules_default" done:nil];
        /* re-adding a rule with another action replaces the action */
        NSMutableArray *specs = [NSMutableArray array];
        for (LRRule *r in sites) [specs addObject:[NSArray arrayWithObjects:newAction, r.type, r.value, nil]];
        [self addSpecs:specs done:^(NSUInteger failed) {
            self->_busy = NO;
            [self load];
            finish();
        }];
    }];
}

- (void)removeRule:(LRRule *)rule {
    [LRRoutingProfiles changeRules:^(void (^finish)(void)) {
        [[LRDaemonClient shared] deleteRuleIndex:rule.index reply:^(NSString *reply) {
            if (!LRReplyIsOK(reply)) [LRToast showError:LRErrorFromReply(reply)];
            [self load];
            finish();
        }];
    }];
}

- (NSArray *)buildSections {
    __block LRSitesScreen *me = self;
    NSMutableArray *sections = [NSMutableArray array];
    BOOL only = [self onlyListed];
    [sections addObject:[LRSectionSpec header:L(@"Mode") rows:[NSArray arrayWithObjects:
        [LRRow check:L(@"All sites through the VPN, except the list") on:!only action:^(LRRow *r, UIView *c) {
            [me setOnlyListed:NO];
        }],
        [LRRow check:L(@"Only the listed sites through the VPN") on:only action:^(LRRow *r, UIView *c) {
            [me setOnlyListed:YES];
        }], nil]
                                       footer:_busy ? L(@"Updating the rules...")
                                                    : L(@"A site covers its subdomains. Addresses and ranges work too. Changing the list restarts a connected tunnel.")]];
    NSMutableArray *rows = [NSMutableArray array];
    for (LRRule *r in [self siteRules]) {
        LRRow *row = [LRRow value:r.value detail:nil action:^(LRRow *row, UIView *c) {
            LRMenu *menu = [LRMenu menuWithTitle:r.value];
            [menu addDestructiveItem:L(@"Remove from the list") action:^{ [me removeRule:r]; }];
            [menu showFromView:c];
        }];
        [rows addObject:row];
    }
    if (![rows count]) [rows addObject:[LRRow text:L(@"The list is empty.")]];
    [sections addObject:[LRSectionSpec header:only ? L(@"Through the VPN") : L(@"Around the VPN")
                                         rows:rows footer:nil]];
    [sections addObject:[LRSectionSpec header:nil rows:[NSArray arrayWithObjects:
        [LRRow button:L(@"Add a site") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [LRAlert promptTitle:L(@"Add a site") message:L(@"A domain like example.com, or an address")
                     placeholder:@"example.com" text:nil button:L(@"Add") done:^(NSString *value) {
                [me addEntries:[LRRoutingProfiles sitesFromText:value]];
            }];
        }],
        [LRRow button:L(@"Import from Clipboard") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            NSString *text = [UIPasteboard generalPasteboard].string;
            if (![LRTrim(text) length]) { [LRToast showError:L(@"The clipboard is empty")]; return; }
            [me addEntries:[LRRoutingProfiles sitesFromText:text]];
        }],
        [LRRow button:L(@"Export the list") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            NSMutableArray *sites = [NSMutableArray array];
            for (LRRule *rule in [me siteRules]) [sites addObject:rule.value];
            LRShareScreen *share = [[[LRShareScreen alloc] initWithTitle:L(@"Split tunneling")
                payload:[LRRoutingProfiles amneziaExportForSites:sites]] autorelease];
            share.fileName = @"sites.json";
            [me openScreen:share];
        }], nil]
                                       footer:L(@"Lists exported from Amnezia VPN (JSON) and plain lists with one site per line both import.")]];
    return sections;
}
@end

#pragma mark geo

@implementation LRGeoScreen

- (id)init {
    if ((self = [super init])) self.title = L(@"Geo data");
    return self;
}

- (void)dealloc {
    [_lines release];
    [_summary release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self load];
}

- (void)take:(NSArray *)lines summary:(NSString *)summary {
    [_lines release];
    _lines = [lines retain];
    [_summary release];
    _summary = [summary copy];
    [self reloadSections];
}

- (void)load {
    [[LRDaemonClient shared] geoStatus:^(NSArray *lines, NSString *summary, BOOL ok) {
        [self take:lines summary:summary];
    }];
}

- (void)update {
    if (_updating) return;
    _updating = YES;
    [self reloadSections];
    [[LRDaemonClient shared] geoUpdate:^(NSArray *lines, NSString *summary, BOOL ok) {
        self->_updating = NO;
        [self take:lines summary:summary];
        if (ok) [LRToast showSuccess:L(@"Geo data updated")];
        else [LRToast showError:summary ? summary : L(@"Geo data could not be downloaded")];
        LRLog(@"routing", ok ? @"geo data updated" : @"geo update failed");
    }];
}

- (void)editURL:(NSString *)key title:(NSString *)title {
    __block LRGeoScreen *me = self;
    [LRAlert promptTitle:title message:L(@"Leave empty for the default.") placeholder:@"https://"
                    text:[DS() stringForKey:key] button:L(@"Save") done:^(NSString *value) {
        NSString *v = LRTrim(value);
        if (![v length]) v = [key isEqualToString:@"geosite_url"]
            ? @"https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat"
            : @"https://raw.githubusercontent.com/ipverse/rir-ip/master/country/%s/ipv4-aggregated.txt";
        [DS() setValue:v forKey:key done:^(BOOL ok, NSString *error) {
            if (!ok) [LRToast showError:L(@"That address was not accepted")];
            [me reloadSections];
        }];
    }];
}

- (NSArray *)buildSections {
    __block LRGeoScreen *me = self;
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *line in _lines) {
        NSArray *w = [line componentsSeparatedByString:@" "];
        if ([w count] < 3) continue;
        NSString *kind = [w objectAtIndex:0], *code = [w objectAtIndex:1], *count = [w objectAtIndex:2];
        if ([kind isEqualToString:@"file"]) continue;
        BOOL missing = [count isEqualToString:@"missing"];
        LRRow *row = [LRRow value:[NSString stringWithFormat:@"%@:%@", [kind isEqualToString:@"site"] ? @"geosite" : @"geoip", code]
                           detail:missing ? L(@"no data") : count action:nil];
        row.monospace = YES;
        if (missing) row.detailColor = SKIN->bad;
        [rows addObject:row];
    }
    if (![rows count]) [rows addObject:[LRRow text:L(@"No rule uses geosite or geoip yet.")]];
    [sections addObject:[LRSectionSpec header:L(@"Used by the rules") rows:rows footer:_summary]];
    [sections addObject:[LRSectionSpec header:nil rows:[NSArray arrayWithObjects:
        [LRRow button:_updating ? L(@"Downloading...") : L(@"Update geo data") style:LRRowStyleAccent
               action:^(LRRow *r, UIView *c) { [me update]; }], nil]
                                       footer:L(@"Only the categories your rules name are kept on the phone. The download goes through the tunnel when it is up.")]];
    [sections addObject:[LRSectionSpec header:L(@"Sources") rows:[NSArray arrayWithObjects:
        [LRRow value:@"geosite" detail:[[DS() stringForKey:@"geosite_url"] lastPathComponent]
              action:^(LRRow *r, UIView *c) { [me editURL:@"geosite_url" title:@"geosite"]; }],
        [LRRow value:@"geoip" detail:[[DS() stringForKey:@"geoip_url"] rangeOfString:@"%s"].location != NSNotFound
                                     ? L(@"per country") : [[DS() stringForKey:@"geoip_url"] lastPathComponent]
              action:^(LRRow *r, UIView *c) { [me editURL:@"geoip_url" title:@"geoip"]; }], nil]
                                       footer:L(@"geosite takes a v2fly .dat up to 16 MB (the 70 MB builds are too big for these phones). geoip takes a .dat, or a list address with %s for the country code.")]];
    return sections;
}
@end
