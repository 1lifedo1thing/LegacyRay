#import "LRManualInputScreen.h"
#import "LRImporter.h"
#import "LRDraw.h"

@implementation LRManualInputScreen

- (id)init {
    if ((self = [super init])) self.title = L(@"Manual Input");
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_well release];
    [_hint release];
    [_paste release];
    [_import release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    LRSkin *s = SKIN;
    __block LRManualInputScreen *me = self;
    _hint = [[UILabel alloc] init];
    _hint.backgroundColor = [UIColor clearColor];
    _hint.numberOfLines = 0;
    _hint.font = [LRSkin bodyFont:13];
    _hint.textColor = s->groupHeader;
    _hint.shadowColor = s->flat ? nil : s->groupHeaderShadow;
    _hint.shadowOffset = CGSizeMake(0, 1);
    _hint.text = L(@"vless://, trojan://, ss://, socks5://, hysteria2:// and happ:// links, subscription URLs, base64 lists, Xray / sing-box JSON, Clash YAML and WireGuard / AmneziaWG profiles. One or many.");
    [self.contentView addSubview:_hint];
    _well = [[LRTextWell alloc] initWithFrame:CGRectMake(0, 0, 300, 200)];
    [self.contentView addSubview:_well];
    _paste = [[LRButton buttonWithStyle:LRButtonMetal title:L(@"Paste") action:^(LRButton *b) {
        NSString *clip = [UIPasteboard generalPasteboard].string;
        if (clip) me->_well.textView.text = clip;
    }] retain];
    _import = [[LRButton buttonWithStyle:LRButtonGreen title:L(@"Import") action:^(LRButton *b) {
        NSString *text = [[me->_well.textView.text copy] autorelease];
        [me close];
        [LRImporter importText:text];
    }] retain];
    for (LRButton *b in [NSArray arrayWithObjects:_paste, _import, nil]) {
        b.frame = CGRectMake(0, 0, 100, 42);
        b.titleLabel.font = [LRSkin boldFont:15];
        [self.contentView addSubview:b];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboard:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboard:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_well.textView becomeFirstResponder];
}

- (void)keyboard:(NSNotification *)note {
    _keyboard = 0;
    if ([[note name] isEqualToString:UIKeyboardWillShowNotification]) {
        CGRect kb = [[[note userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
        kb = [self.contentView convertRect:kb fromView:nil];
        _keyboard = MAX(0, CGRectGetMaxY(self.contentView.bounds) - kb.origin.y);
    }
    [UIView animateWithDuration:0.25 animations:^{ [self layoutContent]; }];
}

- (CGFloat)keyboardOverlap {
    return _keyboard;
}

- (void)layoutContent {
    CGRect b = self.contentView.bounds;
    CGFloat pad = LRIsPad() ? 20 : 12;
    CGFloat w = b.size.width - pad * 2;
    CGSize hs = [_hint.text sizeWithFont:_hint.font constrainedToSize:CGSizeMake(w, 200)];
    _hint.frame = CGRectMake(pad, 12, w, ceilf(hs.height));
    CGFloat bottom = b.size.height - [self keyboardOverlap];
    CGFloat buttonsY = bottom - 54;
    _well.frame = CGRectMake(pad, CGRectGetMaxY(_hint.frame) + 10, w, MAX(80, buttonsY - CGRectGetMaxY(_hint.frame) - 20));
    CGFloat bw = (w - 10) / 2;
    _paste.frame = CGRectMake(pad, buttonsY, bw, 42);
    _import.frame = CGRectMake(pad + bw + 10, buttonsY, bw, 42);
}
@end
