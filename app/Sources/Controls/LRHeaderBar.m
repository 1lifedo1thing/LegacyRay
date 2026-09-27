#import "LRHeaderBar.h"
#import "LRDraw.h"

@implementation LRHeaderBar
@synthesize titleLabel = _titleLabel, leftButton = _leftButton, rightButton = _rightButton,
            extraButton = _extraButton;

+ (UIColor *)glyphColor {
    LRSkin *s = SKIN;
    if (s->flat) return s->tint;
    return s->night ? [UIColor colorWithWhite:0.88f alpha:1] : [UIColor colorWithWhite:0.25f alpha:1];
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.contentMode = UIViewContentModeRedraw;
        LRSkin *s = SKIN;
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [LRSkin titleFont:18];
        _titleLabel.textColor = s->engrave;
        _titleLabel.shadowColor = s->engraveShadow;
        _titleLabel.shadowOffset = CGSizeMake(0, s->engraveOffset);
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumFontSize = 12;
        [self addSubview:_titleLabel];
        if (s->flat) {
            _titleLabel.font = [LRSkin titleFont:17];
        } else {
            self.layer.shadowColor = [UIColor blackColor].CGColor;
            self.layer.shadowOpacity = 0.45f;
            self.layer.shadowOffset = CGSizeMake(0, 1);
            self.layer.shadowRadius = 2;
        }
    }
    return self;
}

- (void)dealloc {
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
    if (s->flat) {
        [s->plateTop setFill];
        CGContextFillRect(ctx, b);
        [s->separator setFill];
        CGContextFillRect(ctx, CGRectMake(0, b.size.height - LRHairline(), b.size.width, LRHairline()));
        return;
    }
    LRDrawBrushedMetal(ctx, b, s->plateTop, s->plateBottom, s->hairLight, s->hairDark, 21);
    /* top highlight, bottom groove */
    CGContextSetRGBFillColor(ctx, 1, 1, 1, s->night ? 0.12f : 0.7f);
    CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.55f);
    CGContextFillRect(ctx, CGRectMake(0, b.size.height - 1, b.size.width, 1));
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
    LRButton *b = [self makeButton:nil style:LRButtonMetal action:action];
    [b setGlyph:glyph];
    self.extraButton = b;
    return b;
}

- (LRButton *)makeButton:(NSString *)title style:(LRButtonStyle)style action:(void (^)(LRButton *))action {
    LRButton *b = [LRButton buttonWithStyle:style title:title action:action];
    b.frame = CGRectMake(0, 0, 60, 30);
    b.titleLabel.font = SKIN->flat ? [LRSkin bodyFont:17] : [LRSkin boldFont:12];
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
    LRButton *b = [self makeButton:nil style:LRButtonMetal action:action];
    [b setGlyph:glyph];
    self.rightButton = b;
    return b;
}

- (CGFloat)widthForButton:(LRButton *)b {
    NSString *t = [b titleForState:UIControlStateNormal];
    if (![t length]) return 40;
    CGFloat w = [t sizeWithFont:b.titleLabel.font].width + (b.style == LRButtonBack ? 28 : 20);
    return MIN(MAX(w, 50), self.bounds.size.width * 0.3f);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    CGFloat side = 0;
    if (_leftButton) {
        CGFloat w = [self widthForButton:_leftButton];
        _leftButton.frame = CGRectMake(7, roundf((b.size.height - 30) / 2), w, 30);
        side = MAX(side, w + 12);
    }
    if (_rightButton) {
        CGFloat w = [self widthForButton:_rightButton];
        _rightButton.frame = CGRectMake(b.size.width - 7 - w, roundf((b.size.height - 30) / 2), w, 30);
        CGFloat used = w + 12;
        if (_extraButton) {
            CGFloat ew = [self widthForButton:_extraButton];
            _extraButton.frame = CGRectMake(_rightButton.frame.origin.x - 6 - ew,
                                            roundf((b.size.height - 30) / 2), ew, 30);
            used += ew + 6;
        }
        side = MAX(side, used);
    }
    _titleLabel.frame = CGRectMake(side + 4, 0, b.size.width - 2 * (side + 4), b.size.height);
}
@end
