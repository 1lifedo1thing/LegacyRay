#import "LRConsoleScreen.h"
#import "LRDisplayView.h"
#import "LRTuningDial.h"
#import "LRVUMeter.h"
#import "LRPowerButton.h"
#import "LRToggleSwitch.h"
#import "LRDraw.h"
#import "LRTunnel.h"
#import "LRCatalog.h"
#import "LRPrefs.h"
#import "LRDaemonSettings.h"
#import "LRImporter.h"
#import "LRToast.h"
#import "LRStationsScreen.h"
#import "LRStationScreen.h"
#import "LRSettingsScreen.h"
#import "LRDiagnosticsScreen.h"

/* the nameplate and the four corner screws, drawn once over the faceplate */
@interface LRConsoleDecor : UIView {
@public
    CGFloat nameplateBottom;
}
@end

@implementation LRConsoleDecor
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    LRSkin *s = SKIN;
    CGRect b = self.bounds;
    CGFloat mid = CGRectGetMidX(b);
    if (s->flat) {
        UIFont *f = [LRSkin lightFont:22];
        LRDrawEngraved(@"LegacyRay", CGRectMake(0, 10, b.size.width, 28), f, NSTextAlignmentCenter,
                       s->groupInk, nil, 0);
        return;
    }
    LRDrawScrew(ctx, CGPointMake(12, 12), 4, 0.6f);
    LRDrawScrew(ctx, CGPointMake(b.size.width - 12, 12), 4, 2.0f);
    LRDrawScrew(ctx, CGPointMake(12, b.size.height - 12), 4, 1.1f);
    LRDrawScrew(ctx, CGPointMake(b.size.width - 12, b.size.height - 12), 4, 0.3f);
    UIFont *title = [LRSkin titleFont:21];
    LRDrawEngraved(@"LegacyRay", CGRectMake(0, 8, b.size.width, 26), title, NSTextAlignmentCenter,
                   s->engrave, s->engraveShadow, s->engraveOffset);
    UIFont *legend = [LRSkin labelFont:7.5f];
    LRDrawTracked(L(@"FULL-DEVICE VLESS RECEIVER"), mid, 34, legend, 1.6f, NSTextAlignmentCenter,
                  s->engrave, s->engraveShadow, s->engraveOffset);
}
@end

static UILabel *LRLegendLabel(void) {
    LRSkin *s = SKIN;
    UILabel *l = [[[UILabel alloc] init] autorelease];
    l.backgroundColor = [UIColor clearColor];
    l.textAlignment = NSTextAlignmentCenter;
    l.font = s->flat ? [LRSkin bodyFont:11] : [LRSkin labelFont:8];
    l.textColor = s->flat ? s->groupMuted : s->engrave;
    l.shadowColor = s->flat ? nil : s->engraveShadow;
    l.shadowOffset = CGSizeMake(0, s->engraveOffset);
    return l;
}

@implementation LRConsoleScreen
@synthesize embedded = _embedded;

- (id)init {
    if ((self = [super init])) {
        _backgroundStyle = LRBackgroundPlate;
        _hidesHeader = YES;
        self.title = @"LegacyRay";
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_decor release];
    [_display release];
    [_dial release];
    [_upMeter release];
    [_downMeter release];
    [_power release];
    [_seekBack release];
    [_seekForward release];
    [_powerCaption release];
    [_seekCaptions[0] release];
    [_seekCaptions[1] release];
    [_toggles release];
    [_toggleCaptions release];
    [_keys release];
    [_dialServers release];
    [_shownError release];
    [super dealloc];
}

#pragma mark building

