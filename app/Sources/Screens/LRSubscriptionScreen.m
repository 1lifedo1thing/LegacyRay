#import "LRSubscriptionScreen.h"
#import "LRCatalog.h"
#import "LRDaemonClient.h"
#import "LRDaemonSettings.h"
#import "LRActivityLog.h"
#import "LRPrefs.h"
#import "LRAlert.h"
#import "LRToast.h"
#import "LRIndicators.h"
#import "LRDraw.h"

/* the card above the table: the tube gauge and the two headline numbers */
@interface LRUsageCard : UIView {
@public
    LRTubeGauge *gauge;
    UILabel *used;
    UILabel *left;
}
@end

@implementation LRUsageCard
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        LRSkin *s = SKIN;
        gauge = [[LRTubeGauge alloc] initWithFrame:CGRectZero];
        [self addSubview:gauge];
        used = [[UILabel alloc] init];
        left = [[UILabel alloc] init];
        for (UILabel *l in [NSArray arrayWithObjects:used, left, nil]) {
            l.backgroundColor = [UIColor clearColor];
            l.font = [LRSkin boldFont:14];
            l.textColor = s->groupHeader;
            l.shadowColor = s->flat ? nil : s->groupHeaderShadow;
            l.shadowOffset = CGSizeMake(0, s->night ? -1 : 1);
            [self addSubview:l];
        }
        left.textAlignment = NSTextAlignmentRight;
    }
    return self;
}
- (void)dealloc {
    [gauge release];
    [used release];
    [left release];
    [super dealloc];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    CGFloat m = LRPlateMargin(b.size.width) + 15;
    used.frame = CGRectMake(m, 14, (b.size.width - m * 2) * 0.6f, 18);
    left.frame = CGRectMake(b.size.width / 2, 14, b.size.width / 2 - m, 18);
    gauge.frame = CGRectMake(m, 38, b.size.width - m * 2, SKIN->flat ? 8 : 18);
}
@end

@implementation LRSubscriptionScreen

- (id)initWithSubscription:(LRSubscription *)sub {
    if ((self = [super init])) {
        _sub = [sub retain];
        self.title = [sub.name length] ? sub.name : L(@"Subscription");
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_sub release];
    [_hwid release];
    [super dealloc];
}

- (void)viewDidLoad {
    LRUsageCard *card = [[[LRUsageCard alloc] initWithFrame:CGRectMake(0, 0, 320, 64)] autorelease];
    [self setTableHeaderView:card];
    [super viewDidLoad];
    [[LRDaemonClient shared] deviceHWID:^(NSString *hwid) {
        [self->_hwid release];
        self->_hwid = [hwid copy];
        [self reloadSections];
    }];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(catalogChanged)
                                                 name:LRCatalogDidChangeNotification object:nil];
}

- (void)catalogChanged {
    LRSubscription *fresh = [[LRCatalog shared] subscriptionWithIndex:_sub.index];
    if (!fresh) return;
    [_sub release];
    _sub = [fresh retain];
    self.title = [fresh.name length] ? fresh.name : L(@"Subscription");
    [self reloadSections];
}

- (void)updateCard {
    LRUsageCard *card = (LRUsageCard *)_tableHeader;
    double f = [_sub usageFraction];
    card->gauge.fraction = f;
    card->used.text = _sub.total ? [NSString stringWithFormat:L(@"%@ of %@"), LRBytes([_sub used]), LRBytes(_sub.total)]
                                 : [NSString stringWithFormat:L(@"%@ used"), LRBytes([_sub used])];
    NSInteger days = [_sub daysLeft];
    card->left.text = days == NSIntegerMax ? L(@"No expiration")
        : (days < 0 ? L(@"Expired") : [NSString stringWithFormat:L(@"%ld days left"), (long)days]);
    card->left.textColor = days != NSIntegerMax && days < 3 ? SKIN->bad : SKIN->groupHeader;
}

static NSString *LRDateText(unsigned long long unix) {
    if (!unix) return nil;
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
    [f setDateStyle:NSDateFormatterMediumStyle];
    [f setTimeStyle:NSDateFormatterNoStyle];
    return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)unix]];
}

