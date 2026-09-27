#import "LRAlert.h"
#import "LRDraw.h"
#import "LRTextField.h"

@interface LRAlertPanel : UIView {
@public
    NSMutableArray *separators;   /* flat skin: hairline rects between buttons */
}
@end

@implementation LRAlertPanel
- (void)dealloc {
    [separators release];
    [super dealloc];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    LRSkin *s = SKIN;
    if (s->flat) {
        LRAddRoundRect(ctx, b, 8);
        [[UIColor colorWithWhite:0.975f alpha:1] setFill];
        CGContextFillPath(ctx);
        [s->separator setFill];
        for (NSValue *v in separators) CGContextFillRect(ctx, [v CGRectValue]);
        return;
    }
    CGContextSaveGState(ctx);
    LRAddRoundRect(ctx, b, 12);
    CGContextClip(ctx);
    LRDrawBrushedMetal(ctx, b, s->plateTop, s->plateBottom, s->hairLight, s->hairDark, 33);
    LRDrawNoise(ctx, b, 0.08f);
    CGContextRestoreGState(ctx);
    LRAddRoundRect(ctx, CGRectInset(b, 0.5f, 0.5f), 12);
    CGContextSetRGBStrokeColor(ctx, 1, 1, 1, s->night ? 0.12f : 0.7f);
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);
    LRDrawScrew(ctx, CGPointMake(11, 11), 3.5f, 0.5f);
    LRDrawScrew(ctx, CGPointMake(b.size.width - 11, 11), 3.5f, 1.9f);
    LRDrawScrew(ctx, CGPointMake(11, b.size.height - 11), 3.5f, 2.6f);
    LRDrawScrew(ctx, CGPointMake(b.size.width - 11, b.size.height - 11), 3.5f, 1.1f);
}
@end

@implementation LRAlert

+ (LRAlert *)alertWithTitle:(NSString *)title message:(NSString *)message {
    LRAlert *a = [[[LRAlert alloc] initWithFrame:CGRectZero] autorelease];
    a->_title = [title copy];
    a->_message = [message copy];
    return a;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _fields = [[NSMutableArray alloc] init];
        _buttons = [[NSMutableArray alloc] init];
        _actions = [[NSMutableArray alloc] init];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_title release];
    [_message release];
    [_fields release];
    [_buttons release];
    [_actions release];
    [_panel release];
    [_dim release];
    [_titleLabel release];
    [_messageLabel release];
    [super dealloc];
}

- (void)addButton:(NSString *)title style:(LRButtonStyle)style action:(void (^)(LRAlert *))action {
    BOOL flat = SKIN->flat;
    LRButton *b = [LRButton buttonWithStyle:flat ? LRButtonMetal : style title:title action:nil];
    b.frame = CGRectMake(0, 0, 100, 40);
    b.titleLabel.font = flat ? (style == LRButtonMetal ? [LRSkin bodyFont:17] : [LRSkin boldFont:17])
                             : [LRSkin boldFont:14];
    if (flat && style == LRButtonRed) [b setTitleColor:SKIN->ledRed forState:UIControlStateNormal];
    b.tag = (NSInteger)[_buttons count];
    [b addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_buttons addObject:b];
    id block = action ? [[action copy] autorelease] : (id)[NSNull null];
    [_actions addObject:block];
}

- (UITextField *)addFieldWithPlaceholder:(NSString *)placeholder text:(NSString *)text {
    LRTextField *f = [[[LRTextField alloc] initWithFrame:CGRectMake(0, 0, 200, 36)] autorelease];
    f.placeholder = placeholder;
    f.text = text;
    f.delegate = self;
    f.returnKeyType = UIReturnKeyDone;
    [_fields addObject:f];
    return f;
}

- (NSArray *)fields {
    return _fields;
}

- (NSString *)textAtIndex:(NSUInteger)index {
    return index < [_fields count] ? [[_fields objectAtIndex:index] text] : nil;
}

- (void)buttonTapped:(LRButton *)b {
    id action = [[[_actions objectAtIndex:(NSUInteger)b.tag] retain] autorelease];
    [self retain];
    [self dismiss];
    if (action != [NSNull null]) ((void (^)(LRAlert *))action)(self);
    [self release];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSUInteger i = [_fields indexOfObject:textField];
    if (i + 1 < [_fields count]) {
        [[_fields objectAtIndex:i + 1] becomeFirstResponder];
        return NO;
    }
    /* return on the last field presses the primary (last) button */
    LRButton *primary = [_buttons lastObject];
    if (primary) [self buttonTapped:primary];
    return NO;
}

- (CGFloat)panelWidth {
    return MIN(LRIsPad() ? 360.0f : 290.0f, self.bounds.size.width - 20);
}

