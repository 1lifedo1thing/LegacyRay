#import "LRPowerButton.h"
#import "LRDraw.h"
#import "LRSound.h"

/* between the cap and the frame: the well (9) and the stitched ring (17) */
#define LR_POWER_MARGIN 19.0f

@implementation LRPowerButton
@synthesize powerState = _powerState;

+ (CGFloat)radiusForSide:(CGFloat)side {
    return SKIN->flat ? side / 2 - 12 : side / 2 - LR_POWER_MARGIN;
}

+ (CGFloat)sideForRadius:(CGFloat)radius {
    return SKIN->flat ? radius * 2 + 24 : radius * 2 + LR_POWER_MARGIN * 2;
}

static UIColor *LRPowerColor(LRPowerState s) {
    switch (s) {
        case LRPowerOn: return SKIN->ledGreen;
        case LRPowerTuning: return SKIN->ledAmber;
        case LRPowerFault: return SKIN->ledRed;
        case LRPowerOff: break;
    }
    return SKIN->flat ? [UIColor colorWithWhite:0.55f alpha:1] : [UIColor colorWithRed:0.635f green:0.647f blue:0.663f alpha:1];
}

- (CGFloat)radius {
    return [LRPowerButton radiusForSide:MIN(self.bounds.size.width, self.bounds.size.height)];
}

static void LRAddPowerGlyph(CGContextRef ctx, CGPoint c, CGFloat gr) {
    CGContextAddArc(ctx, c.x, c.y, gr, (CGFloat)-M_PI_2 + 0.72f, (CGFloat)-M_PI_2 - 0.72f + (CGFloat)M_PI * 2, 0);
    CGContextMoveToPoint(ctx, c.x, c.y - gr * 1.22f);
    CGContextAddLineToPoint(ctx, c.x, c.y - gr * 0.28f);
}

#pragma mark classic

/* the pearl: matte white cloth over a dome, the icon's twill just visible */
- (UIImage *)capImage:(CGFloat)R pressed:(BOOL)pressed {
    return LRImageWithSize(CGSizeMake(R * 2, R * 2), NO, ^(CGContextRef ctx, CGRect rect) {
        CGPoint c = CGPointMake(R, R);
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, rect);
        CGContextClip(ctx);
        if (pressed)
            LRFillVertical(ctx, rect, [UIColor colorWithRed:0.894f green:0.894f blue:0.886f alpha:1],
                           [UIColor colorWithRed:0.769f green:0.773f blue:0.761f alpha:1]);
        else
            LRFillVertical(ctx, rect, [UIColor colorWithRed:0.984f green:0.984f blue:0.980f alpha:1],
                           [UIColor colorWithRed:0.831f green:0.835f blue:0.824f alpha:1]);
        UIImage *tile = LRDenimTile();
        if (tile) {
            CGContextSaveGState(ctx);
            CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
            CGContextSetAlpha(ctx, 0.035f);
            [[UIColor colorWithPatternImage:tile] setFill];
            CGContextFillRect(ctx, rect);
            CGContextRestoreGState(ctx);
        }
        LRFillRadial(ctx, CGPointMake(c.x - R * 0.25f, c.y - R * 0.55f), 0, R * 1.2f,
                     [UIColor colorWithWhite:1 alpha:pressed ? 0.3f : 0.55f], [UIColor colorWithWhite:1 alpha:0]);
        CGContextRestoreGState(ctx);
        CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.55f);
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokeEllipseInRect(ctx, CGRectInset(rect, 0.5f, 0.5f));
        CGContextSetRGBStrokeColor(ctx, 1, 1, 1, pressed ? 0.5f : 0.9f);
        CGContextAddArc(ctx, c.x, c.y, R - 1.5f, (CGFloat)M_PI * 1.1f, (CGFloat)M_PI * 1.9f, 0);
        CGContextStrokePath(ctx);
    });
}

