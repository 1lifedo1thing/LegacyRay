#import "LRButton.h"
#import "LRDraw.h"
#import "LRSound.h"

NSString *LRSpaced(NSString *text) {
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 0; i < [text length]; ++i) {
        if (i) [s appendString:@" "];
        [s appendFormat:@"%C", [text characterAtIndex:i]];
    }
    return s;
}

static NSMutableDictionary *gButtonImages = nil;

static void LRButtonBodyColors(LRButtonStyle style, BOOL pressed, NSArray **colors, CGFloat **locs) {
    static CGFloat four[4] = { 0, 0.5f, 0.51f, 1 };
    static CGFloat two[2] = { 0, 1 };
    LRSkin *s = SKIN;
    BOOL night = s->night;
    UIColor *(^W)(CGFloat) = ^UIColor *(CGFloat v) { return [UIColor colorWithWhite:v alpha:1]; };
    switch (style) {
        case LRButtonMetal:
        case LRButtonBack:
        case LRButtonKey:
            if (!night) {
                *colors = pressed
                    ? [NSArray arrayWithObjects:W(0.70f), W(0.76f), W(0.74f), W(0.82f), nil]
                    : [NSArray arrayWithObjects:W(0.985f), W(0.87f), W(0.81f), W(0.90f), nil];
            } else {
                *colors = pressed
                    ? [NSArray arrayWithObjects:W(0.14f), W(0.18f), W(0.16f), W(0.22f), nil]
                    : [NSArray arrayWithObjects:W(0.40f), W(0.25f), W(0.19f), W(0.27f), nil];
            }
            *locs = four;
            return;
        case LRButtonDark:
            *colors = pressed
                ? [NSArray arrayWithObjects:W(0.08f), W(0.12f), W(0.10f), W(0.16f), nil]
                : [NSArray arrayWithObjects:W(0.36f), W(0.20f), W(0.13f), W(0.21f), nil];
            *locs = four;
            return;
        case LRButtonGreen: {
            UIColor *a = [UIColor colorWithRed:0.52f green:0.86f blue:0.42f alpha:1];
            UIColor *b = [UIColor colorWithRed:0.20f green:0.62f blue:0.16f alpha:1];
            if (pressed) { a = LRColorMix(a, W(0), 0.25f); b = LRColorMix(b, W(0), 0.25f); }
            *colors = [NSArray arrayWithObjects:a, LRColorMix(a, b, 0.45f), b, LRColorMix(b, a, 0.3f), nil];
            *locs = four;
            return;
        }
        case LRButtonRed: {
            UIColor *a = [UIColor colorWithRed:0.95f green:0.45f blue:0.40f alpha:1];
            UIColor *b = [UIColor colorWithRed:0.72f green:0.12f blue:0.09f alpha:1];
            if (pressed) { a = LRColorMix(a, W(0), 0.25f); b = LRColorMix(b, W(0), 0.25f); }
            *colors = [NSArray arrayWithObjects:a, LRColorMix(a, b, 0.45f), b, LRColorMix(b, a, 0.3f), nil];
            *locs = four;
            return;
        }
        case LRButtonBrass: {
            UIColor *a = s->brassTop, *b = s->brassBottom;
            if (pressed) { a = LRColorMix(a, W(0), 0.2f); b = LRColorMix(b, W(0), 0.2f); }
            *colors = [NSArray arrayWithObjects:a, b, nil];
            *locs = two;
            return;
        }
    }
}

static void LRAddButtonShape(CGContextRef ctx, CGRect r, CGFloat radius, BOOL back) {
    if (!back) {
        LRAddRoundRect(ctx, r, radius);
        return;
    }
    CGFloat point = r.size.height * 0.34f;
    CGFloat minx = r.origin.x, maxx = CGRectGetMaxX(r), miny = r.origin.y, maxy = CGRectGetMaxY(r);
    CGFloat midy = CGRectGetMidY(r);
    CGContextMoveToPoint(ctx, minx, midy);
    CGContextAddLineToPoint(ctx, minx + point, miny + 1);
    CGContextAddArcToPoint(ctx, minx + point + 1, miny, minx + point + 4, miny, 2);
    CGContextAddArcToPoint(ctx, maxx, miny, maxx, midy, radius);
    CGContextAddArcToPoint(ctx, maxx, maxy, minx + point, maxy, radius);
    CGContextAddLineToPoint(ctx, minx + point + 4, maxy);
    CGContextAddArcToPoint(ctx, minx + point + 1, maxy, minx + point, maxy - 1, 2);
    CGContextClosePath(ctx);
}

