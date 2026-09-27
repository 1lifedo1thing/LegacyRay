#import "LRShareScreen.h"
#import "LRQRCode.h"
#import "LRImporter.h"
#import "LRMenu.h"
#import "LRToast.h"
#import "LRDraw.h"
#import "LRSound.h"
#import "LRPrefs.h"

/* the card the code sits on: a paper card on the classic finishes, a plain
   white one with a hairline in flat */
@interface LRShareCard : UIView
@end

@implementation LRShareCard
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    if (SKIN->flat) {
        CGRect r = CGRectInset(b, 0.5f, 0.5f);
        LRAddRoundRect(ctx, r, 12);
        CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextFillPath(ctx);
        LRAddRoundRect(ctx, r, 12);
        CGContextSetStrokeColorWithColor(ctx, SKIN->separator.CGColor);
        CGContextSetLineWidth(ctx, 1.0f / [UIScreen mainScreen].scale);
        CGContextStrokePath(ctx);
        return;
    }
    LRDrawPaperCard(ctx, CGRectInset(b, 3, 3), 8);
}
@end

@implementation LRShareScreen
@synthesize subtitle = _subtitle, fileName = _fileName;

- (id)initWithTitle:(NSString *)title payload:(NSString *)payload {
    if ((self = [super init])) {
        self.title = title;
        _payload = [payload copy];
        _backgroundStyle = LRBackgroundLeather;
    }
    return self;
}

- (void)dealloc {
    [_payload release];
    [_subtitle release];
    [_fileName release];
    [_card release];
    [_qr release];
    [_nameLabel release];
    [_textLabel release];
    [_note release];
    [_copyButton release];
    [_sendButton release];
    [_revealButton release];
    _document.delegate = nil;
    [_document release];
    [super dealloc];
}

- (UILabel *)label:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *l = [[UILabel alloc] init];
    l.backgroundColor = [UIColor clearColor];
    l.font = font;
    l.textColor = color;
    l.textAlignment = NSTextAlignmentCenter;
    l.numberOfLines = lines;
    return l;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    LRSkin *s = SKIN;
    __block LRShareScreen *me = self;
    _card = [[LRShareCard alloc] init];
    [self.contentView addSubview:_card];
    _qr = [[UIImageView alloc] init];
    _qr.contentMode = UIViewContentModeCenter;
    _qr.userInteractionEnabled = YES;
    [_qr addGestureRecognizer:[[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                       action:@selector(reveal)] autorelease]];
    [_card addSubview:_qr];
    UIColor *ink = s->flat ? [UIColor colorWithWhite:0.1f alpha:1] : s->cardInk;
    _nameLabel = [self label:s->flat ? [LRSkin boldFont:17] : [LRSkin titleFont:18] color:ink lines:1];
    _nameLabel.text = self.title;
    [_card addSubview:_nameLabel];
    _textLabel = [self label:[LRSkin monoFont:11] color:s->flat ? s->groupMuted : s->cardMuted lines:3];
    _textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [_card addSubview:_textLabel];
    _note = [self label:[LRSkin bodyFont:13] color:s->flat ? s->groupMuted : LRColorAlpha(s->stitch, 0.9f) lines:0];
    [self.contentView addSubview:_note];

    _copyButton = [[LRButton buttonWithStyle:LRButtonMetal title:L(@"Copy") action:^(LRButton *b) {
        [UIPasteboard generalPasteboard].string = me->_payload ? me->_payload : @"";
        [LRSound click];
        [LRToast showSuccess:L(@"Copied to the clipboard")];
    }] retain];
    _sendButton = [[LRButton buttonWithStyle:LRButtonGreen title:L(@"Send...") action:^(LRButton *b) {
        [me showSendMenu:b];
    }] retain];
    _revealButton = [[LRButton buttonWithStyle:LRButtonMetal title:L(@"Show the code") action:^(LRButton *b) {
        [me reveal];
    }] retain];
    [self.contentView addSubview:_copyButton];
    [self.contentView addSubview:_sendButton];
    [self.contentView addSubview:_revealButton];
    _revealed = ![LRPrefs stealthMode];
    [self refreshCode];
}

- (void)reveal {
    if (_revealed) return;
    _revealed = YES;
    [self refreshCode];
    [self layoutContent];
}

- (CGFloat)qrSide {
    CGRect b = self.contentView.bounds;
    CGFloat side = MIN(b.size.width - 72, b.size.height - 230);
    return MAX(120, MIN(side, LRIsPad() ? 440 : 300));
}

