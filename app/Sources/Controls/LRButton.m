#import "LRButton.h"
#import "LRDraw.h"
#import "LRSound.h"

static NSMutableDictionary *gButtonImages = nil;

static UIColor *W(CGFloat white, CGFloat alpha) {
    return [UIColor colorWithWhite:white alpha:alpha];
}

static UIColor *RGB(unsigned rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0f green:((rgb >> 8) & 0xff) / 255.0f
                            blue:(rgb & 0xff) / 255.0f alpha:1];
}

static BOOL LRBarStyle(LRButtonStyle style) {
    return style == LRButtonBar || style == LRButtonBack || style == LRButtonDone;
}

static void LRAddButtonShape(CGContextRef ctx, CGRect r, CGFloat radius, BOOL back) {
    if (!back) {
        LRAddRoundRect(ctx, r, radius);
        return;
    }
    CGFloat point = r.size.height * 0.36f;
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

/* a glossy body: two gradients meeting at the middle, like ios 6 */
static void LRGloss(CGContextRef ctx, CGRect r, UIColor *top, UIColor *bottom) {
    CGFloat locs[4] = { 0, 0.5f, 0.5f, 1 };
    LRFillLinear(ctx, CGPointMake(0, r.origin.y), CGPointMake(0, CGRectGetMaxY(r)),
                 [NSArray arrayWithObjects:LRColorMix(top, W(1, 1), 0.18f), LRColorMix(top, bottom, 0.35f),
                  LRColorMix(top, bottom, 0.62f), bottom, nil], locs);
}

#pragma mark flat

/* flat buttons: text only for the plain styles, solid fills for the
   coloured actions */
static BOOL LRFlatTextOnly(LRButtonStyle style) {
    return !(style == LRButtonGreen || style == LRButtonRed || style == LRButtonDark || style == LRButtonRow);
}

static UIImage *LRFlatButtonImage(LRButtonStyle style, CGFloat height, BOOL pressed) {
    if (LRFlatTextOnly(style)) return nil;
    LRSkin *s = SKIN;
    CGFloat radius = style == LRButtonRow ? 0 : 6;
    CGFloat cap = radius + 2;
    CGFloat width = cap * 2 + 1;
    UIColor *fill = nil;
    switch (style) {
        case LRButtonGreen: fill = s->ledGreen; break;
        case LRButtonRed: fill = s->ledRed; break;
        case LRButtonDark: fill = W(0.20f, 1); break;
        case LRButtonRow: fill = pressed ? W(0.85f, 1) : nil; break;
        default: break;
    }
    if (pressed && style != LRButtonRow && fill) fill = LRColorMix(fill, [UIColor blackColor], 0.18f);
    if (!fill) return nil;
    UIImage *img = LRImageWithSize(CGSizeMake(width, height), NO, ^(CGContextRef ctx, CGRect rect) {
        LRAddRoundRect(ctx, rect, radius);
        [fill setFill];
        CGContextFillPath(ctx);
    });
    return LRStretchable(img, cap, 0);
}

#pragma mark classic

static UIImage *LRClassicButtonImage(LRButtonStyle style, CGFloat height, BOOL pressed) {
    LRSkin *s = SKIN;
    BOOL back = style == LRButtonBack;
    if (style == LRButtonRow) {
        if (!pressed) return nil;
        UIImage *img = LRImageWithSize(CGSizeMake(3, height), YES, ^(CGContextRef ctx, CGRect rect) {
            LRFillVertical(ctx, rect, s->groupPressed, s->groupPressedBottom);
        });
        return LRStretchable(img, 1, 0);
    }
    CGFloat radius = LRBarStyle(style) || style == LRButtonAlert || style == LRButtonAlertDefault
        ? 5 : MIN(8.0f, height * 0.25f);
    CGFloat cap = back ? height * 0.36f + radius + 4 : radius + 2;
    CGFloat width = cap * 2 + 1;
    UIImage *img = LRImageWithSize(CGSizeMake(width, height), NO, ^(CGContextRef ctx, CGRect rect) {
        CGRect body = CGRectMake(0, 0, width, height - 1);
        /* the lip under the key: white on the tables, faint on the denim */
        BOOL onLight = style == LRButtonMetal || style == LRButtonGreen || style == LRButtonRed;
        LRAddButtonShape(ctx, CGRectOffset(body, 0, 1), radius, back);
        CGContextSetRGBFillColor(ctx, 1, 1, 1, onLight ? 0.75f : 0.12f);
        CGContextFillPath(ctx);
        CGContextSaveGState(ctx);
        CGContextSetBlendMode(ctx, kCGBlendModeClear);
        LRAddButtonShape(ctx, body, radius, back);
        CGContextFillPath(ctx);
        CGContextRestoreGState(ctx);
        CGContextSaveGState(ctx);
        LRAddButtonShape(ctx, CGRectInset(body, 1, 1), MAX(1, radius - 1), back);
        CGContextClip(ctx);
        switch (style) {
            case LRButtonMetal:
                if (pressed) LRFillVertical(ctx, body, s->groupPressed, s->groupPressedBottom);
                else LRFillVertical(ctx, body, W(1, 1), W(0.93f, 1));
                break;
            case LRButtonDark:
                LRGloss(ctx, body, pressed ? W(0.22f, 1) : W(0.40f, 1), pressed ? W(0.08f, 1) : W(0.15f, 1));
                break;
            case LRButtonGreen:
                LRGloss(ctx, body, pressed ? RGB(0x4E9A40) : RGB(0x72C45E), pressed ? RGB(0x1E6A17) : RGB(0x2E8E24));
                break;
            case LRButtonRed:
                LRGloss(ctx, body, pressed ? RGB(0xB8453F) : RGB(0xE66F69), pressed ? RGB(0x8A1712) : RGB(0xB2231C));
                break;
            case LRButtonDone:
                LRGloss(ctx, body, pressed ? RGB(0x3A6BC4) : RGB(0x5B8FE6), pressed ? RGB(0x1B449C) : RGB(0x2458C4));
                break;
            case LRButtonBar:
            case LRButtonBack: {
                /* translucent, so the denim of the bar shows through */
                CGContextSetRGBFillColor(ctx, 0, 0, 0, pressed ? 0.5f : 0.28f);
                CGContextFillRect(ctx, body);
                CGFloat locs[4] = { 0, 0.5f, 0.5f, 1 };
                CGFloat a = pressed ? 0.04f : 0.22f, b = pressed ? 0 : 0.07f;
                LRFillLinear(ctx, CGPointMake(0, 0), CGPointMake(0, body.size.height),
                             [NSArray arrayWithObjects:W(1, a), W(1, (a + b) / 2), W(1, b), W(1, b * 0.6f), nil],
                             locs);
                break;
            }
            case LRButtonAlert:
            case LRButtonAlertDefault: {
                BOOL primary = style == LRButtonAlertDefault;
                CGFloat a = pressed ? 0.10f : (primary ? 0.45f : 0.32f);
                CGFloat b = pressed ? 0.04f : (primary ? 0.20f : 0.10f);
                CGFloat locs[4] = { 0, 0.5f, 0.5f, 1 };
                LRFillLinear(ctx, CGPointMake(0, 0), CGPointMake(0, body.size.height),
                             [NSArray arrayWithObjects:W(1, a), W(1, (a + b) / 2 + 0.04f), W(1, b), W(1, b * 1.2f), nil],
                             locs);
                break;
            }
            case LRButtonRow:
                break;
        }
        CGContextRestoreGState(ctx);
        /* the rim, then a line of light just inside the top */
        CGContextSaveGState(ctx);
        LRAddButtonShape(ctx, CGRectInset(body, 0.5f, 0.5f), radius - 0.5f, back);
        CGFloat rim = style == LRButtonMetal ? 0.35f : (onLight ? 0.55f : 0.75f);
        CGContextSetRGBStrokeColor(ctx, 0, 0, 0, rim);
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokePath(ctx);
        CGContextRestoreGState(ctx);
        if (style != LRButtonMetal || !pressed) {
            CGContextSaveGState(ctx);
            LRAddButtonShape(ctx, CGRectInset(body, 1, 1), MAX(1, radius - 1), back);
            CGContextClip(ctx);
            CGContextSetRGBFillColor(ctx, 1, 1, 1, pressed ? 0.06f : (style == LRButtonMetal ? 0.9f : 0.3f));
            CGContextFillRect(ctx, CGRectMake(0, 1, width, 1));
            CGContextRestoreGState(ctx);
        }
    });
    return LRStretchable(img, cap, 0);
}

static UIImage *LRButtonImage(LRButtonStyle style, CGFloat height, BOOL pressed) {
    NSString *key = [NSString stringWithFormat:@"%d.%.0f.%d.%d", style, height, pressed, SKIN->flat];
    id cached = [gButtonImages objectForKey:key];
    if (cached) return cached == [NSNull null] ? nil : cached;
    UIImage *img = SKIN->flat ? LRFlatButtonImage(style, height, pressed)
                              : LRClassicButtonImage(style, height, pressed);
    if (!gButtonImages) gButtonImages = [[NSMutableDictionary alloc] init];
    [gButtonImages setObject:img ? (id)img : (id)[NSNull null] forKey:key];
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
        self.titleLabel.font = [LRSkin boldFont:15];
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
    if (_glyph) [self setGlyph:[[_glyph retain] autorelease]];
}

- (void)applyFlatStyle {
    LRSkin *s = SKIN;
    BOOL filled = _style == LRButtonGreen || _style == LRButtonRed || _style == LRButtonDark;
    UIColor *text = filled ? [UIColor whiteColor] : (_style == LRButtonRow ? s->groupInk : s->tint);
    [self setTitleColor:text forState:UIControlStateNormal];
    [self setTitleColor:filled || _style == LRButtonRow ? LRColorAlpha(text, 0.7f) : LRColorAlpha(text, 0.3f)
               forState:UIControlStateHighlighted];
    [self setTitleColor:LRColorAlpha(filled ? text : s->groupMuted, 0.5f) forState:UIControlStateDisabled];
    [self setTitleShadowColor:[UIColor clearColor] forState:UIControlStateNormal];
    self.titleLabel.shadowOffset = CGSizeZero;
    self.titleEdgeInsets = _style == LRButtonBack ? UIEdgeInsetsMake(0, 14, 0, 0) : UIEdgeInsetsZero;
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
    LRSkin *s = SKIN;
    if (_style == LRButtonMetal) {
        /* the stock rounded rect: blue-grey bold text, white when pressed */
        [self setTitleColor:s->groupDetail forState:UIControlStateNormal];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
        [self setTitleColor:LRColorAlpha(s->groupDetail, 0.4f) forState:UIControlStateDisabled];
        [self setTitleShadowColor:W(1, 0.9f) forState:UIControlStateNormal];
        [self setTitleShadowColor:W(0, 0.25f) forState:UIControlStateHighlighted];
        self.titleLabel.shadowOffset = CGSizeMake(0, 1);
    } else if (_style == LRButtonRow) {
        [self setTitleColor:s->groupInk forState:UIControlStateNormal];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
        [self setTitleColor:LRColorAlpha(s->groupInk, 0.4f) forState:UIControlStateDisabled];
        [self setTitleShadowColor:[UIColor clearColor] forState:UIControlStateNormal];
        self.titleLabel.shadowOffset = CGSizeZero;
    } else {
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self setTitleColor:W(1, 0.45f) forState:UIControlStateDisabled];
        [self setTitleShadowColor:W(0, 0.55f) forState:UIControlStateNormal];
        self.titleLabel.shadowOffset = CGSizeMake(0, -1);
    }
    self.titleEdgeInsets = _style == LRButtonBack ? UIEdgeInsetsMake(0, 8, 0, 0) : UIEdgeInsetsZero;
    [self updateImages];
}

