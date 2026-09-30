#import "LRToast.h"
#import "LRDraw.h"

static LRToast *gCurrentToast = nil;

@implementation LRToast

- (id)initWithText:(NSString *)text tape:(UIColor *)tape width:(CGFloat)maxWidth {
    BOOL flat = SKIN->flat;
    UIFont *font = flat ? [LRSkin bodyFont:14] : [LRSkin boldFont:15];
    NSString *shown = text;
    CGSize size = [shown sizeWithFont:font constrainedToSize:CGSizeMake(maxWidth - 40, 200)
                        lineBreakMode:NSLineBreakByWordWrapping];
    CGRect frame = CGRectMake(0, 0, MIN(maxWidth, ceilf(size.width) + 40), ceilf(size.height) + (flat ? 18 : 22));
    if ((self = [super initWithFrame:frame])) {
        _text = [shown copy];
        _tape = [tape retain];
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.userInteractionEnabled = YES;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = flat ? 0.15f : 0;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.layer.shadowRadius = 3;
    }
    return self;
}

- (void)dealloc {
    [_text release];
    [_tape release];
    [super dealloc];
}

- (void)drawFlat:(CGContextRef)ctx {
    CGRect b = self.bounds;
    LRAddRoundRect(ctx, b, MIN(14.0f, b.size.height / 2));
    [LRColorAlpha(_tape, 0.92f) setFill];
    CGContextFillPath(ctx);
    [[UIColor whiteColor] set];
    [_text drawInRect:CGRectInset(b, 20, 9) withFont:[LRSkin bodyFont:14]
        lineBreakMode:NSLineBreakByWordWrapping alignment:NSTextAlignmentCenter];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (SKIN->flat) {
        [self drawFlat:ctx];
        return;
    }
    /* the ios 6 hud: a dark translucent rounded panel with a white rim of
       light, white bold text; errors and successes tint it */
    CGRect b = CGRectInset(self.bounds, 0.5f, 0.5f);
    LRAddRoundRect(ctx, b, 10);
    [LRColorAlpha(LRColorMix(_tape, [UIColor blackColor], 0.35f), 0.82f) setFill];
    CGContextFillPath(ctx);
    CGContextSaveGState(ctx);
    LRAddRoundRect(ctx, b, 10);
    CGContextClip(ctx);
    LRFillVertical(ctx, CGRectMake(b.origin.x, b.origin.y, b.size.width, b.size.height / 2),
                   [UIColor colorWithWhite:1 alpha:0.14f], [UIColor colorWithWhite:1 alpha:0.03f]);
    CGContextRestoreGState(ctx);
    LRAddRoundRect(ctx, b, 10);
    CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 0.25f);
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);
    UIFont *font = [LRSkin boldFont:15];
    CGRect tr = CGRectInset(self.bounds, 20, 11);
    [[UIColor colorWithWhite:0 alpha:0.6f] set];
    [_text drawInRect:CGRectOffset(tr, 0, -1) withFont:font lineBreakMode:NSLineBreakByWordWrapping
            alignment:NSTextAlignmentCenter];
    [[UIColor whiteColor] set];
    [_text drawInRect:tr withFont:font lineBreakMode:NSLineBreakByWordWrapping
            alignment:NSTextAlignmentCenter];
}

+ (void)show:(NSString *)text tape:(UIColor *)tape {
    if (![text length]) return;
    UIViewController *top = LRTopViewController();
    UIView *host = top.view;
    if (!host) return;
    if (gCurrentToast) {
        [gCurrentToast removeFromSuperview];
        [gCurrentToast release];
        gCurrentToast = nil;
    }
    CGFloat maxW = MIN(host.bounds.size.width - 24, 480);
    LRToast *toast = [[LRToast alloc] initWithText:text tape:tape width:maxW];
    CGFloat x = roundf((host.bounds.size.width - toast.bounds.size.width) / 2);
    /* below the header, which on ios 7 also holds the status bar */
    CGFloat restY = 50 + LRStatusBarOverlap(host);
    toast.frame = CGRectMake(x, -toast.bounds.size.height - 8, toast.bounds.size.width,
                             toast.bounds.size.height);
    toast.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [host addSubview:toast];
    gCurrentToast = toast;
    LRAnimateIn(0.28, ^{
        CGRect f = toast.frame;
        f.origin.y = restY;
        toast.frame = f;
    });
    NSTimeInterval stay = 2.2 + [text length] / 40.0;
    [UIView animateWithDuration:0.25 delay:stay options:UIViewAnimationOptionCurveEaseIn animations:^{
        CGRect f = toast.frame;
        f.origin.y = -f.size.height - 8;
        toast.frame = f;
    } completion:^(BOOL finished) {
        if (gCurrentToast == toast) {
            [toast removeFromSuperview];
            [gCurrentToast release];
            gCurrentToast = nil;
        }
    }];
}

+ (void)show:(NSString *)text {
    [self show:text tape:[UIColor colorWithRed:0.12f green:0.12f blue:0.13f alpha:1]];
}

+ (void)showError:(NSString *)text {
    [self show:text tape:[UIColor colorWithRed:0.72f green:0.10f blue:0.10f alpha:1]];
}

+ (void)showSuccess:(NSString *)text {
    [self show:text tape:[UIColor colorWithRed:0.10f green:0.45f blue:0.20f alpha:1]];
}
@end
