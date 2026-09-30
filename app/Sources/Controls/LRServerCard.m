#import "LRServerCard.h"
#import "LRDraw.h"
#import "LRSound.h"

@implementation LRServerCard
@synthesize countryCode = _countryCode, title = _title, detail = _detail, value = _value,
            valueColor = _valueColor;

+ (CGFloat)height {
    return SKIN->flat ? 64 : 62;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        self.exclusiveTouch = YES;
    }
    return self;
}

- (void)dealloc {
    [_countryCode release];
    [_title release];
    [_detail release];
    [_value release];
    [_valueColor release];
    [super dealloc];
}

- (void)setCountryCode:(NSString *)v { if (v != _countryCode && ![v isEqual:_countryCode]) { [_countryCode release]; _countryCode = [v copy]; [self setNeedsDisplay]; } }
- (void)setTitle:(NSString *)v { if (v != _title && ![v isEqual:_title]) { [_title release]; _title = [v copy]; [self setNeedsDisplay]; } }
- (void)setDetail:(NSString *)v { if (v != _detail && ![v isEqual:_detail]) { [_detail release]; _detail = [v copy]; [self setNeedsDisplay]; } }
- (void)setValue:(NSString *)v { if (v != _value && ![v isEqual:_value]) { [_value release]; _value = [v copy]; [self setNeedsDisplay]; } }
- (void)setValueColor:(UIColor *)v { if (v != _valueColor) { [_valueColor release]; _valueColor = [v retain]; [self setNeedsDisplay]; } }

- (void)setHighlighted:(BOOL)highlighted {
    BOOL changed = highlighted != self.highlighted;
    [super setHighlighted:highlighted];
    if (changed) {
        if (highlighted) [LRSound click];
        [self setNeedsDisplay];
    }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    LRSkin *s = SKIN;
    CGRect b = self.bounds;
    BOOL pressed = self.highlighted;
    CGRect card = CGRectMake(0, 0, b.size.width, b.size.height - 3);
    if (s->flat) {
        card = b;
        LRAddRoundRect(ctx, card, 12);
        [(pressed ? s->groupPressed : s->groupTop) setFill];
        CGContextFillPath(ctx);
        LRAddRoundRect(ctx, CGRectInset(card, 0.25f, 0.25f), 12);
        [s->separator setStroke];
        CGContextSetLineWidth(ctx, LRHairline());
        CGContextStrokePath(ctx);
    } else {
        /* a soft shadow on the cloth */
        for (int i = 0; i < 3; ++i) {
            LRAddRoundRect(ctx, CGRectMake(card.origin.x - 0.5f + i * 0.2f, card.origin.y + 1.5f + i * 0.6f,
                                           card.size.width + 1 - i * 0.4f, card.size.height), 10);
            CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.14f);
            CGContextFillPath(ctx);
        }
        LRDrawGroupCell(ctx, card, LRPlateSingle, pressed, YES);
    }
    BOOL white = pressed && !s->flat;
    CGFloat midY = CGRectGetMidY(card);
    CGFloat x = card.origin.x + (s->flat ? 16 : 12);
    if ([_countryCode length] == 2) {
        LRDrawFlag(ctx, _countryCode, CGRectMake(x, roundf(midY - 14.5f), 29, 29));
        x += 40;
    } else {
        x += 2;
    }
    CGFloat right = CGRectGetMaxX(card) - 14;
    UIColor *chevron = white ? [UIColor whiteColor]
        : (s->flat ? [UIColor colorWithWhite:0.78f alpha:1] : [UIColor colorWithWhite:0.55f alpha:1]);
    LRDrawChevron(ctx, CGPointMake(right - 2, midY), 4.5f, NO, chevron, s->flat ? 2 : 2.6f);
    right -= 18;
    UIFont *valueFont = [LRSkin bodyFont:15];
    CGFloat valueW = 0;
    if ([_value length]) {
        valueW = MIN([_value sizeWithFont:valueFont].width, (right - x) * 0.4f);
        [(white ? [UIColor whiteColor] : (_valueColor ? _valueColor : s->groupDetail)) set];
        [_value drawInRect:CGRectMake(right - valueW, midY - 9, valueW, 20) withFont:valueFont
             lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentRight];
        valueW += 10;
    }
    CGFloat textW = right - valueW - x;
    UIFont *titleFont = s->flat ? [LRSkin bodyFont:17] : [LRSkin boldFont:17];
    UIFont *detailFont = [LRSkin bodyFont:13];
    BOOL twoLines = [_detail length] > 0;
    CGFloat titleY = twoLines ? midY - 20 : midY - 11;
    [(white ? [UIColor whiteColor] : s->groupInk) set];
    [_title drawInRect:CGRectMake(x, titleY, textW, 22) withFont:titleFont
         lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentLeft];
    if (twoLines) {
        [(white ? [UIColor whiteColor] : s->groupMuted) set];
        [_detail drawInRect:CGRectMake(x, midY + 3, textW, 17) withFont:detailFont
              lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentLeft];
    }
}
@end
