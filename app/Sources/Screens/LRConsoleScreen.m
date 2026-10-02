#import "LRConsoleScreen.h"
#import "LRPowerButton.h"
#import "LRServerCard.h"
#import "LRDraw.h"
#import "LRTunnel.h"
#import "LRCatalog.h"
#import "LRPrefs.h"
#import "LRAWGProfiles.h"
#import "LRImporter.h"
#import "LRToast.h"
#import "LRStationsScreen.h"
#import "LRStationScreen.h"
#import "LRSettingsScreen.h"
#import "LRDiagnosticsScreen.h"

/* where things go for a content box of a given size */
typedef struct {
    CGFloat radius, side, centerY, statusY, cardY, cardW;
} LRConsoleGeometry;

static LRConsoleGeometry LRConsoleLayoutFor(CGSize size) {
    LRConsoleGeometry g;
    CGFloat W = size.width, H = size.height;
    CGFloat cardH = [LRServerCard height];
    if (W < 500) {
        /* the phone: the button high, the station at the bottom */
        g.radius = H < 440 ? 70 : 78;
        g.side = [LRPowerButton sideForRadius:g.radius];
        g.centerY = 30 + g.side / 2 + (H >= 440 ? 10 : 0);
        g.statusY = g.centerY + g.side / 2 + 14;
        g.cardW = MIN(W - 20, 420);
        g.cardY = MAX(g.statusY + 70, H - cardH - 12);
    } else {
        /* the ipad pane: everything in one column around the middle */
        g.radius = MIN(110.0f, MAX(80.0f, MIN(W, H) * 0.16f));
        g.side = [LRPowerButton sideForRadius:g.radius];
        g.centerY = MAX(g.side / 2 + 30, H * 0.36f);
        g.statusY = g.centerY + g.side / 2 + 18;
        g.cardW = MIN(W - 60, 420);
        g.cardY = MIN(g.statusY + 96, H - cardH - 20);
    }
    return g;
}

@implementation LRConsoleScreen
@synthesize embedded = _embedded;

- (id)init {
    if ((self = [super init])) {
        _backgroundStyle = LRBackgroundDenim;
        self.title = @"LegacyRay";
        _manualLeftButton = YES;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_power release];
    [_status release];
    [_detail release];
    [_card release];
    [_shownError release];
    [super dealloc];
}

#pragma mark building

- (UILabel *)label:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    LRSkin *s = SKIN;
    UILabel *l = [[UILabel alloc] init];
    l.backgroundColor = [UIColor clearColor];
    l.textAlignment = NSTextAlignmentCenter;
    l.font = font;
    l.textColor = color;
    l.numberOfLines = lines;
    if (!s->flat) {
        l.shadowColor = s->pageShadow;
        l.shadowOffset = CGSizeMake(0, 1);
    }
    return l;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    __block LRConsoleScreen *me = self;
    LRSkin *s = SKIN;
    UIView *c = self.contentView;
    UIColor *ink = [LRHeaderBar glyphColor];
    if (_embedded) {
        [self.header setLeftTitle:L(@"Check") style:LRButtonMetal action:^(LRButton *b) { [me openCheck]; }];
    } else {
        LRButton *add = [self.header setLeftTitle:nil style:LRButtonMetal action:^(LRButton *b) {
            [LRImporter showMenuFrom:b host:me];
        }];
        [add setGlyph:LRGlyphPlus(16, ink)];
    }
    [self.header setRightGlyph:LRGlyphGear(18, ink) action:^(LRButton *b) { [me openSettings]; }];

    _power = [[LRPowerButton alloc] initWithFrame:CGRectMake(0, 0, 180, 180)];
    [_power addTarget:self action:@selector(powerPressed) forControlEvents:UIControlEventTouchUpInside];
    [c addSubview:_power];
    _status = [self label:s->flat ? [LRSkin lightFont:24] : [LRSkin boldFont:20]
                    color:s->pageInk lines:1];
    [c addSubview:_status];
    _detail = [self label:[LRSkin bodyFont:s->flat ? 15 : 14] color:s->pageMuted lines:2];
    [c addSubview:_detail];

    _card = [[LRServerCard alloc] initWithFrame:CGRectMake(0, 0, 300, [LRServerCard height])];
    [_card addTarget:self action:@selector(cardTapped) forControlEvents:UIControlEventTouchUpInside];
    UISwipeGestureRecognizer *next = [[[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(swiped:)] autorelease];
    next.direction = UISwipeGestureRecognizerDirectionLeft;
    UISwipeGestureRecognizer *prev = [[[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(swiped:)] autorelease];
    prev.direction = UISwipeGestureRecognizerDirectionRight;
    [_card addGestureRecognizer:next];
    [_card addGestureRecognizer:prev];
    [c addSubview:_card];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(refresh) name:LRTunnelDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(tick) name:LRTunnelTickNotification object:nil];
    [nc addObserver:self selector:@selector(refresh) name:LRCatalogDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(refresh) name:LRCatalogPingNotification object:nil];
    [nc addObserver:self selector:@selector(refresh) name:LRAWGProfilesDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(refresh) name:LRPrefsDidChangeNotification object:nil];
    [self refresh];
}