/* flat buttons: text only for the plain styles, a tint outline (lit when
   selected) for keys, solid fills for the coloured actions */
static BOOL LRFlatTextOnly(LRButtonStyle style) {
    return style == LRButtonMetal || style == LRButtonBack || style == LRButtonBrass;
}

static UIImage *LRFlatButtonImage(LRButtonStyle style, CGFloat height, BOOL pressed, BOOL selected) {
    if (LRFlatTextOnly(style)) return nil;
    LRSkin *s = SKIN;
    CGFloat radius = style == LRButtonKey ? 4 : 6;
    CGFloat cap = radius + 2;
    CGFloat width = cap * 2 + 1;
    UIColor *fill = nil, *stroke = nil;
    switch (style) {
        case LRButtonKey:
            stroke = s->tint;
            if (selected) fill = s->tint;
            else if (pressed) fill = LRColorAlpha(s->tint, 0.15f);
            break;
        case LRButtonGreen: fill = s->ledGreen; break;
        case LRButtonRed: fill = s->ledRed; break;
        case LRButtonDark: fill = [UIColor colorWithWhite:0.20f alpha:1]; break;
        default: break;
    }
    if (pressed && style != LRButtonKey && fill) fill = LRColorMix(fill, [UIColor blackColor], 0.18f);
    UIImage *img = LRImageWithSize(CGSizeMake(width, height), NO, ^(CGContextRef ctx, CGRect rect) {
        CGRect body = CGRectInset(rect, 0.5f, 0.5f);
        if (fill) {
            LRAddRoundRect(ctx, body, radius);
            [fill setFill];
            CGContextFillPath(ctx);
        }
        if (stroke) {
            LRAddRoundRect(ctx, body, radius);
            [stroke setStroke];
            CGContextSetLineWidth(ctx, 1);
            CGContextStrokePath(ctx);
        }
    });
    return LRStretchable(img, cap, 0);
}