- (void)refreshCode {
    CGFloat side = [self qrSide];
    int version = LRQRVersionForText(_payload);
    if (!_revealed) {
        _qr.image = nil;
        _qr.backgroundColor = SKIN->flat ? [UIColor colorWithWhite:0.93f alpha:1]
                                         : [UIColor colorWithWhite:0.5f alpha:0.18f];
        _qr.layer.cornerRadius = 6;
    } else {
        _qr.backgroundColor = [UIColor clearColor];
        _qr.image = version ? LRQRImage(_payload, side) : nil;
    }
    _textLabel.text = _revealed ? _payload : LRStealth(_payload);
    if (_subtitle) _textLabel.text = [NSString stringWithFormat:@"%@\n%@", _subtitle, _textLabel.text];
    _revealButton.hidden = _revealed;
    if (!version)
        _note.text = L(@"Too long for a QR code. Copy it or send it as a file.");
    else if (version > 25)
        _note.text = L(@"A dense code: hold the other camera steady and close.");
    else
        _note.text = _revealed ? L(@"Scan with LegacyRay, Happ, Amnezia or any client that takes links.")
                               : L(@"Stealth mode hides the code until you ask for it.");
}

- (void)layoutContent {
    CGRect b = self.contentView.bounds;
    if (b.size.width < 10) return;
    CGFloat side = [self qrSide];
    CGFloat cardW = side + 40, cardH = side + 112;
    CGFloat top = MAX(12, (b.size.height - cardH - 120) / 2);
    _card.frame = CGRectMake(floorf((b.size.width - cardW) / 2), floorf(top), cardW, cardH);
    [_card setNeedsDisplay];
    _nameLabel.frame = CGRectMake(12, 12, cardW - 24, 24);
    _qr.frame = CGRectMake(20, 42, side, side);
    _textLabel.frame = CGRectMake(14, 46 + side, cardW - 28, cardH - side - 54);
    if (_qr.image.size.width > side + 1 || (_revealed && !_qr.image)) [self refreshCode];
    CGFloat y = CGRectGetMaxY(_card.frame) + 14;
    CGFloat bw = MIN(150, (b.size.width - 48) / 2);
    CGFloat x0 = floorf((b.size.width - bw * 2 - 12) / 2);
    _copyButton.frame = CGRectMake(x0, y, bw, 40);
    _sendButton.frame = CGRectMake(x0 + bw + 12, y, bw, 40);
    _revealButton.frame = CGRectMake(floorf((b.size.width - 200) / 2),
                                     CGRectGetMinY(_card.frame) + 42 + side / 2 - 20, 200, 40);
    CGSize ns = [_note.text sizeWithFont:_note.font constrainedToSize:CGSizeMake(b.size.width - 40, 200)];
    _note.frame = CGRectMake(20, y + 50, b.size.width - 40, ceilf(ns.height));
}

#pragma mark sending

- (NSString *)writeFile {
    NSString *name = [_fileName length] ? _fileName : @"legacyray-link.txt";
    NSString *path = [[LRImporter documentsPath] stringByAppendingPathComponent:name];
    if (![_payload writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL]) {
        [LRToast showError:L(@"Unable to write the file")];
        return nil;
    }
    return path;
}

- (void)showSendMenu:(UIView *)anchor {
    __block LRShareScreen *me = self;
    LRMenu *menu = [LRMenu menuWithTitle:nil];
    [menu addItem:L(@"Save to Documents") action:^{
        NSString *p = [me writeFile];
        if (p) [LRToast showSuccess:[NSString stringWithFormat:L(@"Saved to Documents/%@"), [p lastPathComponent]]];
    }];
    if ([MFMailComposeViewController canSendMail])
        [menu addItem:L(@"Send by Mail") action:^{ [me mail]; }];
    [menu addItem:L(@"Open In...") action:^{ [me openIn:anchor]; }];
    [menu showFromView:anchor];
}

- (void)openIn:(UIView *)anchor {
    NSString *path = [self writeFile];
    if (!path) return;
    [_document release];
    _document = [[UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:path]] retain];
    _document.delegate = self;
    UIView *from = anchor.window ? anchor : self.header;
    if (![_document presentOpenInMenuFromRect:from.bounds inView:from animated:YES])
        [LRToast showError:L(@"No app on this device opens this file")];
}

- (void)mail {
    MFMailComposeViewController *mail = [[[MFMailComposeViewController alloc] init] autorelease];
    mail.mailComposeDelegate = self;
    [mail setSubject:[NSString stringWithFormat:@"LegacyRay: %@", self.title]];
    if ([_fileName length]) {
        [mail addAttachmentData:[_payload dataUsingEncoding:NSUTF8StringEncoding]
                       mimeType:@"text/plain" fileName:_fileName];
    } else {
        [mail setMessageBody:_payload isHTML:NO];
    }
    LRPresentModal(self.navigationController ? (UIViewController *)self.navigationController : self, mail, YES);
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    LRDismissModal(controller, YES);
}
@end