- (LRButton *)key:(NSString *)title action:(void (^)(LRButton *))action {
    LRButton *b = [LRButton buttonWithStyle:SKIN->night ? LRButtonDark : LRButtonMetal
                                      title:SKIN->flat ? title : LRSpaced([title uppercaseString])
                                     action:action];
    b.frame = CGRectMake(0, 0, 90, 36);
    b.titleLabel.font = SKIN->flat ? [LRSkin bodyFont:16] : [LRSkin labelFont:11];
    return b;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    __block LRConsoleScreen *me = self;
    UIView *c = self.contentView;
    _decor = [[LRConsoleDecor alloc] initWithFrame:c.bounds];
    [c addSubview:_decor];

    _display = [[LRDisplayView alloc] initWithFrame:CGRectMake(0, 0, 300, 120)];
    _display.legends = [NSArray arrayWithObjects:L(@"STEALTH"), L(@"LAN"), L(@"ROUTING"), L(@"AUTO"), nil];
    [_display addTarget:self action:@selector(displayTapped) forControlEvents:UIControlEventTouchUpInside];
    [c addSubview:_display];

    _dial = [[LRTuningDial alloc] initWithFrame:CGRectMake(0, 0, 300, 44)];
    [_dial addTarget:self action:@selector(dialChanged) forControlEvents:UIControlEventValueChanged];
    [c addSubview:_dial];

    _upMeter = [[LRVUMeter alloc] initWithFrame:CGRectMake(0, 0, 140, 84)];
    _upMeter.caption = L(@"UPLINK B/s");
    _downMeter = [[LRVUMeter alloc] initWithFrame:CGRectMake(0, 0, 140, 84)];
    _downMeter.caption = L(@"DOWNLINK B/s");
    [c addSubview:_upMeter];
    [c addSubview:_downMeter];

    _power = [[LRPowerButton alloc] initWithFrame:CGRectMake(0, 0, 130, 130)];
    [_power addTarget:self action:@selector(powerPressed) forControlEvents:UIControlEventTouchUpInside];
    [c addSubview:_power];
    _powerCaption = [LRLegendLabel() retain];
    _powerCaption.text = SKIN->flat ? L(@"Power") : LRSpaced(L(@"POWER"));
    [c addSubview:_powerCaption];

    UIColor *glyphInk = SKIN->flat ? SKIN->tint
        : (SKIN->night ? [UIColor colorWithWhite:0.85f alpha:1] : [UIColor colorWithWhite:0.25f alpha:1]);
    _seekBack = [[LRButton buttonWithStyle:LRButtonMetal title:nil action:^(LRButton *b) {
        [[LRTunnel shared] seek:-1];
    }] retain];
    [_seekBack setGlyph:LRGlyphSeek(20, -1, glyphInk)];
    _seekForward = [[LRButton buttonWithStyle:LRButtonMetal title:nil action:^(LRButton *b) {
        [[LRTunnel shared] seek:1];
    }] retain];
    [_seekForward setGlyph:LRGlyphSeek(20, 1, glyphInk)];
    for (int i = 0; i < 2; ++i) {
        LRButton *b = i ? _seekForward : _seekBack;
        b.frame = CGRectMake(0, 0, 50, 30);
        [c addSubview:b];
        _seekCaptions[i] = [LRLegendLabel() retain];
        _seekCaptions[i].text = SKIN->flat ? L(@"Seek") : LRSpaced(L(@"SEEK"));
        [c addSubview:_seekCaptions[i]];
    }

    NSArray *toggleTitles = [NSArray arrayWithObjects:L(@"AUTO-RECONNECT"), L(@"ROUTING"),
                             L(@"LAN BYPASS"), L(@"STEALTH"), nil];
    NSMutableArray *toggles = [NSMutableArray array], *captions = [NSMutableArray array];
    for (NSUInteger i = 0; i < [toggleTitles count]; ++i) {
        LRToggleSwitch *t = [[[LRToggleSwitch alloc] initWithFrame:CGRectZero] autorelease];
        t.tag = (NSInteger)i;
        [t addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        [c addSubview:t];
        [toggles addObject:t];
        UILabel *l = LRLegendLabel();
        NSString *title = [toggleTitles objectAtIndex:i];
        l.text = SKIN->flat ? [title capitalizedString] : LRSpaced(title);
        [c addSubview:l];
        [captions addObject:l];
    }
    _toggles = [toggles copy];
    _toggleCaptions = [captions copy];

    NSMutableArray *keys = [NSMutableArray array];
    if (!_embedded)
        [keys addObject:[self key:L(@"Stations") action:^(LRButton *b) { [me openStations]; }]];
    [keys addObject:[self key:L(@"Import") action:^(LRButton *b) {
        [LRImporter showMenuFrom:b host:me];
    }]];
    if (_embedded)
        [keys addObject:[self key:L(@"Check") action:^(LRButton *b) { [me openCheck]; }]];
    [keys addObject:[self key:L(@"Setup") action:^(LRButton *b) { [me openSettings]; }]];
    for (LRButton *b in keys) [c addSubview:b];
    _keys = [keys copy];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(refresh) name:LRTunnelDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(tick) name:LRTunnelTickNotification object:nil];
    [nc addObserver:self selector:@selector(refresh) name:LRCatalogDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(refresh) name:LRCatalogPingNotification object:nil];
    [nc addObserver:self selector:@selector(refresh) name:LRDaemonSettingsDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(refresh) name:LRPrefsDidChangeNotification object:nil];
    [self refresh];
}