static UIImage *LRButtonImage(LRButtonStyle style, CGFloat height, BOOL pressed, BOOL selected) {
    NSString *key = [NSString stringWithFormat:@"%d.%.0f.%d.%d.%d.%d", style, height, pressed, selected,
                     SKIN->night, SKIN->flat];
    UIImage *cached = [gButtonImages objectForKey:key];
    if (cached) return cached;
    if (SKIN->flat) {
        UIImage *flatImage = LRFlatButtonImage(style, height, pressed, selected);
        if (!gButtonImages) gButtonImages = [[NSMutableDictionary alloc] init];
        if (flatImage) [gButtonImages setObject:flatImage forKey:key];
        return flatImage;
    }
    BOOL back = style == LRButtonBack;
    CGFloat radius = style == LRButtonKey ? 4 : MIN(7.0f, height * 0.22f);
    CGFloat cap = back ? height * 0.34f + radius + 4 : radius + 2;
    CGFloat width = cap * 2 + 1;
    UIImage *img = LRImageWithSize(CGSizeMake(width, height), NO, ^(CGContextRef ctx, CGRect rect) {
        CGRect body = CGRectMake(0.5f, 0.5f, width - 1, height - 2);
        /* lip below: light on a light plate, faint on a dark one */
        CGContextSaveGState(ctx);
        LRAddButtonShape(ctx, CGRectOffset(body, 0, 1), radius, back);
        CGContextSetRGBFillColor(ctx, 1, 1, 1, SKIN->night ? 0.10f : 0.55f);
        CGContextFillPath(ctx);
        LRAddButtonShape(ctx, body, radius, back);
        CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.62f);
        CGContextFillPath(ctx);
        CGRect inner = CGRectInset(body, 1, 1);
        LRAddButtonShape(ctx, inner, radius - 1, back);
        CGContextClip(ctx);
        NSArray *colors = nil;
        CGFloat *locs = NULL;
        LRButtonBodyColors(style, pressed || selected, &colors, &locs);
        LRFillLinear(ctx, CGPointMake(0, inner.origin.y), CGPointMake(0, CGRectGetMaxY(inner)),
                     colors, locs);
        if (style == LRButtonKey && selected) {
            /* a lit key glows from within */
            LRFillVertical(ctx, inner, LRColorAlpha(SKIN->ledAmber, 0.35f),
                           LRColorAlpha(SKIN->ledAmber, 0.10f));
        }
        if (pressed) {
            LRFillVertical(ctx, CGRectMake(0, inner.origin.y, width, 6),
                           [UIColor colorWithWhite:0 alpha:0.35f], [UIColor colorWithWhite:0 alpha:0]);
        }
        CGContextRestoreGState(ctx);
        /* inner top highlight */
        CGContextSaveGState(ctx);
        LRAddButtonShape(ctx, CGRectInset(body, 1.5f, 1.5f), radius - 1.5f, back);
        BOOL candy = style == LRButtonGreen || style == LRButtonRed;
        CGContextSetRGBStrokeColor(ctx, 1, 1, 1, pressed ? 0.08f : (candy ? 0.45f :
                                   (SKIN->night || style == LRButtonDark ? 0.12f : 0.6f)));
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokePath(ctx);
        CGContextRestoreGState(ctx);
    });
    img = LRStretchable(img, cap, 0);
    if (!gButtonImages) gButtonImages = [[NSMutableDictionary alloc] init];
    [gButtonImages setObject:img forKey:key];
    return img;
}

@implementation LRButton
@synthesize style = _style, action = _action;

+ (LRButton *)buttonWithStyle:(LRButtonStyle)style title:(NSString *)title
                       action:(void (^)(LRButton *))action {
    LRButton *b = [LRButton buttonWithType:UIButtonTypeCustom];
    b.style = style;
    b.action = action;
    [b setTitle:title forState:UIControlStateNormal];
    return b;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.titleLabel.font = [LRSkin labelFont:12];
        self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        self.adjustsImageWhenHighlighted = NO;
        self.exclusiveTouch = YES;
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        [self addTarget:self action:@selector(fire) forControlEvents:UIControlEventTouchUpInside];
        [self addTarget:self action:@selector(touchDown) forControlEvents:UIControlEventTouchDown];
        [self applyStyle];
    }
    return self;
}

- (void)dealloc {
    [_action release];
    [_glyph release];
    [super dealloc];
}

- (void)touchDown {
    [LRSound click];
}

- (void)fire {
    if (_action) _action(self);
}

- (void)setStyle:(LRButtonStyle)style {
    _style = style;
    [self applyStyle];
}

- (BOOL)lightText {
    switch (_style) {
        case LRButtonDark: case LRButtonGreen: case LRButtonRed: return YES;
        case LRButtonBrass: return NO;
        default: return SKIN->night;
    }
}

- (void)applyFlatStyle {
    LRSkin *s = SKIN;
    BOOL filled = _style == LRButtonGreen || _style == LRButtonRed || _style == LRButtonDark;
    UIColor *text = filled ? [UIColor whiteColor] : s->tint;
    [self setTitleColor:text forState:UIControlStateNormal];
    [self setTitleColor:filled ? LRColorAlpha(text, 0.7f) : LRColorAlpha(text, 0.3f)
               forState:UIControlStateHighlighted];
    [self setTitleColor:LRColorAlpha(filled ? text : s->groupMuted, 0.5f) forState:UIControlStateDisabled];
    if (_style == LRButtonKey) {
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected | UIControlStateHighlighted];
    }
    [self setTitleShadowColor:[UIColor clearColor] forState:UIControlStateNormal];
    self.titleLabel.shadowOffset = CGSizeZero;
    if (_style == LRButtonBack) self.titleEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 0);
    [self updateImages];
    [self setNeedsDisplay];
}

