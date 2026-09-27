#import "LRToast.h"
#import "LRDraw.h"

static LRToast *gCurrentToast = nil;

@implementation LRToast

- (id)initWithText:(NSString *)text tape:(UIColor *)tape width:(CGFloat)maxWidth {
    BOOL flat = SKIN->flat;
    UIFont *font = flat ? [LRSkin bodyFont:14] : [LRSkin boldFont:13];
    NSString *shown = flat ? text : [text uppercaseString];
    CGSize size = [shown sizeWithFont:font constrainedToSize:CGSizeMake(maxWidth - 40, 200)
                        lineBreakMode:NSLineBreakByWordWrapping];
    CGRect frame = CGRectMake(0, 0, MIN(maxWidth, ceilf(size.width) + 40), ceilf(size.height) + 18);
    if ((self = [super initWithFrame:frame])) {
        _text = [shown copy];
        _tape = [tape retain];
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.userInteractionEnabled = YES;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = flat ? 0.15f : 0.5f;
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
    CGRect b = self.bounds;
    /* tape with zig-zag cut ends */
    CGFloat tooth = 3;
    CGContextMoveToPoint(ctx, tooth, 0);
    CGContextAddLineToPoint(ctx, b.size.width - tooth, 0);
    for (CGFloat y = 0; y < b.size.height; y += tooth * 2) {
        CGContextAddLineToPoint(ctx, b.size.width, MIN(b.size.height, y + tooth));
        CGContextAddLineToPoint(ctx, b.size.width - tooth, MIN(b.size.height, y + tooth * 2));
    }
    CGContextAddLineToPoint(ctx, tooth, b.size.height);
    for (CGFloat y = b.size.height; y > 0; y -= tooth * 2) {
        CGContextAddLineToPoint(ctx, 0, MAX(0, y - tooth));
        CGContextAddLineToPoint(ctx, tooth, MAX(0, y - tooth * 2));
    }
    CGContextClosePath(ctx);
    CGContextSaveGState(ctx);
    CGContextClip(ctx);
    LRFillVertical(ctx, b, LRColorMix(_tape, [UIColor whiteColor], 0.18f),
                   LRColorMix(_tape, [UIColor blackColor], 0.2f));
    LRDrawNoise(ctx, b, 0.12f);
    CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.18f);
    CGContextFillRect(ctx, CGRectMake(0, 1, b.size.width, b.size.height * 0.35f));
    CGContextRestoreGState(ctx);
    /* raised letters: dark below, light above, white face */
    UIFont *font = [LRSkin boldFont:13];
    CGRect tr = CGRectInset(b, 20, 9);
    [[UIColor colorWithWhite:0 alpha:0.45f] set];
    [_text drawInRect:CGRectOffset(tr, 0, 1) withFont:font lineBreakMode:NSLineBreakByWordWrapping
            alignment:NSTextAlignmentCenter];
    [[UIColor colorWithWhite:0.93f alpha:1] set];
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
    CGFloat restY = 50;
    toast.frame = CGRectMake(x, -toast.bounds.size.height - 8, toast.bounds.size.width,
                             toast.bounds.size.height);
    toast.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    if (!SKIN->flat) toast.transform = CGAffineTransformMakeRotation(-0.012f);
    [host addSubview:toast];
    gCurrentToast = toast;
    [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect f = toast.frame;
        f.origin.y = restY;
        toast.frame = f;
    } completion:nil];
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
