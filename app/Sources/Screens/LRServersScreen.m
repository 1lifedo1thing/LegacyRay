#import "LRServersScreen.h"
#import "LRSSH.h"
#import "LRAlert.h"
#import "LRToast.h"
#import "LRMenu.h"
#import "LRImporter.h"
#import "LRAWGProfiles.h"
#import "LRShareScreen.h"
#import "LRSimpleScreens.h"
#import "LRActivityLog.h"
#import "LRDraw.h"
#include "b64.h"

/* this phone's name, fit for a client label on the server */
static NSString *LRClientLabel(NSString *preferred) {
    NSString *raw = [preferred length] ? preferred : [[UIDevice currentDevice] name];
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < [raw length] && [out length] < 24; ++i) {
        unichar c = [raw characterAtIndex:i];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
            c == '.' || c == '-' || c == '_')
            [out appendFormat:@"%C", c];
        else if (c == ' ' && [out length] && ![out hasSuffix:@"-"])
            [out appendString:@"-"];
    }
    while ([out hasSuffix:@"-"]) [out deleteCharactersInRange:NSMakeRange([out length] - 1, 1)];
    return [out length] ? out : @"iphone";
}

static NSString *LRDecodeB64(NSString *text) {
    NSData *in = [text dataUsingEncoding:NSASCIIStringEncoding];
    size_t cap = b64_decoded_maxlen([in length]) + 1;
    unsigned char *out = malloc(cap);
    size_t n = 0;
    NSString *s = nil;
    if (out && b64_decode([in bytes], [in length], out, cap, &n) == 0)
        s = [[[NSString alloc] initWithBytes:out length:n encoding:NSUTF8StringEncoding] autorelease];
    free(out);
    return s;
}

#pragma mark log

@implementation LRServerLogScreen
@synthesize job = _job;

- (id)init {
    if ((self = [super init])) {
        _text = [[NSMutableString alloc] init];
        _backgroundStyle = LRBackgroundLinen;
    }
    return self;
}

- (void)dealloc {
    [_job cancel];
    [_job release];
    [_log release];
    [_stage release];
    [_text release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    LRSkin *s = SKIN;
    _stage = [[UILabel alloc] init];
    _stage.backgroundColor = [UIColor clearColor];
    _stage.font = [LRSkin boldFont:15];
    _stage.textColor = s->flat ? s->groupInk : s->engrave;
    _stage.numberOfLines = 2;
    [self.contentView addSubview:_stage];
    _log = [[UITextView alloc] init];
    _log.editable = NO;
    _log.font = [LRSkin monoFont:LRIsPad() ? 12 : 10];
    _log.backgroundColor = s->flat ? [UIColor whiteColor]
                                   : [UIColor colorWithRed:0.08f green:0.09f blue:0.08f alpha:1];
    _log.textColor = s->flat ? [UIColor colorWithWhite:0.15f alpha:1]
                             : [UIColor colorWithRed:0.55f green:0.95f blue:0.55f alpha:1];
    if (!s->flat) _log.layer.cornerRadius = 6;
    _log.text = _text;
    [self.contentView addSubview:_log];
}

- (void)layoutContent {
    CGRect b = self.contentView.bounds;
    CGFloat pad = SKIN->flat ? 12 : 10;
    _stage.frame = CGRectMake(pad, 8, b.size.width - pad * 2, 40);
    _log.frame = CGRectMake(pad, 52, b.size.width - pad * 2, b.size.height - 52 - pad);
}

- (void)setStage:(NSString *)stage {
    _stage.text = stage;
}

- (void)appendLine:(NSString *)line {
    [_text appendString:line];
    [_text appendString:@"\n"];
    if ([_text length] > 60000) [_text deleteCharactersInRange:NSMakeRange(0, [_text length] - 50000)];
    _log.text = _text;
    if ([_text length]) [_log scrollRangeToVisible:NSMakeRange([_text length] - 1, 1)];
}
@end

#pragma mark list

@implementation LRServersScreen

- (id)init {
    if ((self = [super init])) self.title = L(@"Own servers");
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    __block LRServersScreen *me = self;
    [self.header setRightGlyph:LRGlyphPlus(16, [LRHeaderBar glyphColor]) action:^(LRButton *b) {
        [me openScreen:[[[LRServerSetupScreen alloc] init] autorelease]];
    }];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSections)
                                                 name:LRServerHostsDidChangeNotification object:nil];
}

