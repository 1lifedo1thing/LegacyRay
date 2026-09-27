#import "LRPowerButton.h"
#import "LRDraw.h"
#import "LRSound.h"

@implementation LRPowerButton
@synthesize powerState = _powerState;

static UIColor *LRPowerColor(LRPowerState s) {
    switch (s) {
        case LRPowerOn: return SKIN->ledGreen;
        case LRPowerTuning: return SKIN->ledAmber;
        case LRPowerFault: return SKIN->ledRed;
        case LRPowerOff: break;
    }
    return [UIColor colorWithRed:0.88f green:0.27f blue:0.18f alpha:1];
}

- (CGFloat)radius {
    return MIN(self.bounds.size.width, self.bounds.size.height) / 2 - 12;
}

/* seat + dark gap drawn in drawRect; skirt and cap are images so pressing only
   moves a layer */
- (UIImage *)skirtImage:(CGFloat)R {
    return LRImageWithSize(CGSizeMake(R * 2 + 2, R * 2 + 2), NO, ^(CGContextRef ctx, CGRect rect) {
        CGPoint c = CGPointMake(R + 1, R + 1);
        CGRect disc = CGRectMake(1, 1, R * 2, R * 2);
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, disc);
        CGContextClip(ctx);
        CGFloat locs[3] = { 0, 0.5f, 1 };
        LRFillLinear(ctx, CGPointMake(0, 1), CGPointMake(0, R * 2 + 1),
                     [NSArray arrayWithObjects:[UIColor colorWithWhite:0.94f alpha:1],
                      [UIColor colorWithWhite:0.60f alpha:1], [UIColor colorWithWhite:0.87f alpha:1], nil], locs);
        /* knurling */
        CGContextSetLineWidth(ctx, 1.1f);
        for (int k = 0; k < 120; k += 2) {
            CGFloat a = (CGFloat)M_PI * 2 * k / 120;
            CGContextMoveToPoint(ctx, c.x + cosf(a) * R * 0.80f, c.y + sinf(a) * R * 0.80f);
            CGContextAddLineToPoint(ctx, c.x + cosf(a) * R, c.y + sinf(a) * R);
        }
        CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.13f);
        CGContextStrokePath(ctx);
        CGContextRestoreGState(ctx);
        CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.55f);
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokeEllipseInRect(ctx, CGRectInset(disc, 0.5f, 0.5f));
    });
}

