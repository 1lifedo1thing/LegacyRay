#import "LRIndicators.h"
#import "LRDraw.h"
#import "LRCatalog.h"

@implementation LRLEDView
@synthesize color = _color, on = _on;
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        _color = [SKIN->ledGreen retain];
    }
    return self;
}
- (void)dealloc {
    [_color release];
    [super dealloc];
}
- (void)setOn:(BOOL)on { _on = on; [self setNeedsDisplay]; }
- (void)setColor:(UIColor *)color {
    [_color release];
    _color = [color retain];
    [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    CGRect b = self.bounds;
    CGFloat r = MIN(b.size.width, b.size.height) / 2 - 3;
    LRDrawLED(UIGraphicsGetCurrentContext(), CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b)), r,
              _color, _on);
}
@end

@implementation LRSignalBars
@synthesize level = _level, color = _color, busy = _busy;
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}
- (void)dealloc {
    [_color release];
    [super dealloc];
}
- (void)showPing:(NSNumber *)ms {
    LRSkin *s = SKIN;
    [self.layer removeAnimationForKey:@"busy"];
    _busy = NO;
    self.alpha = 1;
    if (!ms) {
        _level = 0;
        self.color = s->cardMuted;
    } else if ([ms intValue] == LR_PING_RUNNING) {
        _level = 5;
        _busy = YES;
        self.color = s->cardMuted;
        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"];
        a.fromValue = [NSNumber numberWithFloat:1];
        a.toValue = [NSNumber numberWithFloat:0.25f];
        a.duration = 0.5;
        a.autoreverses = YES;
        a.repeatCount = HUGE_VALF;
        [self.layer addAnimation:a forKey:@"busy"];
    } else if ([ms intValue] < 0) {
        _level = 0;
        self.color = s->bad;
    } else {
        int v = [ms intValue];
        _level = v < 80 ? 5 : v < 150 ? 4 : v < 250 ? 3 : v < 450 ? 2 : 1;
        self.color = v < 150 ? s->good : (v < 450 ? s->warn : s->bad);
    }
    [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    CGFloat bw = floorf((b.size.width - 4 * 1.5f) / 5);
    for (int i = 0; i < 5; ++i) {
        CGFloat h = b.size.height * (0.28f + 0.18f * i);
        CGRect bar = CGRectMake(i * (bw + 1.5f), b.size.height - h, bw, h);
        UIColor *c = i < _level ? _color : LRColorAlpha(SKIN->cardMuted, 0.25f);
        [c setFill];
        CGContextFillRect(ctx, bar);
    }
}
@end

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
    CGRect b = CGRectInset(self.bounds, 1, 1);
    CGFloat r = b.size.height / 2;
    LRDrawInsetWell(ctx, b, r, [UIColor colorWithWhite:0.12f alpha:1], [UIColor colorWithWhite:0.25f alpha:1], 1);
    if (_fraction > 0) {
        LRSkin *s = SKIN;
        UIColor *liquid = _fraction < 0.75 ? s->ledGreen : (_fraction < 0.92 ? s->ledAmber : s->ledRed);
        CGRect fill = CGRectMake(b.origin.x + 2, b.origin.y + 2, MAX(b.size.height - 4,
                                 (b.size.width - 4) * (CGFloat)MIN(1.0, _fraction)), b.size.height - 4);
        CGContextSaveGState(ctx);
        LRAddRoundRect(ctx, fill, fill.size.height / 2);
        CGContextClip(ctx);
        LRFillVertical(ctx, fill, LRColorMix(liquid, [UIColor whiteColor], 0.35f),
                       LRColorMix(liquid, [UIColor blackColor], 0.25f));
        CGContextRestoreGState(ctx);
    }
    LRDrawGloss(ctx, b, r);
}
@end