- (void)updateImages {
    CGFloat h = self.bounds.size.height;
    if (h < 8) return;
    [self setBackgroundImage:LRButtonImage(_style, h, NO) forState:UIControlStateNormal];
    [self setBackgroundImage:LRButtonImage(_style, h, YES) forState:UIControlStateHighlighted];
}

- (void)setFrame:(CGRect)frame {
    BOOL heightChanged = frame.size.height != self.frame.size.height;
    [super setFrame:frame];
    if (heightChanged) [self updateImages];
}

- (void)setGlyph:(UIImage *)glyph {
    [_glyph release];
    _glyph = [glyph retain];
    BOOL dark = _style != LRButtonMetal && _style != LRButtonRow;
    UIImage *shown = glyph && !SKIN->flat && dark ? LRShadowedGlyph(glyph, W(0, 0.55f)) : glyph;
    [self setImage:shown forState:UIControlStateNormal];
}
@end

#pragma mark glyphs

UIImage *LRShadowedGlyph(UIImage *glyph, UIColor *shadow) {
    if (!glyph) return nil;
    CGSize size = glyph.size;
    /* the glyph's shape in the shadow colour */
    UIImage *silhouette = LRImageWithSize(size, NO, ^(CGContextRef ctx, CGRect rect) {
        [glyph drawInRect:rect];
        CGContextSetBlendMode(ctx, kCGBlendModeSourceIn);
        [shadow setFill];
        CGContextFillRect(ctx, rect);
    });
    return LRImageWithSize(CGSizeMake(size.width, size.height + 1), NO, ^(CGContextRef ctx, CGRect rect) {
        [silhouette drawAtPoint:CGPointMake(0, 0)];
        [glyph drawAtPoint:CGPointMake(0, 1)];
    });
}