- (NSArray *)buildSections {
    __block LRServersScreen *me = self;
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *rows = [NSMutableArray array];
    for (LRServerHost *h in [LRServerHosts hosts]) {
        NSMutableArray *what = [NSMutableArray array];
        if (h.hasXray) [what addObject:@"Xray Reality"];
        if (h.hasAWG) [what addObject:@"AmneziaWG"];
        LRRow *row = [LRRow value:[h displayName] detail:nil action:^(LRRow *r, UIView *c) {
            [me openScreen:[[[LRServerScreen alloc] initWithHost:h] autorelease]];
        }];
        row.subtitle = [what count] ? [what componentsJoinedByString:@" · "] : LRStealth(h.host);
        row.chevron = YES;
        [rows addObject:row];
    }
    if ([rows count])
        [sections addObject:[LRSectionSpec header:L(@"Servers") rows:rows footer:nil]];
    [sections addObject:[LRSectionSpec header:nil rows:[NSArray arrayWithObjects:
        [LRRow button:L(@"Set up a server") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [me openScreen:[[[LRServerSetupScreen alloc] init] autorelease]];
        }], nil]
                                       footer:L(@"Rent any VPS with Ubuntu or Debian, give LegacyRay its address and root password (or key), and it installs Xray Reality and, on Ubuntu, AmneziaWG. You get the connections here and can share them with others.")]];
    return sections;
}
@end

#pragma mark setup

@implementation LRServerSetupScreen

- (id)init {
    if ((self = [super init])) {
        self.title = L(@"New server");
        _host = [[LRServerHost alloc] init];
        _host.port = 22;
        _host.user = @"root";
        _xray = YES;
        _sni = [@"www.microsoft.com" copy];
    }
    return self;
}

- (void)dealloc {
    [_host release];
    [_sni release];
    [super dealloc];
}

- (void)prompt:(NSString *)title value:(NSString *)value placeholder:(NSString *)placeholder
        secure:(BOOL)secure number:(BOOL)number done:(void (^)(NSString *))done {
    LRAlert *a = [LRAlert alertWithTitle:title message:nil];
    UITextField *f = [a addFieldWithPlaceholder:placeholder text:value];
    f.secureTextEntry = secure;
    f.autocorrectionType = UITextAutocorrectionTypeNo;
    f.autocapitalizationType = UITextAutocapitalizationTypeNone;
    if (number) f.keyboardType = UIKeyboardTypeNumberPad;
    void (^block)(NSString *) = [[done copy] autorelease];
    [a addButton:L(@"Cancel") style:LRButtonMetal action:nil];
    [a addButton:L(@"Save") style:LRButtonGreen action:^(LRAlert *alert) {
        block(LRTrim([alert textAtIndex:0]));
    }];
    [a show];
}