#pragma mark layout

- (CGFloat)backdropFocus {
    LRConsoleGeometry g = LRConsoleLayoutFor(self.contentView.bounds.size);
    return self.contentView.frame.origin.y + g.centerY;
}

- (void)layoutContent {
    CGRect b = self.contentView.bounds;
    CGFloat W = b.size.width;
    if (W < 10 || b.size.height < 10) return;
    LRConsoleGeometry g = LRConsoleLayoutFor(b.size);
    _power.frame = CGRectMake(roundf((W - g.side) / 2), roundf(g.centerY - g.side / 2), g.side, g.side);
    CGFloat textW = MIN(W - 40, 440);
    CGFloat tx = roundf((W - textW) / 2);
    _status.frame = CGRectMake(tx, roundf(g.statusY), textW, 28);
    CGSize ds = [_detail.text sizeWithFont:_detail.font constrainedToSize:CGSizeMake(textW, 40)
                              lineBreakMode:NSLineBreakByWordWrapping];
    _detail.frame = CGRectMake(tx, roundf(g.statusY + 30), textW, MAX(18.0f, ceilf(ds.height)));
    _card.frame = CGRectMake(roundf((W - g.cardW) / 2), roundf(g.cardY), g.cardW, [LRServerCard height]);
}

#pragma mark state

/* a console hidden under a pushed screen redraws nothing; it catches up once
   when it comes back */
- (BOOL)onScreen {
    return self.isViewLoaded && self.view.window != nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_stale) {
        _stale = NO;
        [self refresh];
    }
    [self tick];
}

- (void)catchUp {
    if (_stale && [self onScreen]) {
        _stale = NO;
        [self refresh];
        [self tick];
    }
}

- (NSString *)statusTitle {
    LRTunnel *t = [LRTunnel shared];
    if (t.busy && t.state != LRTunnelConnected) return L(@"Connecting…");
    switch (t.state) {
        case LRTunnelOffline: return L(@"Service Stopped");
        case LRTunnelIdle: return L(@"Not Connected");
        case LRTunnelConnecting: return L(@"Connecting…");
        case LRTunnelConnected: return L(@"Connected");
        case LRTunnelError: return L(@"Connection Failed");
    }
    return @"";
}

- (NSString *)currentStationName {
    LRCatalog *catalog = [LRCatalog shared];
    if ([LRPrefs selectedBackend] == LRBackendAmneziaWG) {
        LRAWGProfile *p = [LRAWGProfiles active];
        return p.name ? p.name : @"AmneziaWG";
    }
    LRServer *sv = [catalog selectedServer];
    return sv ? [catalog displayNameForServer:sv] : nil;
}

- (NSString *)idleDetail {
    LRTunnel *t = [LRTunnel shared];
    LRCatalog *catalog = [LRCatalog shared];
    switch (t.state) {
        case LRTunnelOffline: return L(@"The background service is not running.");
        case LRTunnelError: return [t.lastError length] ? t.lastError : L(@"The server did not answer.");
        case LRTunnelConnecting: return [self currentStationName];
        default: break;
    }
    if (t.busy) return [self currentStationName];
    return [catalog isEmpty] ? L(@"Add a server to begin.") : L(@"Tap the button to connect.");
}