#pragma mark layout

- (void)place:(UIView *)v x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h {
    v.frame = CGRectMake(roundf(x), roundf(y), roundf(w), roundf(h));
}

- (void)layoutContent {
    CGRect b = self.contentView.bounds;
    CGFloat W = b.size.width, H = b.size.height;
    if (W < 10 || H < 10) return;
    _decor.frame = b;
    [_decor setNeedsDisplay];
    BOOL pad = LRIsPad();
    BOOL wide = W >= 700 || (W >= 560 && H < 640);
    CGFloat side = pad ? 24 : 16;
    CGFloat y = 50;
    CGFloat displayH = pad ? (wide ? 136 : 150) : (H >= 540 ? 122 : 112);
    [self place:_display x:side y:y w:W - side * 2 h:displayH];
    _display.compact = !pad;
    y += displayH + (pad ? 14 : 10);
    BOOL showDial = pad || H >= 540;
    _dial.hidden = !showDial;
    if (showDial) {
        [self place:_dial x:side y:y w:W - side * 2 h:pad ? 46 : 40];
        y += (pad ? 46 : 40) + (pad ? 16 : 12);
    }
    CGFloat keysH = pad ? 40 : 34;
    CGFloat keysY = H - keysH - (pad ? 20 : 14);
    BOOL showToggles = pad || H >= 640;
    CGFloat togglesH = showToggles ? 58 : 0;
    CGFloat bottomLimit = keysY - togglesH - (showToggles ? 12 : 8);

    if (wide) {
        /* [meter] (knob) [meter]: the classic symmetrical receiver front */
        CGFloat room = bottomLimit - y;
        CGFloat D = MIN(160.0f, room - 44);
        CGFloat meterW = MIN(240.0f, (W - side * 2 - D - 60) / 2);
        CGFloat meterH = MIN(meterW * 0.62f, room - 30);
        CGFloat cy = y + MAX(D, meterH) / 2 + 4;
        [self place:_upMeter x:side y:cy - meterH / 2 w:meterW h:meterH];
        [self place:_downMeter x:W - side - meterW y:cy - meterH / 2 w:meterW h:meterH];
        CGFloat frame = D + 24;
        [self place:_power x:(W - frame) / 2 y:cy - frame / 2 w:frame h:frame];
        [self place:_powerCaption x:(W - 100) / 2 y:cy + frame / 2 - 6 w:100 h:12];
        CGFloat seekY = CGRectGetMaxY(_upMeter.frame) + 10;
        [self place:_seekBack x:side + meterW / 2 - 25 y:seekY w:50 h:30];
        [self place:_seekForward x:W - side - meterW / 2 - 25 y:seekY w:50 h:30];
    } else {
        CGFloat gap = pad ? 20 : 12;
        CGFloat meterW = MIN(pad ? 260.0f : 200.0f, (W - side * 2 - gap) / 2);
        CGFloat meterH = roundf(meterW * 0.6f);
        CGFloat totalMeters = meterW * 2 + gap;
        CGFloat mx = (W - totalMeters) / 2;
        [self place:_upMeter x:mx y:y w:meterW h:meterH];
        [self place:_downMeter x:mx + meterW + gap y:y w:meterW h:meterH];
        y += meterH + (pad ? 12 : 6);
        CGFloat room = bottomLimit - y;
        CGFloat D = MAX(80.0f, MIN(pad ? 170.0f : 112.0f, room - 34));
        CGFloat frame = D + 24;
        CGFloat cy = y + frame / 2;
        [self place:_power x:(W - frame) / 2 y:y w:frame h:frame];
        [self place:_powerCaption x:(W - 100) / 2 y:y + frame - 8 w:100 h:12];
        CGFloat seekW = 50;
        CGFloat seekGap = MIN(40.0f, (W / 2 - frame / 2 - seekW - side) );
        [self place:_seekBack x:W / 2 - frame / 2 - seekGap - seekW y:cy - 15 w:seekW h:30];
        [self place:_seekForward x:W / 2 + frame / 2 + seekGap y:cy - 15 w:seekW h:30];
    }
    for (int i = 0; i < 2; ++i) {
        LRButton *s = i ? _seekForward : _seekBack;
        [self place:_seekCaptions[i] x:CGRectGetMidX(s.frame) - 40 y:CGRectGetMaxY(s.frame) + 4 w:80 h:11];
    }
    for (NSUInteger i = 0; i < [_toggles count]; ++i) {
        LRToggleSwitch *t = [_toggles objectAtIndex:i];
        UILabel *l = [_toggleCaptions objectAtIndex:i];
        t.hidden = l.hidden = !showToggles;
        if (!showToggles) continue;
        CGFloat cw = (W - side * 2) / [_toggles count];
        CGFloat cx = side + cw * i + cw / 2;
        CGSize ts = LR_TOGGLE_SIZE;
        CGFloat ty = keysY - togglesH - 6;
        [self place:t x:cx - ts.width / 2 y:ty w:ts.width h:ts.height];
        [self place:l x:cx - cw / 2 y:ty + ts.height + 6 w:cw h:12];
    }
    NSUInteger n = [_keys count];
    CGFloat kw = MIN(pad ? 170.0f : 120.0f, (W - side * 2 - (n - 1) * 8) / n);
    CGFloat kx = (W - (kw * n + 8 * (n - 1))) / 2;
    for (NSUInteger i = 0; i < n; ++i)
        [self place:[_keys objectAtIndex:i] x:kx + i * (kw + 8) y:keysY w:kw h:keysH];
}