- (NSArray *)buildSections {
    __block LRServerSetupScreen *me = self;
    NSMutableArray *sections = [NSMutableArray array];
    BOOL key = _host.auth == LRSSHAuthKey;
    NSMutableArray *server = [NSMutableArray array];
    [server addObject:[LRRow value:L(@"Address") detail:_host.host ? LRStealth(_host.host) : L(@"Not set")
                            action:^(LRRow *r, UIView *c) {
        [me prompt:L(@"Server address") value:me->_host.host placeholder:@"203.0.113.10" secure:NO number:NO
              done:^(NSString *v) { me->_host.host = v; [me reloadSections]; }];
    }]];
    [server addObject:[LRRow value:L(@"SSH port") detail:[NSString stringWithFormat:@"%ld", (long)_host.port]
                            action:^(LRRow *r, UIView *c) {
        [me prompt:L(@"SSH port") value:[NSString stringWithFormat:@"%ld", (long)me->_host.port]
       placeholder:@"22" secure:NO number:YES done:^(NSString *v) {
            NSInteger p = [v integerValue];
            if (p > 0 && p < 65536) me->_host.port = p;
            [me reloadSections];
        }];
    }]];
    [server addObject:[LRRow value:L(@"User") detail:_host.user action:^(LRRow *r, UIView *c) {
        [me prompt:L(@"User") value:me->_host.user placeholder:@"root" secure:NO number:NO
              done:^(NSString *v) { if ([v length]) me->_host.user = v; [me reloadSections]; }];
    }]];
    [server addObject:[LRRow check:L(@"Sign in with a password") on:!key action:^(LRRow *r, UIView *c) {
        me->_host.auth = LRSSHAuthPassword; me->_host.secret = nil; [me reloadSections];
    }]];
    [server addObject:[LRRow check:L(@"Sign in with a private key") on:key action:^(LRRow *r, UIView *c) {
        me->_host.auth = LRSSHAuthKey; me->_host.secret = nil; [me reloadSections];
    }]];
    if (key) {
        [server addObject:[LRRow value:L(@"Private key") detail:[_host.secret length] ? L(@"Pasted") : L(@"Not set")
                                action:^(LRRow *r, UIView *c) {
            NSString *clip = [UIPasteboard generalPasteboard].string;
            if ([clip rangeOfString:@"PRIVATE KEY"].location == NSNotFound) {
                [LRToast showError:L(@"Copy the private key (-----BEGIN ... PRIVATE KEY-----) first")];
                return;
            }
            me->_host.secret = clip;
            [LRToast showSuccess:L(@"Key taken from the clipboard")];
            [me reloadSections];
        }]];
        [server addObject:[LRRow value:L(@"Key passphrase") detail:[_host.passphrase length] ? @"••••" : L(@"None")
                                action:^(LRRow *r, UIView *c) {
            [me prompt:L(@"Key passphrase") value:nil placeholder:L(@"Passphrase") secure:YES number:NO
                  done:^(NSString *v) { me->_host.passphrase = v; [me reloadSections]; }];
        }]];
    } else {
        [server addObject:[LRRow value:L(@"Password") detail:[_host.secret length] ? @"••••••" : L(@"Not set")
                                action:^(LRRow *r, UIView *c) {
            [me prompt:L(@"Password") value:nil placeholder:L(@"Password") secure:YES number:NO
                  done:^(NSString *v) { me->_host.secret = v; [me reloadSections]; }];
        }]];
    }
    [sections addObject:[LRSectionSpec header:L(@"Server") rows:server
                                       footer:L(@"The sign-in stays on this phone, in a file only this app can read, so the server can be managed later.")]];

    NSArray *snis = [NSArray arrayWithObjects:@"www.microsoft.com", @"www.apple.com", @"dl.google.com",
                     @"www.samsung.com", @"www.nvidia.com", nil];
    [sections addObject:[LRSectionSpec header:L(@"Install") rows:[NSArray arrayWithObjects:
        [LRRow toggle:@"Xray Reality" on:_xray changed:^(BOOL on) { me->_xray = on; }],
        [LRRow toggle:@"AmneziaWG" on:_awg changed:^(BOOL on) { me->_awg = on; }],
        [LRRow value:L(@"Reality disguise site") detail:_sni action:^(LRRow *r, UIView *c) {
            NSUInteger sel = [snis indexOfObject:me->_sni];
            LRChoiceScreen *choice = [[[LRChoiceScreen alloc] initWithTitle:L(@"Reality disguise site") options:snis
                selected:sel == NSNotFound ? -1 : (NSInteger)sel picked:^(NSInteger i) {
                [me->_sni release];
                me->_sni = [[snis objectAtIndex:(NSUInteger)i] copy];
            }] autorelease];
            choice.footer = L(@"Reality presents this site's certificate to anyone probing the server. A big site that speaks TLS 1.3 and HTTP/2 works best.");
            [me openScreen:choice];
        }], nil]
                                       footer:L(@"Xray Reality works on any Linux with systemd. AmneziaWG needs Ubuntu and a VPS that allows kernel modules (KVM, not OpenVZ/LXC).")]];

    [sections addObject:[LRSectionSpec header:nil rows:[NSArray arrayWithObjects:
        [LRRow button:_working ? L(@"Working...") : L(@"Connect and install") style:LRRowStyleAccent
               action:^(LRRow *r, UIView *c) { [me start]; }], nil]
                                       footer:L(@"The install takes a few minutes. The server needs internet access to download packages.")]];
    return sections;
}