/* the ios 7 alert: text, then a row or a column of text buttons divided by
   hairlines that run to the panel edges */
- (void)layoutFlatPanel {
    CGFloat w = MIN(270.0f, self.bounds.size.width - 20);
    CGFloat pad = 16, y = 20, inner = w - pad * 2, hair = LRHairline();
    CGSize ts = [_titleLabel.text sizeWithFont:_titleLabel.font constrainedToSize:CGSizeMake(inner, 200)];
    _titleLabel.frame = CGRectMake(pad, y, inner, ceilf(ts.height));
    y += ceilf(ts.height) + 4;
    if ([_messageLabel.text length]) {
        CGSize ms = [_messageLabel.text sizeWithFont:_messageLabel.font
                                   constrainedToSize:CGSizeMake(inner, self.bounds.size.height * 0.45f)];
        _messageLabel.frame = CGRectMake(pad, y, inner, ceilf(ms.height));
        y += ceilf(ms.height) + 4;
    }
    y += 10;
    for (UITextField *f in _fields) {
        f.frame = CGRectMake(pad, y, inner, 32);
        y += 38;
    }
    LRAlertPanel *panel = (LRAlertPanel *)_panel;
    [panel->separators release];
    panel->separators = [[NSMutableArray alloc] init];
    NSUInteger n = [_buttons count];
    if (n == 2) {
        [panel->separators addObject:[NSValue valueWithCGRect:CGRectMake(0, y, w, hair)]];
        [panel->separators addObject:[NSValue valueWithCGRect:CGRectMake(w / 2, y, hair, 44)]];
        [[_buttons objectAtIndex:0] setFrame:CGRectMake(0, y, w / 2, 44)];
        [[_buttons objectAtIndex:1] setFrame:CGRectMake(w / 2, y, w / 2, 44)];
        y += 44;
    } else {
        for (LRButton *b in _buttons) {
            [panel->separators addObject:[NSValue valueWithCGRect:CGRectMake(0, y, w, hair)]];
            b.frame = CGRectMake(0, y, w, 44);
            y += 44;
        }
    }
    CGFloat avail = self.bounds.size.height - _keyboardHeight;
    _panel.frame = CGRectMake(roundf((self.bounds.size.width - w) / 2),
                              roundf(MAX(10, (avail - y) / 2)), w, y);
    [_panel setNeedsDisplay];
}

- (void)layoutPanel {
    if (SKIN->flat) {
        [self layoutFlatPanel];
        return;
    }
    CGFloat w = [self panelWidth];
    CGFloat pad = 20, y = 22;
    CGFloat inner = w - pad * 2;
    CGSize ts = [_titleLabel.text sizeWithFont:_titleLabel.font constrainedToSize:CGSizeMake(inner, 200)];
    _titleLabel.frame = CGRectMake(pad, y, inner, ceilf(ts.height));
    y += ceilf(ts.height) + 8;
    if ([_messageLabel.text length]) {
        CGFloat maxMsg = self.bounds.size.height * 0.45f;
        CGSize ms = [_messageLabel.text sizeWithFont:_messageLabel.font
                                   constrainedToSize:CGSizeMake(inner, maxMsg)];
        _messageLabel.frame = CGRectMake(pad, y, inner, ceilf(ms.height));
        y += ceilf(ms.height) + 12;
    }
    for (UITextField *f in _fields) {
        f.frame = CGRectMake(pad, y, inner, 36);
        y += 44;
    }
    y += 4;
    NSUInteger n = [_buttons count];
    BOOL row = n == 2;
    if (row) {
        CGFloat bw = (inner - 10) / 2;
        for (NSUInteger i = 0; i < n; ++i)
            [[_buttons objectAtIndex:i] setFrame:CGRectMake(pad + i * (bw + 10), y, bw, 42)];
        y += 42;
    } else {
        for (LRButton *b in _buttons) {
            b.frame = CGRectMake(pad, y, inner, 42);
            y += 50;
        }
        if (n) y -= 8;
    }
    y += 20;
    CGFloat avail = self.bounds.size.height - _keyboardHeight;
    CGFloat py = roundf(MAX(10, (avail - y) / 2));
    _panel.frame = CGRectMake(roundf((self.bounds.size.width - w) / 2), py, w, y);
    [_panel setNeedsDisplay];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _dim.frame = self.bounds;
    [self layoutPanel];
}