#pragma mark state

- (NSString *)dialLabelFor:(LRServer *)sv {
    NSString *cc = [sv countryCode];
    if (cc) return [cc uppercaseString];
    NSString *name = [[LRCatalog shared] displayNameForServer:sv];
    return [[name substringToIndex:MIN((NSUInteger)4, [name length])] uppercaseString];
}

- (void)refreshDial {
    LRCatalog *catalog = [LRCatalog shared];
    LRServer *selected = [catalog selectedServer];
    LRSection *sec = selected ? [catalog sectionForServer:selected]
                              : ([catalog.sections count] ? [catalog.sections objectAtIndex:0] : nil);
    NSArray *all = sec.servers ? sec.servers : [NSArray array];
    NSUInteger maxStations = LRIsPad() ? 14 : 8;
    NSUInteger start = 0;
    if ([all count] > maxStations) {
        NSUInteger at = selected ? [all indexOfObjectIdenticalTo:selected] : 0;
        if (at == NSNotFound) at = 0;
        start = at > maxStations / 2 ? at - maxStations / 2 : 0;
        if (start + maxStations > [all count]) start = [all count] - maxStations;
    }
    NSArray *window = [all subarrayWithRange:NSMakeRange(start, MIN(maxStations, [all count] - start))];
    [_dialServers release];
    _dialServers = [window retain];
    NSMutableArray *labels = [NSMutableArray array];
    for (LRServer *sv in window) [labels addObject:[self dialLabelFor:sv]];
    _dial.labels = labels;
    NSUInteger sel = selected ? [window indexOfObjectIdenticalTo:selected] : NSNotFound;
    [_dial setSelectedIndex:sel == NSNotFound ? -1 : (NSInteger)sel animated:YES];
}