- (void)start {
    if (_working) return;
    if (![_host.host length]) { [LRToast showError:L(@"Enter the server address")]; return; }
    if (![_host.secret length]) {
        [LRToast showError:_host.auth == LRSSHAuthKey ? L(@"Paste the private key") : L(@"Enter the password")];
        return;
    }
    if (!_xray && !_awg) { [LRToast showError:L(@"Choose what to install")]; return; }
    _working = YES;
    [self reloadSections];
    [LRToast show:L(@"Connecting...")];
    __block LRServerSetupScreen *me = self;
    [self retain];
    [LRSSHJob probeKeyOf:_host done:^(NSString *type, NSString *hash, NSString *error) {
        if (!hash) {
            me->_working = NO;
            [me reloadSections];
            [LRToast showError:error];
            [me release];
            return;
        }
        NSString *msg = [NSString stringWithFormat:L(@"%@ answered with the key\n%@\n%@\nIf your provider shows the server's key, compare them."),
                         me->_host.host, type, LRSSHFingerprint(hash)];
        [LRAlert confirmTitle:L(@"Is this your server?") message:msg button:L(@"Trust and continue")
                  destructive:NO action:^{
            me->_host.hostKey = hash;
            me->_host.hostKeyType = type;
            [LRServerHosts save:me->_host];
            [me install];
            [me release];
        } cancel:^{
            me->_working = NO;
            [me reloadSections];
            [me release];
        }];
    }];
}

- (void)install {
    LRServerLogScreen *log = [[[LRServerLogScreen alloc] init] autorelease];
    log.title = L(@"Installing");
    [self openScreen:log];
    NSMutableArray *commands = [NSMutableArray array];
    if (_xray) [commands addObject:@"install-xray"];
    if (_awg) [commands addObject:@"install-awg"];
    NSDictionary *vars = [NSDictionary dictionaryWithObjectsAndKeys:LRClientLabel(nil), @"LR_NAME", _sni, @"LR_SNI", nil];
    NSMutableArray *links = [NSMutableArray array];
    NSMutableArray *confs = [NSMutableArray array];
    NSMutableArray *errors = [NSMutableArray array];
    [self runCommands:commands at:0 vars:vars log:log links:links confs:confs errors:errors];
}

- (void)runCommands:(NSArray *)commands at:(NSUInteger)i vars:(NSDictionary *)vars
                log:(LRServerLogScreen *)log links:(NSMutableArray *)links confs:(NSMutableArray *)confs
             errors:(NSMutableArray *)errors {
    __block LRServerSetupScreen *me = self;
    if (i >= [commands count]) {
        [self finishWithLog:log links:links confs:confs errors:errors];
        return;
    }
    NSString *cmd = [commands objectAtIndex:i];
    [log setStage:[cmd isEqualToString:@"install-xray"] ? L(@"Installing Xray Reality...") : L(@"Installing AmneziaWG...")];
    [log appendLine:[NSString stringWithFormat:@"== %@", cmd]];
    [self retain];
    log.job = [LRSSHJob run:cmd vars:vars on:_host line:^(NSString *kind, NSString *text) {
        if ([kind isEqualToString:@"STEP"]) { [log setStage:text]; [log appendLine:[@"• " stringByAppendingString:text]]; }
        else if ([kind isEqualToString:@"LINK"]) { [links addObject:text]; [log appendLine:L(@"• a connection is ready")]; }
        else if ([kind isEqualToString:@"CONF"]) {
            NSString *conf = LRDecodeB64(text);
            if (conf) [confs addObject:conf];
            [log appendLine:L(@"• a connection is ready")];
        }
        else if ([kind isEqualToString:@"ERROR"]) [log appendLine:[@"✗ " stringByAppendingString:text]];
        else if ([kind isEqualToString:@"INFO"]) [log appendLine:[@"  " stringByAppendingString:text]];
        else if ([kind isEqualToString:@"STAGE"]) [log appendLine:[@"  ssh: " stringByAppendingString:text]];
        else if (![kind isEqualToString:@"DONE"]) [log appendLine:text];
    } done:^(BOOL ok, NSString *error) {
        if (ok) {
            if ([cmd isEqualToString:@"install-xray"]) me->_host.hasXray = YES;
            else me->_host.hasAWG = YES;
            [LRServerHosts save:me->_host];
        } else {
            [errors addObject:error ? error : cmd];
            [log appendLine:[@"✗ " stringByAppendingString:error ? error : cmd]];
        }
        [me runCommands:commands at:i + 1 vars:vars log:log links:links confs:confs errors:errors];
        [me release];
    }];
}