- (UIImage *)capImage:(CGFloat)R pressed:(BOOL)pressed color:(UIColor *)glow lit:(BOOL)lit {
    CGFloat rc = R * 0.78f;
    return LRImageWithSize(CGSizeMake(rc * 2 + 2, rc * 2 + 2), NO, ^(CGContextRef ctx, CGRect rect) {
        CGPoint c = CGPointMake(rc + 1, rc + 1);
        CGRect disc = CGRectMake(1, 1, rc * 2, rc * 2);
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, disc);
        CGContextClip(ctx);
        if (pressed)
            LRFillVertical(ctx, disc, [UIColor colorWithWhite:0.70f alpha:1], [UIColor colorWithWhite:0.86f alpha:1]);
        else
            LRFillVertical(ctx, disc, [UIColor colorWithWhite:0.975f alpha:1], [UIColor colorWithWhite:0.73f alpha:1]);
        /* concentric machining */
        unsigned seed = 5;
        CGContextSetLineWidth(ctx, 0.7f);
        for (CGFloat r = 2; r < rc; ) {
            seed = seed * 1103515245u + 12345u;
            BOOL light = (seed >> 16) & 1;
            CGContextSetRGBStrokeColor(ctx, light, light, light, light ? 0.10f : 0.05f);
            CGContextStrokeEllipseInRect(ctx, CGRectMake(c.x - r, c.y - r, r * 2, r * 2));
            r += 1.2f + ((seed >> 8) & 0xff) / 255.0f;
        }
        /* anisotropic highlight: two bright wedges */
        CGFloat starts[2] = { -0.95f, (CGFloat)M_PI - 0.95f };
        for (int i = 0; i < 2; ++i) {
            CGContextMoveToPoint(ctx, c.x, c.y);
            CGContextAddArc(ctx, c.x, c.y, rc, starts[i], starts[i] + 0.5f, 0);
            CGContextClosePath(ctx);
            CGContextSetRGBFillColor(ctx, 1, 1, 1, pressed ? 0.12f : 0.30f);
            CGContextFillPath(ctx);
        }
        CGContextRestoreGState(ctx);
        CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.35f);
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokeEllipseInRect(ctx, CGRectInset(disc, 0.5f, 0.5f));
        /* engraved power glyph, lit from behind when on */
        CGFloat gr = rc * 0.42f;
        UIColor *ink = lit ? LRColorMix(glow, [UIColor whiteColor], 0.15f)
                           : [UIColor colorWithWhite:0.32f alpha:1];
        for (int pass = 0; pass < 2; ++pass) {
            CGFloat dy = pass == 0 ? 1 : 0;
            CGContextSaveGState(ctx);
            if (pass == 0) CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 0.8f);
            else {
                [ink setStroke];
                if (lit) CGContextSetShadowWithColor(ctx, CGSizeZero, 6, glow.CGColor);
            }
            CGContextSetLineCap(ctx, kCGLineCapRound);
            CGContextSetLineWidth(ctx, rc * 0.11f);
            CGContextAddArc(ctx, c.x, c.y + dy, gr, (CGFloat)-M_PI_2 + 0.75f,
                            (CGFloat)-M_PI_2 - 0.75f + (CGFloat)M_PI * 2, 0);
            CGContextStrokePath(ctx);
            CGContextMoveToPoint(ctx, c.x, c.y + dy - gr * 1.18f);
            CGContextAddLineToPoint(ctx, c.x, c.y + dy - gr * 0.25f);
            CGContextStrokePath(ctx);
            CGContextRestoreGState(ctx);
        }
    });
}

/* flat: a disc inside a thin ring. green and filled when on, the ring alone
   (pulsing amber) while tuning, white with a grey ring on standby */
- (UIImage *)flatCapImage:(CGFloat)R pressed:(BOOL)pressed color:(UIColor *)color {
    CGFloat rc = R - 7;
    BOOL filled = _powerState == LRPowerOn;
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
        UIColor *ink = filled ? [UIColor whiteColor]
            : (_powerState == LRPowerOff ? [UIColor colorWithWhite:0.55f alpha:1] : color);
        CGFloat gr = rc * 0.36f;
        [ink setStroke];
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetLineWidth(ctx, MAX(2.0f, rc * 0.07f));
        CGContextAddArc(ctx, c.x, c.y, gr, (CGFloat)-M_PI_2 + 0.75f,
                        (CGFloat)-M_PI_2 - 0.75f + (CGFloat)M_PI * 2, 0);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, c.x, c.y - gr * 1.18f);
        CGContextAddLineToPoint(ctx, c.x, c.y - gr * 0.25f);
        CGContextStrokePath(ctx);
    });
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _ring = [[CAShapeLayer layer] retain];
        _ring.fillColor = [UIColor clearColor].CGColor;
        _ring.shadowOffset = CGSizeZero;
        _ring.shadowOpacity = 1;
        _ring.shadowRadius = 9;
        [self.layer addSublayer:_ring];
        _skirt = [[UIImageView alloc] init];
        _cap = [[UIImageView alloc] init];
        _skirt.userInteractionEnabled = NO;
        _cap.userInteractionEnabled = NO;
        [self addSubview:_skirt];
        [self addSubview:_cap];
        [self rebuild];
    }
    return self;
}

- (void)dealloc {
    [_ring release];
    [_skirt release];
    [_cap release];
    [super dealloc];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self rebuild];
}