- (void)openLink:(NSString *)url {
    NSURL *u = [NSURL URLWithString:url];
    if (!u) return;
    if ([[u scheme] length] == 0) u = [NSURL URLWithString:[@"https://" stringByAppendingString:url]];
    [[UIApplication sharedApplication] openURL:u];
}

- (NSArray *)buildSections {
    [self updateCard];
    LRSubscription *sub = _sub;
    __block LRSubscriptionScreen *me = self;
    NSMutableArray *sections = [NSMutableArray array];

    NSMutableArray *usage = [NSMutableArray array];
    [usage addObject:[LRRow value:L(@"Traffic Used") detail:LRBytes([sub used]) action:nil]];
    [usage addObject:[LRRow value:L(@"Uploaded") detail:LRBytes(sub.upload) action:nil]];
    [usage addObject:[LRRow value:L(@"Downloaded") detail:LRBytes(sub.download) action:nil]];
    [usage addObject:[LRRow value:L(@"Traffic Limit") detail:sub.total ? LRBytes(sub.total) : L(@"Unlimited") action:nil]];
    [usage addObject:[LRRow value:L(@"Expires") detail:sub.expire ? LRDateText(sub.expire) : L(@"No expiration") action:nil]];
    if (sub.refillDate)
        [usage addObject:[LRRow value:L(@"Traffic Refill") detail:LRDateText(sub.refillDate) action:nil]];
    if (sub.updateIntervalHours)
        [usage addObject:[LRRow value:L(@"Suggested Update Interval")
                               detail:[NSString stringWithFormat:L(@"every %u h"), sub.updateIntervalHours] action:nil]];
    [sections addObject:[LRSectionSpec header:L(@"Usage") rows:usage footer:nil]];

    NSMutableArray *provider = [NSMutableArray array];
    if ([sub.summary length]) [provider addObject:[LRRow text:sub.summary]];
    if ([sub.webPageURL length])
        [provider addObject:[LRRow value:L(@"Web Page") detail:LRStealth(sub.webPageURL)
                                  action:^(LRRow *r, UIView *c) { [me openLink:sub.webPageURL]; }]];
    if ([sub.supportURL length] && ![sub.supportURL isEqualToString:sub.webPageURL])
        [provider addObject:[LRRow value:L(@"Support") detail:LRStealth(sub.supportURL)
                                  action:^(LRRow *r, UIView *c) { [me openLink:sub.supportURL]; }]];
    if ([provider count]) [sections addObject:[LRSectionSpec header:L(@"Provider") rows:provider footer:nil]];

    NSMutableArray *fetch = [NSMutableArray array];
    [fetch addObject:[LRRow value:L(@"Subscription Link") detail:LRStealth(sub.url)
                           action:^(LRRow *r, UIView *c) {
        [UIPasteboard generalPasteboard].string = sub.url;
        [LRToast showSuccess:L(@"Link copied")];
    }]];
    if ([sub.header length]) [fetch addObject:[LRRow value:L(@"Extra header") detail:LRStealth(sub.header) action:nil]];
    NSString *ua = [[LRDaemonSettings shared] stringForKey:@"sub_user_agent"];
    [fetch addObject:[LRRow value:@"User-Agent" detail:ua ? ua : @"Happ/3.26.1" action:nil]];
    LRRow *hwid = [LRRow value:@"HWID" detail:_hwid ? LRStealth(_hwid) : L(@"Loading...")
                        action:^(LRRow *r, UIView *c) {
        if (!me->_hwid) return;
        [UIPasteboard generalPasteboard].string = me->_hwid;
        [LRToast showSuccess:L(@"HWID copied")];
    }];
    hwid.monospace = YES;
    [fetch addObject:hwid];
    [sections addObject:[LRSectionSpec header:L(@"Fetching") rows:fetch
                                       footer:L(@"Panels see the device id and the user agent. Tap a line to copy it.")]];

    NSMutableArray *actions = [NSMutableArray array];
    [actions addObject:[LRRow button:_updating ? L(@"Updating...") : L(@"Update Now") style:LRRowStyleAccent
                              action:^(LRRow *r, UIView *c) { [me update]; }]];
    [actions addObject:[LRRow button:L(@"Check latency of all stations") style:LRRowStyleAccent
                              action:^(LRRow *r, UIView *c) {
        for (LRSection *sec in [LRCatalog shared].sections)
            if (sec.sectionId == sub.index) [[LRCatalog shared] pingServers:sec.servers];
        [LRToast show:L(@"All configurations in this subscription are being pinged")];
    }]];
    [actions addObject:[LRRow button:L(@"Rename Subscription") style:LRRowStyleAccent
                              action:^(LRRow *r, UIView *c) { [me rename]; }]];
    [actions addObject:[LRRow button:L(@"Edit link and header") style:LRRowStyleAccent
                              action:^(LRRow *r, UIView *c) { [me edit]; }]];
    [actions addObject:[LRRow button:L(@"Delete Subscription") style:LRRowStyleDestructive
                              action:^(LRRow *r, UIView *c) {
        [LRAlert confirmTitle:L(@"Delete Subscription") message:sub.name button:L(@"Delete") destructive:YES action:^{
            [[LRDaemonClient shared] deleteSubscriptionIndex:sub.index reply:^(NSString *reply) {
                LRLog(@"subscriptions", @"subscription deleted");
                [[LRCatalog shared] reload];
                [me close];
            }];
        }];
    }]];
    [sections addObject:[LRSectionSpec header:nil rows:actions footer:nil]];
    return sections;
}

