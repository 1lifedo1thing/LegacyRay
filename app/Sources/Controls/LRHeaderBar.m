#import "LRHeaderBar.h"
#import "LRDraw.h"

@implementation LRHeaderBar
@synthesize titleLabel = _titleLabel, leftButton = _leftButton, rightButton = _rightButton,
            extraButton = _extraButton, topInset = _topInset, translucent = _translucent;

+ (UIColor *)glyphColor {
    LRSkin *s = SKIN;
    return s->flat ? s->tint : s->barInk;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.contentMode = UIViewContentModeRedraw;
        LRSkin *s = SKIN;
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [LRSkin titleFont:20];
        _titleLabel.textColor = s->barInk;
        _titleLabel.shadowColor = s->barShadow;
        _titleLabel.shadowOffset = CGSizeMake(0, -1);
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumFontSize = 12;
        [self addSubview:_titleLabel];
        if (s->flat) {
            _titleLabel.font = [LRSkin titleFont:17];
        } else {
            /* the bar's shadow on the page; the path keeps it cheap */
            self.layer.shadowColor = [UIColor blackColor].CGColor;
            self.layer.shadowOpacity = 0.4f;
            self.layer.shadowOffset = CGSizeMake(0, 1);
            self.layer.shadowRadius = 2;
        }
    }
    return self;
}

- (void)setTopInset:(CGFloat)inset {
    if (inset == _topInset) return;
    _topInset = inset;
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (void)setTranslucent:(BOOL)on {
    if (on == _translucent) return;
    _translucent = on;
    if (on) {
        UIToolbar *bar = [[[UIToolbar alloc] initWithFrame:self.bounds] autorelease];
        bar.barStyle = UIBarStyleDefault;
        bar.translucent = YES;
        bar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        /* the toolbar's own hairline is on top; a nav bar's is at the bottom */
        bar.clipsToBounds = YES;
        bar.userInteractionEnabled = NO;
        [self insertSubview:bar atIndex:0];
        _blur = [bar retain];
        _hairline = [[UIView alloc] init];
        _hairline.backgroundColor = SKIN->separator;
        [self addSubview:_hairline];
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    } else {
        [_blur removeFromSuperview];
        [_blur release];
        _blur = nil;
        [_hairline removeFromSuperview];
        [_hairline release];
        _hairline = nil;
    }
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (void)dealloc {
    [_blur release];
    [_hairline release];
    [_titleLabel release];
    [_leftButton release];
    [_rightButton release];
    [_extraButton release];
    [super dealloc];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    LRSkin *s = SKIN;
    if (_translucent) return;
    (void)s;
    LRDrawBar(ctx, b);
}

- (void)setTitle:(NSString *)title {
    _titleLabel.text = title;
    [self setNeedsLayout];
}

- (NSString *)title {
    return _titleLabel.text;
}

- (void)setLeftButton:(LRButton *)b {
    [_leftButton removeFromSuperview];
    [_leftButton release];
    _leftButton = [b retain];
    if (b) [self addSubview:b];
    [self setNeedsLayout];
}

- (void)setRightButton:(LRButton *)b {
    [_rightButton removeFromSuperview];
    [_rightButton release];
    _rightButton = [b retain];
    if (b) [self addSubview:b];
    [self setNeedsLayout];
}

- (void)setExtraButton:(LRButton *)b {
    [_extraButton removeFromSuperview];
    [_extraButton release];
    _extraButton = [b retain];
    if (b) [self addSubview:b];
    [self setNeedsLayout];
}

- (LRButton *)setExtraGlyph:(UIImage *)glyph action:(void (^)(LRButton *))action {
    LRButton *b = [self makeButton:nil style:LRButtonBar action:action];
    [b setGlyph:glyph];
    self.extraButton = b;
    return b;
}

/* keys on a bar: the plain key becomes a bar key, green (save, done) the
   blue done key */
- (LRButton *)makeButton:(NSString *)title style:(LRButtonStyle)style action:(void (^)(LRButton *))action {
    if (style == LRButtonMetal) style = LRButtonBar;
    else if (style == LRButtonGreen) style = LRButtonDone;
    LRButton *b = [LRButton buttonWithStyle:style title:title action:action];
    b.frame = CGRectMake(0, 0, 60, 30);
    b.titleLabel.font = SKIN->flat ? (style == LRButtonDone ? [LRSkin boldFont:17] : [LRSkin bodyFont:17])
                                   : [LRSkin boldFont:12];
    if (SKIN->flat && style == LRButtonBack)
        b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    return b;
}

- (LRButton *)setBackButtonWithTitle:(NSString *)title action:(void (^)(LRButton *))action {
    self.leftButton = [self makeButton:title style:LRButtonBack action:action];
    return _leftButton;
}

- (LRButton *)setLeftTitle:(NSString *)title style:(LRButtonStyle)style action:(void (^)(LRButton *))action {
    self.leftButton = [self makeButton:title style:style action:action];
    return _leftButton;
}

- (LRButton *)setRightTitle:(NSString *)title style:(LRButtonStyle)style action:(void (^)(LRButton *))action {
    self.rightButton = [self makeButton:title style:style action:action];
    return _rightButton;
}

- (LRButton *)setRightGlyph:(UIImage *)glyph action:(void (^)(LRButton *))action {
    LRButton *b = [self makeButton:nil style:LRButtonBar action:action];
    [b setGlyph:glyph];
    self.rightButton = b;
    return b;
}

- (CGFloat)widthForButton:(LRButton *)b {
    NSString *t = [b titleForState:UIControlStateNormal];
    if (![t length]) return SKIN->flat ? 40 : 36;
    CGFloat w = [t sizeWithFont:b.titleLabel.font].width + (b.style == LRButtonBack ? 28 : 20);
    return MIN(MAX(w, 50), self.bounds.size.width * 0.3f);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect full = self.bounds;
    if (self.layer.shadowOpacity > 0)
        self.layer.shadowPath = [UIBezierPath bezierPathWithRect:full].CGPath;
    _blur.frame = full;
    _hairline.frame = CGRectMake(0, full.size.height - LRHairline(), full.size.width, LRHairline());
    [self bringSubviewToFront:_hairline];
    /* everything below lays out in the 44 points under the status bar */
    CGRect b = CGRectMake(0, _topInset, full.size.width, full.size.height - _topInset);
    CGFloat side = 0;
    if (_leftButton) {
        CGFloat w = [self widthForButton:_leftButton];
        _leftButton.frame = CGRectMake(7, b.origin.y + roundf((b.size.height - 30) / 2), w, 30);
        side = MAX(side, w + 12);
    }
    if (_rightButton) {
        CGFloat w = [self widthForButton:_rightButton];
        _rightButton.frame = CGRectMake(b.size.width - 7 - w, b.origin.y + roundf((b.size.height - 30) / 2), w, 30);
        CGFloat used = w + 12;
        if (_extraButton) {
            CGFloat ew = [self widthForButton:_extraButton];
            _extraButton.frame = CGRectMake(_rightButton.frame.origin.x - 6 - ew,
                                            b.origin.y + roundf((b.size.height - 30) / 2), ew, 30);
            used += ew + 6;
        }
        side = MAX(side, used);
    }
    _titleLabel.frame = CGRectMake(side + 4, b.origin.y, b.size.width - 2 * (side + 4), b.size.height);
}
@end
