#import "LRVUMeter.h"
#import "LRDraw.h"

#define LR_VU_A0 (-140.0 * M_PI / 180.0)
#define LR_VU_A1 (-40.0 * M_PI / 180.0)

@implementation LRVUMeter
@synthesize caption = _caption;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        self.userInteractionEnabled = NO;
        _well = [[UIView alloc] init];
        _well.clipsToBounds = YES;
        _well.backgroundColor = [UIColor clearColor];
        [self addSubview:_well];
        _needleShadow = [[CALayer layer] retain];
        _needleShadow.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2f].CGColor;
        _needleShadow.anchorPoint = CGPointMake(0.5f, 1);
        [_well.layer addSublayer:_needleShadow];
        _needle = [[CALayer layer] retain];
        _needle.backgroundColor = SKIN->meterNeedle.CGColor;
        _needle.anchorPoint = CGPointMake(0.5f, 1);
        [_well.layer addSublayer:_needle];
        _glass = [[UIImageView alloc] init];
        [self addSubview:_glass];
    }
    return self;
}

- (void)dealloc {
    free(_path);
    [_caption release];
    [_well release];
    [_needle release];
    [_needleShadow release];
    [_glass release];
    [super dealloc];
}

- (CGRect)faceRect {
    return CGRectInset(self.bounds, 5, 5);
}

- (void)pivot:(CGPoint *)pivot radius:(CGFloat *)radius inFace:(CGRect)face {
    CGFloat h = face.size.height;
    *pivot = CGPointMake(face.size.width / 2, h * 1.28f);
    *radius = h * 1.06f;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect face = [self faceRect];
    _well.frame = face;
    CGPoint pivot;
    CGFloat R;
    [self pivot:&pivot radius:&R inFace:face];
    CGFloat len = R + 2;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _needle.bounds = CGRectMake(0, 0, 1.6f, len);
    _needle.position = pivot;
    _needleShadow.bounds = CGRectMake(0, 0, 1.6f, len);
    _needleShadow.position = CGPointMake(pivot.x + 1.5f, pivot.y + 2.5f);
    [CATransaction commit];
    [self applyNeedle];
    _glass.frame = face;
    _needleShadow.hidden = SKIN->flat;
    _needle.backgroundColor = SKIN->meterNeedle.CGColor;
    if (SKIN->flat) {
        /* no glass and no pivot strip: the needle just ends at the card edge */
        _glass.image = nil;
        return;
    }
    _glass.image = LRImageWithSize(face.size, NO, ^(CGContextRef ctx, CGRect rect) {
        /* the black strip that hides the pivot */
        CGFloat bar = rect.size.height * 0.11f;
        LRFillVertical(ctx, CGRectMake(0, rect.size.height - bar, rect.size.width, bar),
                       [UIColor colorWithWhite:0.10f alpha:1], [UIColor colorWithWhite:0.22f alpha:1]);
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.12f);
        CGContextFillRect(ctx, CGRectMake(0, rect.size.height - bar, rect.size.width, 1));
        LRDrawGloss(ctx, rect, 4);
    });
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    LRSkin *s = SKIN;
    LRDrawBezel(ctx, self.bounds, 8);
    CGRect face = [self faceRect];
    LRDrawInsetWell(ctx, face, s->flat ? 10 : 4, s->meterTop, s->meterBottom, 0.9f);
    CGContextSaveGState(ctx);
    LRAddRoundRect(ctx, face, 4);
    CGContextClip(ctx);
    /* the lamp behind the scale */
    if (!s->flat)
        LRFillRadial(ctx, CGPointMake(CGRectGetMidX(face), CGRectGetMaxY(face) + face.size.height * 0.05f),
                     4, face.size.height * 1.25f, s->meterLamp, LRColorAlpha(s->meterLamp, 0));
    CGPoint pv;
    CGFloat R;
    [self pivot:&pv radius:&R inFace:face];
    CGPoint pivot = CGPointMake(face.origin.x + pv.x, face.origin.y + pv.y);
    UIFont *small = [LRSkin labelFont:MAX(7.0f, face.size.height * 0.105f)];
    CGContextSetLineWidth(ctx, 1.1f);
    [s->meterInk setStroke];
    CGContextAddArc(ctx, pivot.x, pivot.y, R, (CGFloat)LR_VU_A0, (CGFloat)LR_VU_A1, 0);
    CGContextStrokePath(ctx);
    [s->meterRed setStroke];
    CGContextSetLineWidth(ctx, 3.2f);
    CGContextAddArc(ctx, pivot.x, pivot.y, R + 2, (CGFloat)(LR_VU_A0 + (LR_VU_A1 - LR_VU_A0) * 0.78),
                    (CGFloat)LR_VU_A1, 0);
    CGContextStrokePath(ctx);
    NSArray *labels = [NSArray arrayWithObjects:@"1K", @"10K", @"100K", @"1M", @"10M", nil];
    for (int i = 0; i <= 20; ++i) {
        double f = i / 20.0;
        CGFloat a = (CGFloat)(LR_VU_A0 + (LR_VU_A1 - LR_VU_A0) * f);
        BOOL major = i % 5 == 0;
        CGFloat l = major ? 7 : 4;
        UIColor *ink = f > 0.78 ? s->meterRed : s->meterInk;
        [ink setStroke];
        CGContextSetLineWidth(ctx, major ? 1.4f : 0.9f);
        CGContextMoveToPoint(ctx, pivot.x + cosf(a) * R, pivot.y + sinf(a) * R);
        CGContextAddLineToPoint(ctx, pivot.x + cosf(a) * (R - l), pivot.y + sinf(a) * (R - l));
        CGContextStrokePath(ctx);
        if (major) {
            NSString *t = [labels objectAtIndex:i / 5];
            CGSize ts = [t sizeWithFont:small];
            CGFloat lr = R - l - ts.height * 0.9f;
            CGPoint p = CGPointMake(pivot.x + cosf(a) * lr - ts.width / 2,
                                    pivot.y + sinf(a) * lr - ts.height / 2);
            [ink set];
            [t drawAtPoint:p withFont:small];
        }
    }
    UIFont *vu = s->flat ? [LRSkin lightFont:face.size.height * 0.17f]
                         : [LRSkin titleFont:face.size.height * 0.17f];
    [s->meterInk set];
    NSString *mark = @"VU";
    CGSize vs = [mark sizeWithFont:vu];
    [mark drawAtPoint:CGPointMake(CGRectGetMidX(face) - vs.width / 2, face.origin.y + face.size.height * 0.46f)
             withFont:vu];
    if ([_caption length]) {
        UIFont *cf = [LRSkin labelFont:MAX(6.5f, face.size.height * 0.085f)];
        CGSize cs = [_caption sizeWithFont:cf];
        [_caption drawAtPoint:CGPointMake(CGRectGetMidX(face) - cs.width / 2,
                                          face.origin.y + face.size.height * 0.66f) withFont:cf];
    }
    CGContextRestoreGState(ctx);
}