- (void)update {
    if (_updating) return;
    _updating = YES;
    [self reloadSections];
    __block LRSubscriptionScreen *me = self;
    [self retain];
    [[LRDaemonClient shared] refreshSubscriptionIndex:_sub.index reply:^(NSString *reply) {
        me->_updating = NO;
        if (LRReplyIsOK(reply)) {
            LRLog(@"subscriptions", @"subscription updated");
            [LRToast showSuccess:LRTrim([reply substringFromIndex:MIN((NSUInteger)3, [reply length])])];
        } else {
            LRLogFail(@"subscriptions", @"update failed");
            [LRToast showError:LRErrorFromReply(reply) ? LRErrorFromReply(reply) : L(@"Subscription update failed")];
        }
        [[LRCatalog shared] reload];
        [me reloadSections];
        [me release];
    }];
}

- (void)saveName:(NSString *)name url:(NSString *)url header:(NSString *)header {
    [[LRDaemonClient shared] replaceSubscriptionIndex:_sub.index name:name url:url header:header
                                                reply:^(NSString *reply) {
        if (LRReplyIsOK(reply)) {
            [LRToast showSuccess:L(@"Subscription saved")];
            LRLog(@"subscriptions", @"subscription edited");
        } else {
            [LRToast showError:LRErrorFromReply(reply) ? LRErrorFromReply(reply) : L(@"Could not save")];
        }
        [[LRCatalog shared] reload];
    }];
}

- (void)rename {
    __block LRSubscriptionScreen *me = self;
    [LRAlert promptTitle:L(@"Rename Subscription") message:nil placeholder:L(@"Subscription name")
                    text:_sub.name button:L(@"Save") done:^(NSString *value) {
        NSString *name = LRTrim(value);
        if (!name) { [LRToast showError:L(@"Subscription name cannot be empty.")]; return; }
        [me saveName:name url:me->_sub.url header:me->_sub.header];
    }];
}

- (void)edit {
    __block LRSubscriptionScreen *me = self;
    LRAlert *a = [LRAlert alertWithTitle:L(@"Edit Subscription")
                                 message:L(@"An extra header is sent with every fetch, for panels that want one (Name: value).")];
    [a addFieldWithPlaceholder:L(@"Subscription name") text:_sub.name];
    [a addFieldWithPlaceholder:@"https://" text:_sub.url];
    [a addFieldWithPlaceholder:L(@"Header (optional)") text:_sub.header];
    [a addButton:L(@"Cancel") style:LRButtonMetal action:nil];
    [a addButton:L(@"Save") style:LRButtonGreen action:^(LRAlert *alert) {
        NSString *name = LRTrim([alert textAtIndex:0]), *url = LRTrim([alert textAtIndex:1]);
        if (!name || !url) { [LRToast showError:L(@"Name and link are required")]; return; }
        [me saveName:name url:url header:LRTrim([alert textAtIndex:2])];
    }];
    [a show];
}
@end