- (void)refreshCard {
    LRCatalog *catalog = [LRCatalog shared];
    LRSkin *s = SKIN;
    if ([LRPrefs selectedBackend] == LRBackendAmneziaWG) {
        LRAWGProfile *p = [LRAWGProfiles active];
        _card.countryCode = nil;
        _card.title = p.name ? p.name : @"AmneziaWG";
        _card.detail = p ? [p summary] : L(@"WireGuard profile");
        _card.value = nil;
        return;
    }
    LRServer *sv = [catalog selectedServer];
    if (!sv) {
        _card.countryCode = nil;
        _card.title = [catalog isEmpty] ? L(@"No servers yet") : L(@"Choose a server");
        _card.detail = [catalog isEmpty] ? L(@"Tap to add a link, a QR code or a subscription") : nil;
        _card.value = nil;
        return;
    }
    _card.countryCode = [sv countryCode];
    _card.title = [catalog displayNameForServer:sv];
    _card.detail = [sv protocolSummary];
    NSNumber *ping = [catalog pingForServer:sv];
    if (ping && [ping intValue] == LR_PING_RUNNING) {
        _card.value = L(@"checking");
        _card.valueColor = s->groupMuted;
    } else if (ping && [ping intValue] < 0) {
        _card.value = L(@"no signal");
        _card.valueColor = s->bad;
    } else if (ping) {
        int v = [ping intValue];
        _card.value = [NSString stringWithFormat:@"%d ms", v];
        _card.valueColor = s->flat ? (v < 150 ? s->good : (v < 450 ? s->warn : s->bad)) : s->groupDetail;
    } else {
        _card.value = nil;
    }
}

- (void)refresh {
    if (![self onScreen] && _power) {
/* the ios 4 ipad container does not forward appearance calls, so also look
   again on the next turn of the run loop, when a new console is in place */
        if (!_stale) [self performSelector:@selector(catchUp) withObject:nil afterDelay:0];
        _stale = YES;
        return;
    }
    LRTunnel *t = [LRTunnel shared];
    LRPowerState ps = LRPowerOff;
    switch (t.state) {
        case LRTunnelConnected: ps = LRPowerOn; break;
        case LRTunnelConnecting: ps = LRPowerTuning; break;
        case LRTunnelError: ps = LRPowerFault; break;
        default: break;
    }
    if (t.busy && ps == LRPowerOff) ps = LRPowerTuning;
    _power.powerState = ps;
    _status.text = [self statusTitle];
    if (t.state == LRTunnelError && [t.lastError length] && ![t.lastError isEqualToString:_shownError]) {
        [LRToast showError:t.lastError];
        [_shownError release];
        _shownError = [t.lastError copy];
    }
    if (t.state != LRTunnelError) {
        [_shownError release];
        _shownError = nil;
    }
    [self refreshCard];
    [self tick];
}

- (void)tick {
    if (![self onScreen]) return;
    LRTunnel *t = [LRTunnel shared];
    NSString *text;
    if (t.state == LRTunnelConnected)
        text = [NSString stringWithFormat:@"%@    ↓ %@    ↑ %@", LRDuration([t liveUptime]),
                LRBytes(t.bytesDown), LRBytes(t.bytesUp)];
    else
        text = [self idleDetail];
    if ([text isEqualToString:_detail.text]) return;
    BOOL relayout = [text length] > 44 || [_detail.text length] > 44;
    _detail.text = text;
    if (relayout) [self layoutContent];
}

#pragma mark actions

- (void)powerPressed {
    [[LRTunnel shared] toggle];
}

- (void)swiped:(UISwipeGestureRecognizer *)g {
    if ([LRPrefs selectedBackend] == LRBackendAmneziaWG) return;
    [[LRTunnel shared] seek:g.direction == UISwipeGestureRecognizerDirectionLeft ? 1 : -1];
}

- (void)cardTapped {
    LRCatalog *catalog = [LRCatalog shared];
    if (catalog.loaded && [catalog isEmpty] && [LRPrefs selectedBackend] != LRBackendAmneziaWG) {
        [LRImporter showMenuFrom:_card host:self];
        return;
    }
    if (_embedded) {
        LRServer *sv = [catalog selectedServer];
        if (sv && [LRPrefs selectedBackend] == LRBackendServer)
            [self presentSheet:[[[LRStationScreen alloc] initWithServer:sv] autorelease]];
        return;
    }
    [self openScreen:[[[LRStationsScreen alloc] init] autorelease]];
}

- (void)openSettings {
    [self presentSheet:[[[LRSettingsScreen alloc] init] autorelease]];
}

- (void)openCheck {
    [self presentSheet:[[[LRConnectionCheckScreen alloc] init] autorelease]];
}
@end