- (void)finishWithLog:(LRServerLogScreen *)log links:(NSArray *)links confs:(NSArray *)confs
               errors:(NSArray *)errors {
    _working = NO;
    [self reloadSections];
    NSString *serverName = [_host displayName];
    for (NSString *link in links) [LRImporter importText:link];
    for (NSString *conf in confs)
        [LRAWGProfiles addConfig:conf name:[NSString stringWithFormat:@"%@ · AWG", serverName]
                            done:^(LRAWGProfile *p, NSString *error) {
            if (!p) [LRToast showError:error];
        }];
    NSUInteger made = [links count] + [confs count];
    if (made) {
        LRLog(@"server", @"own server set up with %lu connection(s)", (unsigned long)made);
        [log setStage:[errors count] ? L(@"Partly done: see the log") : L(@"Done. The connections are in the station log.")];
        [LRToast showSuccess:L(@"Your server is ready")];
    } else {
        [log setStage:L(@"The install failed: see the log")];
        [LRToast showError:[errors count] ? [errors objectAtIndex:0] : L(@"The install failed")];
    }
}
@end

#pragma mark one server

@implementation LRServerScreen

- (id)initWithHost:(LRServerHost *)host {
    if ((self = [super init])) {
        _host = [host retain];
        self.title = [host displayName];
        _info = [[NSMutableDictionary alloc] init];
        _clients = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_job cancel];
    [_job release];
    [_host release];
    [_info release];
    [_clients release];
    [_status release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self refresh];
}

- (void)setStatusText:(NSString *)text {
    [_status release];
    _status = [text copy];
    [self reloadSections];
}

- (void)refresh {
    if (_loading) return;
    _loading = YES;
    [_info removeAllObjects];
    [_clients removeAllObjects];
    [self setStatusText:L(@"Asking the server...")];
    __block LRServerScreen *me = self;
    [self retain];
    [_job release];
    _job = [[LRSSHJob run:@"status" vars:nil on:_host line:^(NSString *kind, NSString *text) {
        NSRange sp = [text rangeOfString:@" "];
        if ([kind isEqualToString:@"INFO"] && sp.location != NSNotFound)
            [me->_info setObject:[text substringFromIndex:sp.location + 1] forKey:[text substringToIndex:sp.location]];
        else if ([kind isEqualToString:@"CLIENT"] && sp.location != NSNotFound)
            [me->_clients addObject:[NSArray arrayWithObjects:[text substringToIndex:sp.location],
                                     [text substringFromIndex:sp.location + 1], nil]];
    } done:^(BOOL ok, NSString *error) {
        me->_loading = NO;
        [me setStatusText:ok ? nil : error];
        [me release];
    }] retain];
}