- (void)refresh {
    LRTunnel *t = [LRTunnel shared];
    LRCatalog *catalog = [LRCatalog shared];
    LRDaemonSettings *ds = [LRDaemonSettings shared];
    LRPowerState ps = LRPowerOff;
    switch (t.state) {
        case LRTunnelConnected: ps = LRPowerOn; break;
        case LRTunnelConnecting: ps = LRPowerTuning; break;
        case LRTunnelError: ps = LRPowerFault; break;
        default: break;
    }
    if (t.busy && ps == LRPowerOff) ps = LRPowerTuning;
    _power.powerState = ps;
    _display.status = t.busy && t.state != LRTunnelConnected ? L(@"TUNING...") : [t stateTitle];
    BOOL awg = [LRPrefs selectedBackend] == LRBackendAmneziaWG;
    LRServer *sv = [catalog selectedServer];
    if (awg) {
        _display.station = @"AmneziaWG";
        _display.countryCode = nil;
        _display.detail = L(@"WireGuard profile");
    } else if (sv) {
        _display.station = [catalog displayNameForServer:sv];
        _display.countryCode = [sv countryCode];
        NSNumber *ping = [catalog pingForServer:sv];
        NSString *detail = [sv protocolSummary];
        if (ping && [ping intValue] >= 0) detail = [detail stringByAppendingFormat:@"  ·  %d ms", [ping intValue]];
        _display.detail = detail;
    } else {
        _display.station = [catalog isEmpty] ? L(@"No stations") : L(@"Select a station");
        _display.countryCode = nil;
        _display.detail = [catalog isEmpty] ? L(@"Press IMPORT to add servers") : nil;
    }
    _display.message = t.state == LRTunnelError ? t.lastError : nil;
    if (t.state == LRTunnelError && [t.lastError length] && ![t.lastError isEqualToString:_shownError]) {
        [LRToast showError:t.lastError];
        [_shownError release];
        _shownError = [t.lastError copy];
    }
    if (t.state != LRTunnelError) {
        [_shownError release];
        _shownError = nil;
    }
    NSMutableSet *lit = [NSMutableSet set];
    if ([LRPrefs stealthMode]) [lit addObject:L(@"STEALTH")];
    if ([ds boolForKey:@"bypass_lan" fallback:YES]) [lit addObject:L(@"LAN")];
    if ([ds boolForKey:@"rules_enabled" fallback:YES]) [lit addObject:L(@"ROUTING")];
    if ([ds boolForKey:@"auto_reconnect" fallback:YES]) [lit addObject:L(@"AUTO")];
    _display.litLegends = lit;
    BOOL values[4] = { [ds boolForKey:@"auto_reconnect" fallback:YES],
                       [ds boolForKey:@"rules_enabled" fallback:YES],
                       [ds boolForKey:@"bypass_lan" fallback:YES], [LRPrefs stealthMode] };
    for (NSUInteger i = 0; i < [_toggles count]; ++i) {
        LRToggleSwitch *toggle = [_toggles objectAtIndex:i];
        if (toggle.on != values[i]) [toggle setOn:values[i] animated:YES];
    }
    [self refreshDial];
    [self tick];
}

- (void)tick {
    LRTunnel *t = [LRTunnel shared];
    BOOL on = t.state == LRTunnelConnected;
    _display.seconds = on ? [t liveUptime] : 0;
    _display.upText = on ? LRBytes(t.bytesUp) : nil;
    _display.downText = on ? LRBytes(t.bytesDown) : nil;
    [_upMeter setSpeed:on ? t.speedUp : 0];
    [_downMeter setSpeed:on ? t.speedDown : 0];
}

#pragma mark actions

- (void)powerPressed {
    [[LRTunnel shared] toggle];
}

- (void)dialChanged {
    NSInteger i = _dial.selectedIndex;
    if (i < 0 || i >= (NSInteger)[_dialServers count]) return;
    LRServer *sv = [_dialServers objectAtIndex:(NSUInteger)i];
    [LRPrefs setSelectedBackend:LRBackendServer];
    LRTunnel *t = [LRTunnel shared];
    if ([t isOn] && t.activeBackend == LRBackendServer && sv.index != [LRCatalog shared].selectedIndex)
        [t connectServerIndex:sv.index];
    else {
        [LRCatalog shared].selectedIndex = sv.index;
        [self refresh];
    }
}

- (void)toggleChanged:(LRToggleSwitch *)t {
    LRDaemonSettings *ds = [LRDaemonSettings shared];
    switch (t.tag) {
        case 0: [ds setBool:t.on forKey:@"auto_reconnect"]; break;
        case 1:
            [ds setBool:t.on forKey:@"rules_enabled"];
            if ([[LRTunnel shared] isOn]) [LRToast show:L(@"Reconnect the VPN to apply routing changes.")];
            break;
        case 2:
            [ds setBool:t.on forKey:@"bypass_lan"];
            if ([[LRTunnel shared] isOn]) [LRToast show:L(@"Reconnect the VPN to apply routing changes.")];
            break;
        case 3: [LRPrefs setStealthMode:t.on]; break;
    }
}

- (void)displayTapped {
    LRServer *sv = [[LRCatalog shared] selectedServer];
    if (_embedded) {
        if (sv) [self presentSheet:[[[LRStationScreen alloc] initWithServer:sv] autorelease]];
        return;
    }
    [self openStations];
}

- (void)openStations {
    [self openScreen:[[[LRStationsScreen alloc] init] autorelease]];
}

- (void)openSettings {
    [self presentSheet:[[[LRSettingsScreen alloc] init] autorelease]];
}

- (void)openCheck {
    [self presentSheet:[[[LRConnectionCheckScreen alloc] init] autorelease]];
}
@end