/* the glyph pressed into the cloth; lit from behind when the tunnel is up */
- (UIImage *)glyphImage:(CGFloat)R state:(LRPowerState)state {
    CGFloat gr = R * 0.34f, lw = MAX(2.0f, R * 0.085f);
    CGFloat side = ceilf(gr * 2.6f + lw + 14);
    UIColor *ink = LRPowerColor(state);
    BOOL lit = state != LRPowerOff;
    return LRImageWithSize(CGSizeMake(side, side), NO, ^(CGContextRef ctx, CGRect rect) {
        CGPoint c = CGPointMake(side / 2, side / 2 + gr * 0.1f);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetLineWidth(ctx, lw);
        /* the light catches the lower edge of the groove */
        LRAddPowerGlyph(ctx, CGPointMake(c.x, c.y + 1), gr);
        CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 0.95f);
        CGContextStrokePath(ctx);
        LRAddPowerGlyph(ctx, CGPointMake(c.x, c.y - 0.6f), gr);
        CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.18f);
        CGContextStrokePath(ctx);
        CGContextSaveGState(ctx);
        if (lit) CGContextSetShadowWithColor(ctx, CGSizeZero, 5, LRColorAlpha(ink, 0.6f).CGColor);
        LRAddPowerGlyph(ctx, c, gr);
        [ink setStroke];
        CGContextStrokePath(ctx);
        CGContextRestoreGState(ctx);
    });
}

#pragma mark flat

/* a disc inside a thin ring: green and filled when on, the ring alone
   (pulsing amber) while tuning, white with a grey ring on standby */
- (UIImage *)flatCapImage:(CGFloat)R pressed:(BOOL)pressed color:(UIColor *)color {
    CGFloat rc = R - 7;
    BOOL filled = _powerState == LRPowerOn;
    LRPowerState state = _powerState;
    return LRImageWithSize(CGSizeMake(rc * 2 + 2, rc * 2 + 2), NO, ^(CGContextRef ctx, CGRect rect) {
        CGPoint c = CGPointMake(rc + 1, rc + 1);
        CGRect disc = CGRectMake(1, 1, rc * 2, rc * 2);
        UIColor *fill = filled ? color : [UIColor whiteColor];
        if (pressed) fill = LRColorMix(fill, [UIColor blackColor], 0.08f);
        [fill setFill];
        CGContextFillEllipseInRect(ctx, disc);
        if (!filled) {
            [[UIColor colorWithWhite:0 alpha:0.06f] setStroke];
            CGContextSetLineWidth(ctx, 1);
            CGContextStrokeEllipseInRect(ctx, CGRectInset(disc, 0.5f, 0.5f));
        }
        UIColor *ink = filled ? [UIColor whiteColor] : (state == LRPowerOff ? [UIColor colorWithWhite:0.55f alpha:1] : color);
        [ink setStroke];
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetLineWidth(ctx, MAX(2.0f, rc * 0.07f));
        LRAddPowerGlyph(ctx, c, rc * 0.36f);
        CGContextStrokePath(ctx);
    });
}

#pragma mark control

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        if (SKIN->flat) {
            _ring = [[CAShapeLayer layer] retain];
            _ring.fillColor = [UIColor clearColor].CGColor;
            [self.layer addSublayer:_ring];
        }
        _cap = [[UIImageView alloc] init];
        _cap.userInteractionEnabled = NO;
        [self addSubview:_cap];
        _glyph = [[UIImageView alloc] init];
        _glyph.userInteractionEnabled = NO;
        _glyph.hidden = SKIN->flat;
        [self addSubview:_glyph];
    }
    return self;
}

- (void)dealloc {
    [_ring release];
    [_cap release];
    [_glyph release];
    [super dealloc];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat R = [self radius];
    if (R < 10 || R == _builtFor) return;
    _builtFor = R;
    if (_ring) {
        CGPoint c = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        CGFloat ringR = R - 1.5f;
        CGMutablePathRef p = CGPathCreateMutable();
        CGPathAddEllipseInRect(p, NULL, CGRectMake(c.x - ringR, c.y - ringR, ringR * 2, ringR * 2));
        _ring.path = p;
        CGPathRelease(p);
        _ring.frame = self.bounds;
        _ring.lineWidth = 3;
    }
    [self applyState];
    [self setNeedsDisplay];
}