/* the flat back button carries the ios 7 chevron in front of its title */
- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    if (!SKIN->flat || _style != LRButtonBack) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIColor *c = self.highlighted ? LRColorAlpha(SKIN->tint, 0.3f) : SKIN->tint;
    CGFloat midY = CGRectGetMidY(self.bounds);
    [c setStroke];
    CGContextSetLineWidth(ctx, 2.5f);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGContextMoveToPoint(ctx, 10, midY - 7);
    CGContextAddLineToPoint(ctx, 3, midY);
    CGContextAddLineToPoint(ctx, 10, midY + 7);
    CGContextStrokePath(ctx);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    if (SKIN->flat && _style == LRButtonBack) [self setNeedsDisplay];
}

- (void)applyStyle {
    if (SKIN->flat) {
        [self applyFlatStyle];
        return;
    }
    BOOL light = [self lightText];
    UIColor *text = _style == LRButtonBrass ? SKIN->brassInk
        : (light ? [UIColor colorWithWhite:0.93f alpha:1] : [UIColor colorWithWhite:0.20f alpha:1]);
    UIColor *shadow = light ? [UIColor colorWithWhite:0 alpha:0.75f] : [UIColor colorWithWhite:1 alpha:0.85f];
    [self setTitleColor:text forState:UIControlStateNormal];
    [self setTitleColor:LRColorAlpha(text, 0.4f) forState:UIControlStateDisabled];
    if (_style == LRButtonKey)
        [self setTitleColor:SKIN->night ? SKIN->ledAmber : [UIColor colorWithRed:0.45f green:0.25f blue:0 alpha:1]
                   forState:UIControlStateSelected];
    [self setTitleShadowColor:shadow forState:UIControlStateNormal];
    self.titleLabel.shadowOffset = CGSizeMake(0, light ? -1 : 1);
    if (_style == LRButtonBack) self.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);
    [self updateImages];
}

- (void)updateImages {
    CGFloat h = self.bounds.size.height;
    if (h < 8) return;
    if (SKIN->flat && LRFlatTextOnly(_style)) {
        [self setBackgroundImage:nil forState:UIControlStateNormal];
        [self setBackgroundImage:nil forState:UIControlStateHighlighted];
        return;
    }
    [self setBackgroundImage:LRButtonImage(_style, h, NO, NO) forState:UIControlStateNormal];
    [self setBackgroundImage:LRButtonImage(_style, h, YES, NO) forState:UIControlStateHighlighted];
    if (_style == LRButtonKey) {
        [self setBackgroundImage:LRButtonImage(_style, h, NO, YES) forState:UIControlStateSelected];
        [self setBackgroundImage:LRButtonImage(_style, h, YES, YES)
                        forState:UIControlStateSelected | UIControlStateHighlighted];
    }
}

- (void)setFrame:(CGRect)frame {
    BOOL heightChanged = frame.size.height != self.frame.size.height;
    [super setFrame:frame];
    if (heightChanged) [self updateImages];
}

- (void)setGlyph:(UIImage *)glyph {
    [_glyph release];
    _glyph = [glyph retain];
    [self setImage:glyph forState:UIControlStateNormal];
}
@end

#pragma mark glyphs

static UIImage *LRGlyph(CGFloat size, void (^draw)(CGContextRef, CGFloat)) {
    return LRImageWithSize(CGSizeMake(size, size), NO, ^(CGContextRef ctx, CGRect rect) {
        draw(ctx, size);
    });
}

UIImage *LRGlyphPlus(CGFloat size, UIColor *color) {
    return LRGlyph(size, ^(CGContextRef ctx, CGFloat s) {
        [color setFill];
        CGFloat t = s * 0.16f;
        CGContextFillRect(ctx, CGRectMake(s * 0.15f, (s - t) / 2, s * 0.7f, t));
        CGContextFillRect(ctx, CGRectMake((s - t) / 2, s * 0.15f, t, s * 0.7f));
    });
}