/* run a management command; links and configs it prints are shared */
- (void)run:(NSString *)cmd vars:(NSDictionary *)vars title:(NSString *)title {
    __block LRServerScreen *me = self;
    [self setStatusText:title];
    NSMutableArray *links = [NSMutableArray array];
    NSMutableArray *confs = [NSMutableArray array];
    NSString *clientName = [vars objectForKey:@"LR_NAME"];
    [self retain];
    [LRSSHJob run:cmd vars:vars on:_host line:^(NSString *kind, NSString *text) {
        if ([kind isEqualToString:@"LINK"]) [links addObject:text];
        else if ([kind isEqualToString:@"CONF"]) { NSString *c = LRDecodeB64(text); if (c) [confs addObject:c]; }
        else if ([kind isEqualToString:@"STEP"]) [me setStatusText:text];
    } done:^(BOOL ok, NSString *error) {
        [me setStatusText:ok ? nil : error];
        if (!ok) [LRToast showError:error];
        NSString *payload = [links count] ? [links objectAtIndex:0] : ([confs count] ? [confs objectAtIndex:0] : nil);
        if (ok && payload) {
            LRShareScreen *share = [[[LRShareScreen alloc] initWithTitle:clientName ? clientName : [me->_host displayName]
                                                                 payload:payload] autorelease];
            if ([confs count]) share.fileName = [(clientName ? clientName : @"amneziawg") stringByAppendingString:@".conf"];
            share.subtitle = [links count] ? @"Xray Reality" : @"AmneziaWG";
            [me openScreen:share];
        }
        if (ok) {
            me->_loading = NO;
            [me refresh];
        }
        [me release];
    }];
}

- (void)addClient {
    __block LRServerScreen *me = self;
    void (^ask)(NSString *) = ^(NSString *proto) {
        [LRAlert promptTitle:L(@"New client") message:L(@"A name for the person or device (letters, digits, dots, dashes)")
                 placeholder:@"friend" text:nil button:L(@"Create") done:^(NSString *value) {
            NSString *name = LRClientLabel(value);
            [me run:@"add-client" vars:[NSDictionary dictionaryWithObjectsAndKeys:proto, @"LR_PROTO", name, @"LR_NAME", nil]
              title:L(@"Creating the client...")];
        }];
    };
    if (_host.hasXray && _host.hasAWG) {
        LRMenu *menu = [LRMenu menuWithTitle:L(@"New client")];
        [menu addItem:@"Xray Reality" action:^{ ask(@"xray"); }];
        [menu addItem:@"AmneziaWG" action:^{ ask(@"awg"); }];
        [menu showFromView:self.header];
    } else {
        ask(_host.hasAWG ? @"awg" : @"xray");
    }
}

- (void)clientMenu:(NSArray *)client from:(UIView *)anchor {
    __block LRServerScreen *me = self;
    NSString *proto = [client objectAtIndex:0], *name = [client objectAtIndex:1];
    LRMenu *menu = [LRMenu menuWithTitle:name];
    if ([proto isEqualToString:@"xray"])
        [menu addItem:L(@"Share") action:^{
            [me run:@"share-client" vars:[NSDictionary dictionaryWithObjectsAndKeys:@"xray", @"LR_PROTO", name, @"LR_NAME", nil]
              title:L(@"Asking the server...")];
        }];
    [menu addDestructiveItem:L(@"Revoke access") action:^{
        [LRAlert confirmTitle:L(@"Revoke access") message:name button:L(@"Revoke") destructive:YES action:^{
            [me run:@"remove-client" vars:[NSDictionary dictionaryWithObjectsAndKeys:proto, @"LR_PROTO", name, @"LR_NAME", nil]
              title:L(@"Revoking...")];
        }];
    }];
    [menu showFromView:anchor];
}