- (void)rebuild {
    CGFloat R = [self radius];
    if (R < 10) return;
    CGPoint c = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGFloat ringR = SKIN->flat ? R - 1.5f : R + 4.5f;
    CGMutablePathRef p = CGPathCreateMutable();
    CGPathAddEllipseInRect(p, NULL, CGRectMake(c.x - ringR, c.y - ringR, ringR * 2, ringR * 2));
    _ring.path = p;
    _ring.frame = self.bounds;
    _ring.lineWidth = SKIN->flat ? 3.0f : R * 0.10f;
    _skirt.hidden = SKIN->flat;
    /* no shadowPath: CGPathCreateCopyByStrokingPath is ios 5+, and one layer
       rendering its own shadow is cheap enough */
    CGPathRelease(p);
    _skirt.image = [self skirtImage:R];
    _skirt.frame = CGRectMake(c.x - R - 1, c.y - R - 1, R * 2 + 2, R * 2 + 2);
    [self applyState];
    [self setNeedsDisplay];
}

- (void)applyState {
    CGFloat R = [self radius];
    if (R < 10) return;
    UIColor *color = LRPowerColor(_powerState);
    BOOL lit = _powerState != LRPowerOff;
    CGPoint c = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGFloat rc = R * 0.78f;
    BOOL pressed = self.highlighted;
    BOOL flat = SKIN->flat;
    if (flat) {
        rc = R - 7;
        _cap.image = [self flatCapImage:R pressed:pressed color:color];
        _cap.frame = CGRectMake(c.x - rc - 1, c.y - rc - 1, rc * 2 + 2, rc * 2 + 2);
    } else {
        _cap.image = [self capImage:R pressed:pressed color:color lit:lit];
        _cap.frame = CGRectMake(c.x - rc - 1, c.y - rc - 1 + (pressed ? 1.5f : 0), rc * 2 + 2, rc * 2 + 2);
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (flat) {
        _ring.strokeColor = (lit ? color : [UIColor colorWithWhite:0.80f alpha:1]).CGColor;
        _ring.shadowOpacity = 0;
    } else {
        _ring.strokeColor = (lit ? color : LRColorMix(color, [UIColor blackColor], 0.72f)).CGColor;
        _ring.shadowColor = color.CGColor;
        _ring.shadowOpacity = lit ? 1.0f : 0.0f;
    }
    [CATransaction commit];
    [_ring removeAnimationForKey:@"pulse"];
    if (_powerState == LRPowerTuning) {
        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"];
        a.fromValue = [NSNumber numberWithFloat:1];
        a.toValue = [NSNumber numberWithFloat:0.3f];
        a.duration = 0.55;
        a.autoreverses = YES;
        a.repeatCount = HUGE_VALF;
        [_ring addAnimation:a forKey:@"pulse"];
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

- (void)drawRect:(CGRect)rect {
    if (SKIN->flat) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat R = [self radius];
    CGPoint c = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    /* soft shadow the knob casts on the plate */
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 3), 8, [UIColor colorWithWhite:0 alpha:0.5f].CGColor);
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.3f);
    CGContextFillEllipseInRect(ctx, CGRectMake(c.x - R - 7, c.y - R - 7, (R + 7) * 2, (R + 7) * 2));
    CGContextRestoreGState(ctx);
    /* recessed seat: dark above, light lip below */
    CGRect seat = CGRectMake(c.x - R - 7, c.y - R - 7, (R + 7) * 2, (R + 7) * 2);
    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, seat);
    CGContextClip(ctx);
    LRFillVertical(ctx, seat, [UIColor colorWithWhite:0 alpha:0.5f],
                   [UIColor colorWithWhite:1 alpha:SKIN->night ? 0.15f : 0.5f]);
    CGContextRestoreGState(ctx);
    CGContextSetRGBFillColor(ctx, 0.07f, 0.07f, 0.08f, 1);
    CGContextFillEllipseInRect(ctx, CGRectInset(seat, 1.5f, 1.5f));
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGPoint c = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGFloat dx = point.x - c.x, dy = point.y - c.y;
    CGFloat r = [self radius] + 10;
    return dx * dx + dy * dy <= r * r;
}
@end
