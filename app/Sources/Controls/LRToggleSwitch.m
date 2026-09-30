#import "LRToggleSwitch.h"
#import "LRDraw.h"
#import "LRSound.h"

CGSize LRToggleSwitchSize(void) {
    return SKIN->flat ? CGSizeMake(51, 31) : CGSizeMake(79, 27);
}

static UIColor *RGB(unsigned rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0f green:((rgb >> 8) & 0xff) / 255.0f
                            blue:(rgb & 0xff) / 255.0f alpha:1];
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

/* the classic knob: a pale disc with a darker edge and a little shadow */
static UIImage *LRKnobImage(CGFloat h) {
    static UIImage *cached = nil;
    if (cached && cached.size.height == h + 1) return cached;
    [cached release];
    cached = [LRImageWithSize(CGSizeMake(h, h + 1), NO, ^(CGContextRef ctx, CGRect rect) {
        CGFloat r = h / 2;
        CGRect disc = CGRectMake(0, 0, h, h);
        CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.25f);
        CGContextFillEllipseInRect(ctx, CGRectOffset(disc, 0, 0.5f));
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, CGRectInset(disc, 0.5f, 0.5f));
        CGContextClip(ctx);
        LRFillVertical(ctx, disc, RGB(0xC9C9C9), RGB(0xFDFDFD));
        CGContextRestoreGState(ctx);
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, CGRectInset(disc, 1.5f, 1.5f));
        CGContextClip(ctx);
        LRFillVertical(ctx, disc, RGB(0xFDFDFD), RGB(0xE4E4E4));
        CGContextRestoreGState(ctx);
        CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.35f);
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokeEllipseInRect(ctx, CGRectInset(disc, 0.5f, 0.5f));
        (void)r;
    }) retain];
    return cached;
}

/* the sliding track: blue with ON on the left, grey with OFF on the right,
   (2w - h) wide; the window shows w of it */
static UIImage *LRTrackImage(CGSize size) {
    static UIImage *cached = nil;
    static NSString *cachedLanguage = nil;
    NSString *language = L(@"ON");
    if (cached && [cachedLanguage isEqualToString:language]) return cached;
    [cached release];
    [cachedLanguage release];
    cachedLanguage = [language copy];
    CGFloat w = size.width, h = size.height;
    cached = [LRImageWithSize(CGSizeMake(w * 2 - h, h), YES, ^(CGContextRef ctx, CGRect rect) {
        CGFloat split = w - h / 2;
        LRFillVertical(ctx, CGRectMake(0, 0, split, h), RGB(0x0A5FD1), RGB(0x3C8FF2));
        LRFillVertical(ctx, CGRectMake(split, 0, rect.size.width - split, h), RGB(0xE6E6E6), RGB(0xFDFDFD));
        NSString *on = L(@"ON"), *off = L(@"OFF");
        /* "ВЫКЛ" is wider than "OFF": the words shrink until both fit */
        UIFont *font = [LRSkin boldFont:16];
        for (CGFloat size = 16; size > 10; size -= 1) {
            font = [LRSkin boldFont:size];
            if ([on sizeWithFont:font].width <= w - h - 8 && [off sizeWithFont:font].width <= w - h - 8) break;
        }
        CGFloat onW = MIN([on sizeWithFont:font].width, w - h - 6);
        CGFloat offW = MIN([off sizeWithFont:font].width, w - h - 6);
        CGFloat ty = roundf((h - font.lineHeight) / 2);
        CGRect onRect = CGRectMake(roundf((w - h - onW) / 2), ty, onW, font.lineHeight);
        [[UIColor colorWithWhite:0 alpha:0.3f] set];
        [on drawInRect:CGRectOffset(onRect, 0, -1) withFont:font lineBreakMode:NSLineBreakByClipping
             alignment:NSTextAlignmentCenter];
        [[UIColor whiteColor] set];
        [on drawInRect:onRect withFont:font lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
        CGRect offRect = CGRectMake(roundf(w + (w - h - offW) / 2), ty, offW, font.lineHeight);
        [RGB(0x7F7F7F) set];
        [off drawInRect:offRect withFont:font lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
    }) retain];
    return cached;
}

/* the rim over the window: an inner shadow along the top and a dark edge */
static UIImage *LRRimImage(CGSize size) {
    static UIImage *cached = nil;
    if (cached) return cached;
    CGFloat w = size.width, h = size.height;
    cached = [LRImageWithSize(size, NO, ^(CGContextRef ctx, CGRect rect) {
        CGContextSaveGState(ctx);
        LRAddRoundRect(ctx, rect, h / 2);
        CGContextClip(ctx);
        LRFillVertical(ctx, CGRectMake(0, 0, w, 6), [UIColor colorWithWhite:0 alpha:0.28f],
                       [UIColor colorWithWhite:0 alpha:0]);
        CGContextRestoreGState(ctx);
        LRAddRoundRect(ctx, CGRectInset(rect, 0.5f, 0.5f), h / 2 - 0.5f);
        CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.33f);
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokePath(ctx);
    }) retain];
    return cached;
}

- (id)initWithFrame:(CGRect)frame {
    frame.size = LR_TOGGLE_SIZE;
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        CGSize size = frame.size;
        if (!SKIN->flat) {
            _clip = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
            _clip.userInteractionEnabled = NO;
            _clip.clipsToBounds = YES;
            _clip.layer.cornerRadius = size.height / 2;
            /* a rounded clip renders off screen; cached as a bitmap it costs
               nothing while a table of switches scrolls */
            _clip.layer.shouldRasterize = YES;
            _clip.layer.rasterizationScale = LRScreenScale();
            [self addSubview:_clip];
            _track = [[UIImageView alloc] initWithImage:LRTrackImage(size)];
            [_clip addSubview:_track];
            _rim = [[UIImageView alloc] initWithImage:LRRimImage(size)];
            _rim.userInteractionEnabled = NO;
            [self addSubview:_rim];
        }
        _knob = [[UIImageView alloc] initWithImage:SKIN->flat ? LRFlatKnobImage(size.height)
                                                              : LRKnobImage(size.height)];
        _knob.userInteractionEnabled = NO;
        [self addSubview:_knob];
        [self layoutKnob];
    }
    return self;
}

- (void)dealloc {
    [_knob release];
    [_clip release];
    [_track release];
    [_rim release];
    [super dealloc];
}

- (void)placeKnobAt:(CGFloat)x {
    CGFloat h = self.bounds.size.height;
    _knob.frame = CGRectMake(x, 0, h, _knob.image.size.height);
    /* the track follows the knob: at x = 0 the OFF half shows */
    CGFloat w = self.bounds.size.width;
    _track.frame = CGRectMake(x - (w - h), 0, w * 2 - h, h);
}

- (void)layoutKnob {
    CGFloat h = self.bounds.size.height;
    [self placeKnobAt:_on ? self.bounds.size.width - h : 0];
}

- (void)drawRect:(CGRect)rect {
    if (!SKIN->flat) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
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

- (void)setOn:(BOOL)on {
    [self setOn:on animated:NO];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _on = on;
    if (SKIN->flat) [self setNeedsDisplay];
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

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    self.alpha = enabled ? 1 : 0.5f;
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
        [self placeKnobAt:MAX(0, MIN(self.bounds.size.width - h, base + dx))];
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