- (NSArray *)buildSections {
    __block LRServerScreen *me = self;
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *state = [NSMutableArray array];
    [state addObject:[LRRow value:L(@"Address") detail:LRStealth([NSString stringWithFormat:@"%@:%ld", _host.host, (long)_host.port])
                          action:nil]];
    NSString *xray = [_info objectForKey:@"xray"];
    if (xray) {
        NSString *port = [_info objectForKey:@"xray-port"];
        LRRow *row = [LRRow value:@"Xray Reality" detail:[NSString stringWithFormat:@"%@%@", xray,
                                                          port ? [@" · " stringByAppendingString:port] : @""] action:nil];
        row.detailColor = [xray isEqualToString:@"active"] ? SKIN->good : SKIN->bad;
        [state addObject:row];
    }
    NSString *awg = [_info objectForKey:@"awg"];
    if (awg) {
        NSString *port = [_info objectForKey:@"awg-port"];
        LRRow *row = [LRRow value:@"AmneziaWG" detail:[NSString stringWithFormat:@"%@%@", awg,
                                                       port ? [@" · " stringByAppendingString:port] : @""] action:nil];
        row.detailColor = [awg isEqualToString:@"active"] ? SKIN->good : SKIN->bad;
        [state addObject:row];
    }
    if ([_info objectForKey:@"uptime"]) [state addObject:[LRRow value:L(@"Uptime") detail:[_info objectForKey:@"uptime"] action:nil]];
    if ([_info objectForKey:@"load"]) [state addObject:[LRRow value:L(@"Load") detail:[_info objectForKey:@"load"] action:nil]];
    if (_host.hostKey)
        [state addObject:[LRRow value:L(@"Host key") detail:LRSSHFingerprint(_host.hostKey) action:nil]];
    [sections addObject:[LRSectionSpec header:[_host displayName] rows:state footer:_status]];

    NSMutableArray *clients = [NSMutableArray array];
    for (NSArray *c in _clients) {
        NSArray *client = c;
        LRRow *row = [LRRow value:[client objectAtIndex:1]
                           detail:[[client objectAtIndex:0] isEqualToString:@"xray"] ? @"Reality" : @"AWG"
                           action:^(LRRow *r, UIView *cell) { [me clientMenu:client from:cell]; }];
        [clients addObject:row];
    }
    if (_host.hasXray || _host.hasAWG)
        [clients addObject:[LRRow button:L(@"Add a client") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [me addClient];
        }]];
    [sections addObject:[LRSectionSpec header:L(@"Clients") rows:clients
                                       footer:L(@"Each client gets its own key: give one to each person or device, and revoke it without touching the others.")]];

    NSMutableArray *actions = [NSMutableArray array];
    [actions addObject:[LRRow button:L(@"Refresh") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) { [me refresh]; }]];
    if (!_host.hasXray)
        [actions addObject:[LRRow button:L(@"Install Xray Reality") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [me run:@"install-xray" vars:[NSDictionary dictionaryWithObjectsAndKeys:LRClientLabel(nil), @"LR_NAME", nil]
              title:L(@"Installing Xray Reality...")];
            me->_host.hasXray = YES;
            [LRServerHosts save:me->_host];
        }]];
    if (!_host.hasAWG)
        [actions addObject:[LRRow button:L(@"Install AmneziaWG") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
            [me run:@"install-awg" vars:[NSDictionary dictionaryWithObjectsAndKeys:LRClientLabel(nil), @"LR_NAME", nil]
              title:L(@"Installing AmneziaWG...")];
            me->_host.hasAWG = YES;
            [LRServerHosts save:me->_host];
        }]];
    [actions addObject:[LRRow button:L(@"Restart the services") style:LRRowStyleAccent action:^(LRRow *r, UIView *c) {
        [me run:@"restart" vars:nil title:L(@"Restarting...")];
    }]];
    [actions addObject:[LRRow button:L(@"Remove from the server") style:LRRowStyleDestructive action:^(LRRow *r, UIView *c) {
        [LRAlert confirmTitle:L(@"Remove from the server")
                      message:L(@"Xray and AmneziaWG are stopped and their configuration is deleted. Every client loses access.")
                       button:L(@"Remove") destructive:YES action:^{
            [me run:@"uninstall" vars:nil title:L(@"Removing...")];
            me->_host.hasXray = NO;
            me->_host.hasAWG = NO;
            [LRServerHosts save:me->_host];
        }];
    }]];
    [actions addObject:[LRRow button:L(@"Forget this server") style:LRRowStyleDestructive action:^(LRRow *r, UIView *c) {
        [LRAlert confirmTitle:L(@"Forget this server")
                      message:L(@"Only the saved sign-in is deleted from this phone. The server keeps running.")
                       button:L(@"Forget") destructive:YES action:^{
            [LRServerHosts remove:me->_host];
            [me close];
        }];
    }]];
    [sections addObject:[LRSectionSpec header:nil rows:actions footer:nil]];
    return sections;
}
@end
