#import "LRIndicators.h"
#import "LRDraw.h"

/* the gauge: see the header */
@implementation LRTubeGauge
@synthesize fraction = _fraction;
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}
- (void)setFraction:(double)f { _fraction = f; [self setNeedsDisplay]; }
- (void)drawFlat:(CGContextRef)ctx {
    CGRect b = self.bounds;
    CGFloat h = MIN(b.size.height, 4.0f);
    CGRect track = CGRectMake(0, roundf((b.size.height - h) / 2), b.size.width, h);
    LRAddRoundRect(ctx, track, h / 2);
    [[UIColor colorWithWhite:0.90f alpha:1] setFill];
    CGContextFillPath(ctx);
    if (_fraction > 0) {
        LRSkin *s = SKIN;
        UIColor *c = _fraction < 0.75 ? s->tint : (_fraction < 0.92 ? s->ledAmber : s->ledRed);
        CGRect fill = track;
        fill.size.width = MAX(h, track.size.width * (CGFloat)MIN(1.0, _fraction));
        LRAddRoundRect(ctx, fill, h / 2);
        [c setFill];
        CGContextFillPath(ctx);
    }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (SKIN->flat) {
        [self drawFlat:ctx];
        return;
    }
    CGRect full = self.bounds;
    CGFloat h = MIN(full.size.height, 11.0f);
    CGRect b = CGRectMake(0, roundf((full.size.height - h) / 2), full.size.width, h - 1);
    CGFloat r = b.size.height / 2;
    /* the sunken track, with a white lip under it */
    LRAddRoundRect(ctx, CGRectOffset(b, 0, 1), r);
    CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.8f);
    CGContextFillPath(ctx);
    CGContextSaveGState(ctx);
    LRAddRoundRect(ctx, b, r);
    CGContextClip(ctx);
    LRFillVertical(ctx, b, [UIColor colorWithWhite:0.72f alpha:1], [UIColor colorWithWhite:0.93f alpha:1]);
    CGContextRestoreGState(ctx);
    LRAddRoundRect(ctx, CGRectInset(b, 0.5f, 0.5f), r - 0.5f);
    CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.35f);
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);
    if (_fraction > 0) {
        LRSkin *s = SKIN;
        UIColor *top, *bottom;
        if (_fraction < 0.75) {
            top = [UIColor colorWithRed:0.44f green:0.64f blue:0.93f alpha:1];
            bottom = [UIColor colorWithRed:0.16f green:0.40f blue:0.80f alpha:1];
        } else {
            UIColor *c = _fraction < 0.92 ? s->ledAmber : s->ledRed;
            top = LRColorMix(c, [UIColor whiteColor], 0.3f);
            bottom = LRColorMix(c, [UIColor blackColor], 0.15f);
        }
        CGRect fill = CGRectMake(b.origin.x, b.origin.y, MAX(b.size.height,
                                 b.size.width * (CGFloat)MIN(1.0, _fraction)), b.size.height);
        CGContextSaveGState(ctx);
        LRAddRoundRect(ctx, fill, r);
        CGContextClip(ctx);
        CGFloat locs[4] = { 0, 0.5f, 0.5f, 1 };
        LRFillLinear(ctx, CGPointMake(0, fill.origin.y), CGPointMake(0, CGRectGetMaxY(fill)),
                     [NSArray arrayWithObjects:LRColorMix(top, [UIColor whiteColor], 0.25f), top,
                      LRColorMix(top, bottom, 0.6f), bottom, nil], locs);
        CGContextRestoreGState(ctx);
        LRAddRoundRect(ctx, CGRectInset(fill, 0.5f, 0.5f), r - 0.5f);
        CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.4f);
        CGContextStrokePath(ctx);
    }
}
@end