- (void)applyState {
    CGFloat R = [self radius];
    if (R < 10) return;
    UIColor *color = LRPowerColor(_powerState);
    CGPoint c = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    BOOL pressed = self.highlighted;
    CALayer *pulsing;
    if (SKIN->flat) {
        CGFloat rc = R - 7;
        _cap.image = [self flatCapImage:R pressed:pressed color:color];
        _cap.frame = CGRectMake(c.x - rc - 1, c.y - rc - 1, rc * 2 + 2, rc * 2 + 2);
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        _ring.strokeColor = (_powerState != LRPowerOff ? color : [UIColor colorWithWhite:0.80f alpha:1]).CGColor;
        [CATransaction commit];
        pulsing = _ring;
    } else {
        CGFloat dy = pressed ? 1 : 0;
        _cap.image = [self capImage:R pressed:pressed];
        _cap.frame = CGRectMake(c.x - R, c.y - R + dy, R * 2, R * 2);
        UIImage *g = [self glyphImage:R state:_powerState];
        _glyph.image = g;
        _glyph.frame = CGRectMake(roundf(c.x - g.size.width / 2), roundf(c.y - g.size.height / 2) + dy,
                                  g.size.width, g.size.height);
        pulsing = _glyph.layer;
    }
    /* the one animation on the main screen, and only while connecting */
    [pulsing removeAnimationForKey:@"pulse"];
    if (_powerState == LRPowerTuning) {
        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"];
        a.fromValue = [NSNumber numberWithFloat:1];
        a.toValue = [NSNumber numberWithFloat:0.35f];
        a.duration = 0.8;
        a.autoreverses = YES;
        a.repeatCount = HUGE_VALF;
        a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [pulsing addAnimation:a forKey:@"pulse"];
    }
}

- (void)setPowerState:(LRPowerState)s {
    if (s == _powerState) return;
    _powerState = s;
    [self applyState];
}

- (void)setHighlighted:(BOOL)highlighted {
    BOOL changed = highlighted != self.highlighted;
    [super setHighlighted:highlighted];
    if (changed) {
        if (highlighted) [LRSound clunk];
        [self applyState];
    }
}

/* the stitched ring, the well and the cap's shadow in it: drawn once */
- (void)drawRect:(CGRect)rect {
    if (SKIN->flat) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat R = [self radius];
    CGPoint c = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    LRDrawStitchCircle(ctx, c, R + 17);
    CGFloat well = R + 9;
    CGRect wellRect = CGRectMake(c.x - well, c.y - well, well * 2, well * 2);
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.42f);
    CGContextFillEllipseInRect(ctx, wellRect);
    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, wellRect);
    CGContextClip(ctx);
    LRFillVertical(ctx, CGRectMake(wellRect.origin.x, wellRect.origin.y, wellRect.size.width, 14),
                   [UIColor colorWithWhite:0 alpha:0.5f], [UIColor colorWithWhite:0 alpha:0]);
    CGContextRestoreGState(ctx);
    CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 0.10f);
    CGContextSetLineWidth(ctx, 1);
    CGContextAddArc(ctx, c.x, c.y + 0.5f, well, (CGFloat)M_PI * 0.15f, (CGFloat)M_PI * 0.85f, 0);
    CGContextStrokePath(ctx);
    for (int i = 0; i < 7; ++i) {
        CGFloat r = R + 3.5f - i * 0.6f;
        CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.08f);
        CGContextFillEllipseInRect(ctx, CGRectMake(c.x - r, c.y + 3 - r, r * 2, r * 2));
    }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGPoint c = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGFloat dx = point.x - c.x, dy = point.y - c.y;
    CGFloat r = [self radius] + 12;
    return dx * dx + dy * dy <= r * r;
}
@end
