#import "LRToggleSwitch.h"
#import "LRDraw.h"
#import "LRSound.h"

CGSize LRToggleSwitchSize(void) {
    return SKIN->flat ? CGSizeMake(51, 31) : CGSizeMake(64, 28);
}

@implementation LRToggleSwitch
@synthesize on = _on;

static UIImage *LRFlatKnobImage(CGFloat h) {
    return LRImageWithSize(CGSizeMake(h, h + 2), NO, ^(CGContextRef ctx, CGRect rect) {
        CGRect disc = CGRectMake(1.5f, 1.5f, h - 3, h - 3);
        CGContextSaveGState(ctx);
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1.5f), 3,
                                    [UIColor colorWithWhite:0 alpha:0.3f].CGColor);
        [[UIColor whiteColor] setFill];
        CGContextFillEllipseInRect(ctx, disc);
        CGContextRestoreGState(ctx);
        [[UIColor colorWithWhite:0 alpha:0.06f] setStroke];
        CGContextSetLineWidth(ctx, 0.5f);
        CGContextStrokeEllipseInRect(ctx, disc);
    });
}

static UIImage *LRKnobImage(CGFloat h) {
    return LRImageWithSize(CGSizeMake(h, h + 2), NO, ^(CGContextRef ctx, CGRect rect) {
        CGRect disc = CGRectMake(1, 1, h - 2, h - 2);
        CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.35f);
        CGContextFillEllipseInRect(ctx, CGRectOffset(disc, 0, 1.5f));
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, disc);
        CGContextClip(ctx);
        LRFillVertical(ctx, disc, [UIColor colorWithWhite:0.99f alpha:1], [UIColor colorWithWhite:0.68f alpha:1]);
        CGContextRestoreGState(ctx);
        CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.5f);
        CGContextSetLineWidth(ctx, 0.8f);
        CGContextStrokeEllipseInRect(ctx, disc);
        CGFloat c = h / 2;
        for (int i = -1; i <= 1; ++i) {
            CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 0.8f);
            CGContextSetLineWidth(ctx, 1);
            CGContextMoveToPoint(ctx, c + i * 3.2f + 0.8f, c - h * 0.2f);
            CGContextAddLineToPoint(ctx, c + i * 3.2f + 0.8f, c + h * 0.2f);
            CGContextStrokePath(ctx);
            CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.28f);
            CGContextMoveToPoint(ctx, c + i * 3.2f, c - h * 0.2f);
            CGContextAddLineToPoint(ctx, c + i * 3.2f, c + h * 0.2f);
            CGContextStrokePath(ctx);
        }
    });
}

- (id)initWithFrame:(CGRect)frame {
    frame.size = LR_TOGGLE_SIZE;
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _knob = [[UIImageView alloc] initWithImage:SKIN->flat ? LRFlatKnobImage(frame.size.height)
                                                              : LRKnobImage(frame.size.height)];
        _knob.userInteractionEnabled = NO;
        [self addSubview:_knob];
        [self layoutKnob];
    }
    return self;
}

- (void)dealloc {
    [_knob release];
    [super dealloc];
}

- (void)layoutKnob {
    CGFloat h = self.bounds.size.height;
    CGFloat x = _on ? self.bounds.size.width - h : 0;
    _knob.frame = CGRectMake(x, 0, h, h + 2);
}

- (void)drawFlat:(CGContextRef)ctx {
    CGRect b = CGRectInset(self.bounds, 1, 1);
    CGFloat r = b.size.height / 2;
    LRAddRoundRect(ctx, b, r);
    if (_on) {
        [SKIN->ledGreen setFill];
        CGContextFillPath(ctx);
    } else {
        [[UIColor whiteColor] setFill];
        CGContextFillPath(ctx);
        LRAddRoundRect(ctx, CGRectInset(b, 0.75f, 0.75f), r);
        [[UIColor colorWithWhite:0.90f alpha:1] setStroke];
        CGContextSetLineWidth(ctx, 1.5f);
        CGContextStrokePath(ctx);
    }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (SKIN->flat) {
        [self drawFlat:ctx];
        return;
    }
    CGRect b = CGRectInset(self.bounds, 1, 1.5f);
    LRDrawInsetWell(ctx, b, b.size.height / 2, [UIColor colorWithWhite:0.10f alpha:1],
                    [UIColor colorWithWhite:0.22f alpha:1], 1);
    CGFloat lampW = 14, lampH = 6;
    CGFloat lx = _on ? b.origin.x + 9 : CGRectGetMaxX(b) - 9 - lampW;
    CGRect lamp = CGRectMake(lx, CGRectGetMidY(b) - lampH / 2, lampW, lampH);
    CGContextSaveGState(ctx);
    if (_on) {
        CGContextSetShadowWithColor(ctx, CGSizeZero, 6, SKIN->ledGreen.CGColor);
        [LRColorMix(SKIN->ledGreen, [UIColor whiteColor], 0.3f) setFill];
    } else {
        [[UIColor colorWithRed:0.30f green:0.09f blue:0.07f alpha:1] setFill];
    }
    LRAddRoundRect(ctx, lamp, 3);
    CGContextFillPath(ctx);
    CGContextRestoreGState(ctx);
}

- (void)setOn:(BOOL)on {
    [self setOn:on animated:NO];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _on = on;
    [self setNeedsDisplay];
    if (animated) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.18];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
        [self layoutKnob];
        [UIView commitAnimations];
    } else {
        [self layoutKnob];
    }
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    _dragStartX = [touch locationInView:self].x;
    _dragged = NO;
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    CGFloat dx = [touch locationInView:self].x - _dragStartX;
    if (fabsf(dx) > 6) _dragged = YES;
    if (_dragged) {
        CGFloat h = self.bounds.size.height;
        CGFloat base = _on ? self.bounds.size.width - h : 0;
        CGFloat x = MAX(0, MIN(self.bounds.size.width - h, base + dx));
        _knob.frame = CGRectMake(x, 0, h, h + 2);
    }
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    BOOL target = !_on;
    if (_dragged) target = CGRectGetMidX(_knob.frame) > self.bounds.size.width / 2;
    if (target != _on) {
        [LRSound click];
        [self setOn:target animated:YES];
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    } else {
        [self setOn:_on animated:YES];
    }
}

- (void)cancelTrackingWithEvent:(UIEvent *)event {
    [self setOn:_on animated:YES];
}
@end