- (void)setCaption:(NSString *)caption {
    [_caption release];
    _caption = [caption copy];
    [self setNeedsDisplay];
}

static CATransform3D LRNeedleTransform(double value) {
    double angle = LR_VU_A0 + (LR_VU_A1 - LR_VU_A0) * value;
    return CATransform3DMakeRotation((CGFloat)(angle + M_PI_2), 0, 0, 1);
}

- (void)applyNeedle {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [_needle removeAnimationForKey:@"swing"];
    [_needleShadow removeAnimationForKey:@"swing"];
    _needle.transform = LRNeedleTransform(_value);
    _needleShadow.transform = LRNeedleTransform(_value);
    [CATransaction commit];
}

#define LR_VU_FPS 60.0

/* the position and speed of the swing in flight, so a new reading picks the
   needle up where it is instead of snapping it to rest first */
- (void)currentValue:(double *)value velocity:(double *)velocity {
    *value = _value;
    *velocity = 0;
    if (!_path || !_pathLen) return;
    double t = CACurrentMediaTime() - _pathStart;
    NSUInteger i = t <= 0 ? 0 : (NSUInteger)(t * LR_VU_FPS);
    if (i >= _pathLen) return;
    *value = _path[2 * i];
    *velocity = _path[2 * i + 1];
}

- (void)setValue:(double)value animated:(BOOL)animated {
    double target = MAX(0.0, MIN(1.0, value));
    if (fabs(target - _target) < 0.002 && (animated || fabs(target - _value) < 0.002)) return;
    _target = target;
    if (!animated || !self.window) {
        free(_path);
        _path = NULL;
        _pathLen = 0;
        _value = target;
        [self applyNeedle];
        return;
    }

/* the damped spring the needle always had, integrated once up front. core
   animation then plays the frames in the render server, and the app itself
   sleeps through the swing instead of stepping it thirty times a second */
    double x = 0, v = 0;
    [self currentValue:&x velocity:&v];
    const double dt = 1.0 / LR_VU_FPS, k = 60.0, damping = 9.0;
    NSUInteger cap = (NSUInteger)(LR_VU_FPS * 2.5);
    double *path = (double *)malloc(sizeof(double) * 2 * cap);
    if (!path) { _value = target; [self applyNeedle]; return; }
    NSMutableArray *frames = [NSMutableArray arrayWithCapacity:cap];
    NSUInteger n = 0;
    while (n < cap) {
        double accel = k * (target - x) - damping * v;
        v += accel * dt;
        x += v * dt;
        if (x < -0.02) { x = -0.02; v = 0; }
        if (x > 1.03) { x = 1.03; v = 0; }
        path[2 * n] = x;
        path[2 * n + 1] = v;
        [frames addObject:[NSValue valueWithCATransform3D:LRNeedleTransform(x)]];
        n++;
        if (fabs(target - x) < 0.002 && fabs(v) < 0.01) break;
    }
    free(_path);
    _path = path;
    _pathLen = n;
    _pathStart = CACurrentMediaTime();
    _value = target;

    CAKeyframeAnimation *swing = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    swing.values = frames;
    swing.duration = n * dt;
    swing.calculationMode = kCAAnimationLinear;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _needle.transform = LRNeedleTransform(target);
    _needleShadow.transform = LRNeedleTransform(target);
    [_needle addAnimation:swing forKey:@"swing"];
    [_needleShadow addAnimation:swing forKey:@"swing"];
    [CATransaction commit];
}

- (void)setSpeed:(double)bps {
    double v = bps <= 1000.0 ? 0.0 : (log10(bps) - 3.0) / 4.0;
    [self setValue:v animated:YES];
}
@end
