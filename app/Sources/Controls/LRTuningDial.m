#import "LRTuningDial.h"
#import "LRDraw.h"
#import "LRSound.h"

@implementation LRTuningDial
@synthesize labels = _labels, selectedIndex = _selectedIndex;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _selectedIndex = -1;
        _pointer = [[CALayer layer] retain];
        BOOL flat = SKIN->flat;
        _pointer.backgroundColor = (flat ? SKIN->tint
            : [UIColor colorWithRed:1 green:0.25f blue:0.15f alpha:1]).CGColor;
        _pointer.shadowColor = [UIColor colorWithRed:1 green:0.2f blue:0.1f alpha:1].CGColor;
        _pointer.shadowOpacity = flat ? 0 : 0.9f;
        _pointer.shadowRadius = 4;
        _pointer.shadowOffset = CGSizeZero;
        [self.layer addSublayer:_pointer];
    }
    return self;
}

- (void)dealloc {
    [_labels release];
    [_pointer release];
    [_background release];
    [super dealloc];
}

- (CGRect)glassRect {
    return CGRectInset(self.bounds, 5, 5);
}

- (CGFloat)xForIndex:(NSInteger)i {
    CGRect g = CGRectInset([self glassRect], 14, 0);
    NSUInteger n = MAX((NSUInteger)1, [_labels count]);
    return g.origin.x + g.size.width * ((CGFloat)i + 0.5f) / n;
}

- (NSInteger)indexForX:(CGFloat)x {
    CGRect g = CGRectInset([self glassRect], 14, 0);
    NSUInteger n = [_labels count];
    if (!n) return -1;
    NSInteger i = (NSInteger)floorf((x - g.origin.x) / g.size.width * n);
    return MAX(0, MIN((NSInteger)n - 1, i));
}

- (void)setLabels:(NSArray *)labels {
    if ([labels isEqualToArray:_labels]) return;
    [_labels release];
    _labels = [labels copy];
    [_background release];
    _background = nil;
    [self setNeedsDisplay];
    [self placePointerAnimated:NO];
}

- (void)setSelectedIndex:(NSInteger)index {
    [self setSelectedIndex:index animated:NO];
}

- (void)setSelectedIndex:(NSInteger)index animated:(BOOL)animated {
    _selectedIndex = index;
    [self placePointerAnimated:animated];
    [self setNeedsDisplay];
}

- (void)placePointerAnimated:(BOOL)animated {
    CGRect g = [self glassRect];
    BOOL show = _selectedIndex >= 0 && _selectedIndex < (NSInteger)[_labels count];
    [CATransaction begin];
    [CATransaction setDisableActions:!animated];
    [CATransaction setAnimationDuration:0.35];
    _pointer.hidden = !show;
    _pointer.bounds = CGRectMake(0, 0, 2, g.size.height - 6);
    if (show) _pointer.position = CGPointMake([self xForIndex:_selectedIndex], CGRectGetMidY(g));
    [CATransaction commit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [_background release];
    _background = nil;
    [self placePointerAnimated:NO];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    LRSkin *s = SKIN;
    CGRect g = [self glassRect];
    LRDrawBezel(ctx, self.bounds, 8);
    BOOL flat = s->flat;
    if (flat)
        LRDrawInsetWell(ctx, g, 10, [UIColor whiteColor], [UIColor whiteColor], 1);
    else
        LRDrawInsetWell(ctx, g, 4, [UIColor colorWithRed:0.05f green:0.07f blue:0.08f alpha:1],
                        [UIColor colorWithRed:0.02f green:0.03f blue:0.04f alpha:1], 1);
    CGContextSaveGState(ctx);
    LRAddRoundRect(ctx, g, flat ? 10 : 4);
    CGContextClip(ctx);
    UIColor *ink = flat ? s->groupMuted : s->glow;
    if (!flat) {
        CGFloat locs[3] = { 0, 0.5f, 1 };
        LRFillLinear(ctx, g.origin, CGPointMake(CGRectGetMaxX(g), g.origin.y),
                     [NSArray arrayWithObjects:LRColorAlpha(s->glow, 0), LRColorAlpha(s->glow, 0.13f),
                      LRColorAlpha(s->glow, 0), nil], locs);
    }
    /* fine scale */
    CGRect scale = CGRectInset(g, 14, 0);
    int ticks = 60;
    for (int i = 0; i <= ticks; ++i) {
        CGFloat x = scale.origin.x + scale.size.width * i / ticks;
        BOOL tall = i % 5 == 0;
        [LRColorAlpha(ink, tall ? 0.55f : 0.28f) setFill];
        CGFloat h = tall ? 10 : 5;
        CGContextFillRect(ctx, CGRectMake(roundf(x), CGRectGetMaxY(g) - 5 - h, 1, h));
    }
    UIFont *font = [LRSkin boldFont:9];
    NSUInteger n = [_labels count];
    CGFloat slot = scale.size.width / MAX((NSUInteger)1, n);
    for (NSUInteger i = 0; i < n; ++i) {
        NSString *t = [_labels objectAtIndex:i];
        CGFloat x = [self xForIndex:(NSInteger)i];
        CGRect lr = CGRectMake(x - slot / 2, g.origin.y + 5, slot, 12);
        BOOL sel = (NSInteger)i == _selectedIndex;
        if (sel) LRDrawGlowText(ctx, t, lr, font, s->glow, NSTextAlignmentCenter, 3);
        else if (slot >= 18) {
            [LRColorAlpha(ink, flat ? 0.9f : 0.55f) set];
            [t drawInRect:lr withFont:font lineBreakMode:NSLineBreakByClipping
                alignment:NSTextAlignmentCenter];
        }
    }
    if (!n) {
        [LRColorAlpha(ink, 0.4f) set];
        [L(@"NO STATIONS") drawInRect:CGRectMake(g.origin.x, g.origin.y + 5, g.size.width, 12)
                             withFont:font lineBreakMode:NSLineBreakByClipping
                            alignment:NSTextAlignmentCenter];
    }
    CGContextRestoreGState(ctx);
    LRDrawGloss(ctx, g, 4);
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    if (![_labels count]) return NO;
    _trackingIndex = [self indexForX:[touch locationInView:self].x];
    [self setSelectedIndex:_trackingIndex animated:YES];
    [LRSound tick];
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    NSInteger i = [self indexForX:[touch locationInView:self].x];
    if (i != _trackingIndex) {
        _trackingIndex = i;
        [self setSelectedIndex:i animated:YES];
        [LRSound tick];
    }
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
@end