UIImage *LRGlyphGear(CGFloat size, UIColor *color) {
    return LRGlyph(size, ^(CGContextRef ctx, CGFloat s) {
        [color setFill];
        CGFloat c = s / 2, ro = s * 0.46f, ri = s * 0.34f;
        int teeth = 8;
        for (int i = 0; i < teeth * 2; ++i) {
            CGFloat a0 = (CGFloat)M_PI * 2 * i / (teeth * 2), a1 = (CGFloat)M_PI * 2 * (i + 1) / (teeth * 2);
            CGFloat r = (i % 2) ? ri : ro;
            if (i == 0) CGContextMoveToPoint(ctx, c + cosf(a0) * r, c + sinf(a0) * r);
            CGContextAddLineToPoint(ctx, c + cosf(a0) * r, c + sinf(a0) * r);
            CGContextAddLineToPoint(ctx, c + cosf(a1) * r, c + sinf(a1) * r);
        }
        CGContextClosePath(ctx);
        CGContextAddEllipseInRect(ctx, CGRectMake(c - s * 0.14f, c - s * 0.14f, s * 0.28f, s * 0.28f));
        CGContextEOFillPath(ctx);
    });
}

UIImage *LRGlyphSeek(CGFloat size, int direction, UIColor *color) {
    return LRGlyph(size, ^(CGContextRef ctx, CGFloat s) {
        LRDrawSeekGlyph(ctx, CGPointMake(s / 2, s / 2), s * 0.5f, direction, color);
    });
}

UIImage *LRGlyphList(CGFloat size, UIColor *color) {
    return LRGlyph(size, ^(CGContextRef ctx, CGFloat s) {
        [color setFill];
        for (int i = 0; i < 3; ++i) {
            CGFloat y = s * (0.22f + i * 0.25f);
            CGContextFillEllipseInRect(ctx, CGRectMake(s * 0.1f, y, s * 0.13f, s * 0.13f));
            CGContextFillRect(ctx, CGRectMake(s * 0.32f, y + s * 0.02f, s * 0.58f, s * 0.09f));
        }
    });
}

UIImage *LRGlyphRefresh(CGFloat size, UIColor *color) {
    return LRGlyph(size, ^(CGContextRef ctx, CGFloat s) {
        [color set];
        CGContextSetLineWidth(ctx, s * 0.12f);
        CGContextAddArc(ctx, s / 2, s / 2, s * 0.32f, (CGFloat)-M_PI * 0.35f, (CGFloat)M_PI * 1.35f, 0);
        CGContextStrokePath(ctx);
        CGFloat ax = s / 2 + cosf((CGFloat)-M_PI * 0.35f) * s * 0.32f;
        CGFloat ay = s / 2 + sinf((CGFloat)-M_PI * 0.35f) * s * 0.32f;
        CGContextMoveToPoint(ctx, ax + s * 0.16f, ay - s * 0.02f);
        CGContextAddLineToPoint(ctx, ax - s * 0.06f, ay - s * 0.18f);
        CGContextAddLineToPoint(ctx, ax - s * 0.04f, ay + s * 0.12f);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    });
}

UIImage *LRGlyphClose(CGFloat size, UIColor *color) {
    return LRGlyph(size, ^(CGContextRef ctx, CGFloat s) {
        [color setStroke];
        CGContextSetLineWidth(ctx, s * 0.14f);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextMoveToPoint(ctx, s * 0.25f, s * 0.25f);
        CGContextAddLineToPoint(ctx, s * 0.75f, s * 0.75f);
        CGContextMoveToPoint(ctx, s * 0.75f, s * 0.25f);
        CGContextAddLineToPoint(ctx, s * 0.25f, s * 0.75f);
        CGContextStrokePath(ctx);
    });
}

UIImage *LRGlyphDots(CGFloat size, UIColor *color) {
    return LRGlyph(size, ^(CGContextRef ctx, CGFloat s) {
        [color setFill];
        for (int i = 0; i < 3; ++i)
            CGContextFillEllipseInRect(ctx, CGRectMake(s * (0.14f + i * 0.28f), s * 0.42f,
                                                       s * 0.16f, s * 0.16f));
    });
}