static UIImage *LRGlyph(CGFloat size, void (^draw)(CGContextRef, CGFloat)) {
    return LRImageWithSize(CGSizeMake(size, size), NO, ^(CGContextRef ctx, CGRect rect) {
        draw(ctx, size);
    });
}

UIImage *LRGlyphPlus(CGFloat size, UIColor *color) {
    return LRGlyph(size, ^(CGContextRef ctx, CGFloat s) {
        [color setFill];
        CGFloat t = roundf(s * 0.15f * 2) / 2;
        CGContextFillRect(ctx, CGRectMake(s * 0.14f, (s - t) / 2, s * 0.72f, t));
        CGContextFillRect(ctx, CGRectMake((s - t) / 2, s * 0.14f, t, s * 0.72f));
    });
}

UIImage *LRGlyphGear(CGFloat size, UIColor *color) {
    return LRGlyph(size, ^(CGContextRef ctx, CGFloat s) {
        [color setFill];
        CGFloat c = s / 2, ro = s * 0.48f, ri = s * 0.36f;
        int teeth = 8;
        for (int i = 0; i < teeth * 2; ++i) {
            CGFloat a0 = (CGFloat)M_PI * 2 * i / (teeth * 2), a1 = (CGFloat)M_PI * 2 * (i + 1) / (teeth * 2);
            CGFloat r = (i % 2) ? ri : ro;
            if (i == 0) CGContextMoveToPoint(ctx, c + cosf(a0) * r, c + sinf(a0) * r);
            CGContextAddLineToPoint(ctx, c + cosf(a0) * r, c + sinf(a0) * r);
            CGContextAddLineToPoint(ctx, c + cosf(a1) * r, c + sinf(a1) * r);
        }
        CGContextClosePath(ctx);
        CGContextAddEllipseInRect(ctx, CGRectMake(c - s * 0.15f, c - s * 0.15f, s * 0.30f, s * 0.30f));
        CGContextEOFillPath(ctx);
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