- (void)show {
    UIViewController *top = LRTopViewController();
    UIView *host = top.view;
    if (!host) return;
    if (![_buttons count]) [self addButton:L(@"OK") style:LRButtonMetal action:nil];
    self.frame = host.bounds;
    _dim = [[UIView alloc] initWithFrame:self.bounds];
    _dim.backgroundColor = [UIColor colorWithWhite:0 alpha:SKIN->flat ? 0.4f : 0.55f];
    [self addSubview:_dim];
    _panel = [[LRAlertPanel alloc] initWithFrame:CGRectZero];
    _panel.backgroundColor = [UIColor clearColor];
    _panel.contentMode = UIViewContentModeRedraw;
    _panel.layer.shadowColor = [UIColor blackColor].CGColor;
    _panel.layer.shadowOpacity = SKIN->flat ? 0 : 0.7f;
    _panel.layer.shadowRadius = 10;
    _panel.layer.shadowOffset = CGSizeMake(0, 4);
    [self addSubview:_panel];
    LRSkin *s = SKIN;
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = _title;
    _titleLabel.font = s->flat ? [LRSkin boldFont:17] : [LRSkin titleFont:18];
    _titleLabel.numberOfLines = 0;
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = s->engrave;
    _titleLabel.shadowColor = s->engraveShadow;
    _titleLabel.shadowOffset = CGSizeMake(0, s->engraveOffset);
    [_panel addSubview:_titleLabel];
    _messageLabel = [[UILabel alloc] init];
    _messageLabel.text = _message;
    _messageLabel.font = [LRSkin bodyFont:s->flat ? 13 : 14];
    _messageLabel.numberOfLines = 0;
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.textColor = s->flat ? s->groupInk : LRColorAlpha(s->engrave, 0.85f);
    _messageLabel.shadowColor = s->engraveShadow;
    _messageLabel.shadowOffset = CGSizeMake(0, s->engraveOffset);
    [_panel addSubview:_messageLabel];
    for (UITextField *f in _fields) [_panel addSubview:f];
    for (LRButton *b in _buttons) [_panel addSubview:b];
    [host addSubview:self];
    [self layoutPanel];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    _dim.alpha = 0;
    _panel.transform = CGAffineTransformMakeScale(0.85f, 0.85f);
    _panel.alpha = 0;
    LRAnimateIn(0.2, ^{
        _dim.alpha = 1;
        _panel.alpha = 1;
        _panel.transform = CGAffineTransformIdentity;
    });
    if ([_fields count]) [[_fields objectAtIndex:0] becomeFirstResponder];
}

- (void)keyboardWillShow:(NSNotification *)note {
    CGRect kb = [[[note userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    kb = [self convertRect:[self.window convertRect:kb fromWindow:nil] fromView:self.window];
    _keyboardHeight = MAX(0, CGRectGetMaxY(self.bounds) - kb.origin.y);
    [UIView animateWithDuration:0.25 animations:^{ [self layoutPanel]; }];
}

- (void)keyboardWillHide:(NSNotification *)note {
    _keyboardHeight = 0;
    [UIView animateWithDuration:0.25 animations:^{ [self layoutPanel]; }];
}

- (void)dismiss {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self endEditing:YES];
    [self retain];
    [UIView animateWithDuration:0.15 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        [self release];
    }];
}

+ (void)showTitle:(NSString *)title message:(NSString *)message {
    LRAlert *a = [self alertWithTitle:title message:message];
    [a addButton:L(@"OK") style:LRButtonMetal action:nil];
    [a show];
}

+ (void)confirmTitle:(NSString *)title message:(NSString *)message button:(NSString *)button
         destructive:(BOOL)destructive action:(void (^)(void))action {
    [self confirmTitle:title message:message button:button destructive:destructive action:action cancel:nil];
}

+ (void)confirmTitle:(NSString *)title message:(NSString *)message button:(NSString *)button
         destructive:(BOOL)destructive action:(void (^)(void))action cancel:(void (^)(void))cancel {
    LRAlert *a = [self alertWithTitle:title message:message];
    void (^block)(void) = [[action copy] autorelease];
    void (^back)(void) = [[cancel copy] autorelease];
    [a addButton:L(@"Cancel") style:LRButtonMetal action:^(LRAlert *alert) {
        if (back) back();
    }];
    [a addButton:button style:destructive ? LRButtonRed : LRButtonGreen action:^(LRAlert *alert) {
        if (block) block();
    }];
    [a show];
}

+ (void)promptTitle:(NSString *)title message:(NSString *)message placeholder:(NSString *)placeholder
               text:(NSString *)text button:(NSString *)button done:(void (^)(NSString *))done {
    LRAlert *a = [self alertWithTitle:title message:message];
    void (^block)(NSString *) = [[done copy] autorelease];
    [a addFieldWithPlaceholder:placeholder text:text];
    [a addButton:L(@"Cancel") style:LRButtonMetal action:nil];
    [a addButton:button style:LRButtonGreen action:^(LRAlert *alert) {
        if (block) block([alert textAtIndex:0]);
    }];
    [a show];
}
@end
