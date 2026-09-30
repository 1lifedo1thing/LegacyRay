#import "LRSimpleScreens.h"
#import "LRDraw.h"
#import "LRToast.h"
#import "LRImporter.h"
#import "LRMenu.h"
#import <MessageUI/MessageUI.h>

@implementation LRChoiceScreen
@synthesize notes = _notes, footer = _footer;

- (id)initWithTitle:(NSString *)title options:(NSArray *)options selected:(NSInteger)selected
             picked:(void (^)(NSInteger))picked {
    if ((self = [super init])) {
        self.title = title;
        _options = [options copy];
        _selected = selected;
        _picked = [picked copy];
    }
    return self;
}

- (void)dealloc {
    [_options release];
    [_notes release];
    [_footer release];
    [_picked release];
    [super dealloc];
}

- (NSArray *)buildSections {
    NSMutableArray *rows = [NSMutableArray array];
    __block LRChoiceScreen *me = self;
    for (NSUInteger i = 0; i < [_options count]; ++i) {
        LRRow *row = [LRRow check:[_options objectAtIndex:i] on:(NSInteger)i == _selected
                           action:^(LRRow *r, UIView *cell) {
            me->_selected = (NSInteger)i;
            [me reloadSections];
            if (me->_picked) me->_picked((NSInteger)i);
        }];
        if (i < [_notes count]) row.subtitle = [_notes objectAtIndex:i];
        [rows addObject:row];
    }
    return [NSArray arrayWithObject:[LRSectionSpec header:nil rows:rows footer:_footer]];
}
@end

@implementation LRTextScreen
@synthesize fileName = _fileName, reload = _reload;

- (id)initWithTitle:(NSString *)title text:(NSString *)text {
    if ((self = [super init])) {
        self.title = title;
        _text = [text copy];
    }
    return self;
}

- (void)dealloc {
    [_text release];
    [_textView release];
    [_fileName release];
    [_documentController release];
    [_reload release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    LRSkin *s = SKIN;
    _textView = [[UITextView alloc] init];
    _textView.editable = NO;
    _textView.font = [LRSkin monoFont:LRIsPad() ? 13 : 11];
    _textView.text = [_text length] ? _text : L(@"(empty)");
    _textView.backgroundColor = [UIColor whiteColor];
    _textView.textColor = [UIColor colorWithWhite:0.12f alpha:1];
    if (!s->flat) {
        /* a grouped row's white, rim and corners */
        _textView.layer.cornerRadius = 10;
        _textView.layer.borderColor = s->groupEdge.CGColor;
        _textView.layer.borderWidth = 1;
    }
    [self.contentView addSubview:_textView];
    __block LRTextScreen *me = self;
    [self.header setRightGlyph:LRGlyphDots(18, [LRHeaderBar glyphColor]) action:^(LRButton *b) {
        [me showActions:b];
    }];
}

- (void)setText:(NSString *)text {
    [_text release];
    _text = [text copy];
    _textView.text = [_text length] ? _text : L(@"(empty)");
}

- (void)layoutContent {
    CGRect b = self.contentView.bounds;
    _textView.frame = SKIN->flat ? b : CGRectInset(b, 10, 10);
}

- (void)showActions:(UIView *)anchor {
    __block LRTextScreen *me = self;
    LRMenu *menu = [LRMenu menuWithTitle:nil];
    [menu addItem:L(@"Copy") action:^{
        [UIPasteboard generalPasteboard].string = me->_text ? me->_text : @"";
        [LRToast showSuccess:L(@"Copied to the clipboard")];
    }];
    [menu addItem:L(@"Save to Documents") action:^{ [me saveToDocuments]; }];
    if ([MFMailComposeViewController canSendMail])
        [menu addItem:L(@"Send by Mail") action:^{ [me mail]; }];
    [menu addItem:L(@"Open In...") action:^{ [me openIn:anchor]; }];
    if (_reload) [menu addItem:L(@"Refresh") action:^{ me->_reload(me); }];
    [menu showFromView:anchor];
}

- (NSString *)saveToDocuments {
    NSString *name = [_fileName length] ? _fileName : @"legacyray.txt";
    NSString *path = [[LRImporter documentsPath] stringByAppendingPathComponent:name];
    if ([_text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL]) {
        [LRToast showSuccess:[NSString stringWithFormat:L(@"Saved to Documents/%@"), name]];
        return path;
    }
    [LRToast showError:L(@"Unable to write the file")];
    return nil;
}

- (void)openIn:(UIView *)anchor {
    NSString *path = [self saveToDocuments];
    if (!path) return;
    [_documentController release];
    _documentController = [[UIDocumentInteractionController interactionControllerWithURL:
                            [NSURL fileURLWithPath:path]] retain];
    [_documentController setDelegate:self];
    UIView *from = anchor.window ? anchor : self.header;
    if (![_documentController presentOpenInMenuFromRect:from.bounds inView:from animated:YES])
        [LRToast show:L(@"No app on this device opens this file")];
}

- (void)mail {
    MFMailComposeViewController *mail = [[[MFMailComposeViewController alloc] init] autorelease];
    mail.mailComposeDelegate = (id<MFMailComposeViewControllerDelegate>)self;
    [mail setSubject:[NSString stringWithFormat:@"LegacyRay: %@", self.title]];
    NSData *data = [_text dataUsingEncoding:NSUTF8StringEncoding];
    [mail addAttachmentData:data mimeType:@"text/plain"
                   fileName:[_fileName length] ? _fileName : @"legacyray.txt"];
    LRPresentModal(self.navigationController ? (UIViewController *)self.navigationController : self, mail, YES);
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    LRDismissModal(controller, YES);
}
@end

@implementation LRTextEditScreen

- (id)initWithTitle:(NSString *)title text:(NSString *)text save:(void (^)(NSString *, LRTextEditScreen *))save {
    if ((self = [super init])) {
        self.title = title;
        _initial = [text copy];
        _save = [save copy];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_initial release];
    [_well release];
    [_save release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _well = [[LRTextWell alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
    _well.textView.text = _initial;
    [self.contentView addSubview:_well];
    __block LRTextEditScreen *me = self;
    [self.header setRightTitle:L(@"Save") style:LRButtonGreen action:^(LRButton *b) {
        if (me->_save) me->_save(me->_well.textView.text, me);
    }];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboard:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboard:)
                                                 name:UIKeyboardWillHideNotification object:nil];
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

- (void)layoutContent {
    CGRect b = self.contentView.bounds;
    b.size.height -= _keyboard;
    _well.frame = CGRectInset(b, 8, 8);
}
@end
