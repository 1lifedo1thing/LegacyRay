#import "LRDisplayView.h"
#import "LRDraw.h"

@implementation LRDisplayView
@synthesize status = _status, station = _station, countryCode = _countryCode, detail = _detail,
            message = _message, seconds = _seconds, upText = _upText, downText = _downText,
            legends = _legends, litLegends = _litLegends, compact = _compact;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        self.opaque = NO;
    }
    return self;
}

- (void)dealloc {
    [_status release];
    [_station release];
    [_countryCode release];
    [_detail release];
    [_message release];
    [_upText release];
    [_downText release];
    [_legends release];
    [_litLegends release];
    [_glass release];
    [super dealloc];
}

#define LR_DISPLAY_SETTER(Name, ivar) \
- (void)Name:(NSString *)v { \
    if (v == ivar || [v isEqualToString:ivar]) return; \
    [ivar release]; ivar = [v copy]; [self setNeedsDisplay]; \
}
LR_DISPLAY_SETTER(setStatus, _status)
LR_DISPLAY_SETTER(setStation, _station)
LR_DISPLAY_SETTER(setCountryCode, _countryCode)
LR_DISPLAY_SETTER(setDetail, _detail)
LR_DISPLAY_SETTER(setMessage, _message)
LR_DISPLAY_SETTER(setUpText, _upText)
LR_DISPLAY_SETTER(setDownText, _downText)

- (void)setSeconds:(long)s {
    if (s == _seconds) return;
    _seconds = s;
    [self setNeedsDisplay];
}

- (void)setLitLegends:(NSSet *)lit {
    if ([lit isEqualToSet:_litLegends]) return;
    [_litLegends release];
    _litLegends = [lit retain];
    [self setNeedsDisplay];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.85f : 1;
}

- (CGRect)glassRect {
    return CGRectInset(self.bounds, 6, 6);
}

/* bezel, glass, scanlines and backlight bloom: static, drawn once per size */
- (UIImage *)glassImage {
    CGSize size = self.bounds.size;
    if (_glass && CGSizeEqualToSize(_glass.size, size)) return _glass;
    [_glass release];
    CGRect g = [self glassRect];
    _glass = [LRImageWithSize(size, NO, ^(CGContextRef ctx, CGRect rect) {
        LRSkin *s = SKIN;
        LRDrawBezel(ctx, rect, 11);
        LRDrawInsetWell(ctx, g, s->flat ? 12 : 6, s->glassTop, s->glassBottom, 1);
        if (s->flat) return;
        CGContextSaveGState(ctx);
        LRAddRoundRect(ctx, g, 6);
        CGContextClip(ctx);
        CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.22f);
        for (CGFloat y = g.origin.y; y < CGRectGetMaxY(g); y += 3)
            CGContextFillRect(ctx, CGRectMake(g.origin.x, y, g.size.width, 1));
        LRFillRadial(ctx, CGPointMake(CGRectGetMidX(g), CGRectGetMidY(g)), 4, g.size.width * 0.7f,
                     LRColorAlpha(s->glow, 0.10f), LRColorAlpha(s->glow, 0));
        CGContextRestoreGState(ctx);
    }) retain];
    return _glass;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    LRSkin *s = SKIN;
    [[self glassImage] drawAtPoint:CGPointZero];
    CGRect g = CGRectInset([self glassRect], 12, 8);
    UIColor *glow = s->glow;
    BOOL flat = s->flat;
    /* the flat card reads like an ios 7 widget: tint headline, black station,
       grey details, thin black clock */
    UIColor *stationColor = flat ? s->groupInk : glow;
    UIColor *detailColor = flat ? s->groupMuted : LRColorAlpha(glow, 0.8f);
    UIColor *clockColor = flat ? s->groupInk : LRColorMix(glow, [UIColor whiteColor], 0.12f);
    UIColor *trafficColor = flat ? s->groupMuted : glow;
    CGFloat scale = self.compact ? 0.9f : 1.0f;
    /* headline and legends */
    UIFont *head = [LRSkin boldFont:13 * scale];
    LRDrawGlowText(ctx, _status, CGRectMake(g.origin.x, g.origin.y, g.size.width * 0.5f, 18), head, glow,
                   NSTextAlignmentLeft, 4);
    UIFont *legendFont = [LRSkin boldFont:8.5f];
    CGFloat lx = CGRectGetMaxX(g);
    for (NSString *legend in [_legends reverseObjectEnumerator]) {
        CGSize ls = [legend sizeWithFont:legendFont];
        lx -= ls.width;
        BOOL lit = [_litLegends containsObject:legend];
        CGRect lr = CGRectMake(lx, g.origin.y + 3, ls.width, ls.height);
        if (lit) LRDrawGlowText(ctx, legend, lr, legendFont, glow, NSTextAlignmentLeft, 3);
        else {
            [(flat ? LRColorAlpha(s->groupMuted, 0.35f) : LRColorAlpha(glow, 0.16f)) set];
            [legend drawInRect:lr withFont:legendFont];
        }
        lx -= 8;
        if (lx < g.origin.x + g.size.width * 0.5f) break;
    }
    /* station */
    CGFloat y = g.origin.y + 22 * scale;
    CGFloat sx = g.origin.x;
    if ([_countryCode length] == 2) {
        CGFloat fs = 16 * scale;
        LRDrawFlag(ctx, _countryCode, CGRectMake(sx, y + 1, fs, fs));
        sx += fs + 7;
    }
    UIFont *stationFont = [LRSkin boldFont:(self.compact ? 15 : 17)];
    LRDrawGlowText(ctx, [_station length] ? _station : @"—",
                   CGRectMake(sx, y, CGRectGetMaxX(g) - sx, 22), stationFont, stationColor,
                   NSTextAlignmentLeft, 5);
    y += 22 * scale;
    UIFont *detailFont = [LRSkin bodyFont:10.5f * scale];
    NSString *line = [_message length] ? _message : _detail;
    UIColor *lineColor = [_message length] ? (flat ? s->bad : LRColorMix(glow, s->ledRed, 0.6f))
                                           : detailColor;
    if ([line length])
        LRDrawGlowText(ctx, line, CGRectMake(g.origin.x, y, g.size.width, 14), detailFont, lineColor,
                       NSTextAlignmentLeft, 2);
    /* clock and totals along the bottom */
    CGFloat digitH = floorf(MIN(34.0f, g.size.height * 0.30f));
    NSString *clock = LRDuration(_seconds);
    if ([clock rangeOfString:@"d"].location != NSNotFound) {
        long h = _seconds / 3600, m = (_seconds / 60) % 60;
        clock = [NSString stringWithFormat:@"%03ld:%02ld", MIN(h, 999L), m];
    }
    if (flat) {
        /* the flat card's clock reads like the ios 7 clock app: thin and large */
        UIFont *thin = [LRSkin thinFont:floorf(digitH * 1.45f)];
        CGSize cs = [clock sizeWithFont:thin];
        [clockColor set];
        [clock drawAtPoint:CGPointMake(g.origin.x - 1, CGRectGetMaxY(g) - cs.height + 2) withFont:thin];
    } else {
        LRDrawSevenSegment(ctx, clock, CGPointMake(g.origin.x, CGRectGetMaxY(g) - digitH - 2), digitH,
                           clockColor, s->glowDim);
    }
    UIFont *traffic = [LRSkin bodyFont:11 * scale];
    CGFloat tw = g.size.width * 0.42f;
    if ([_upText length])
        LRDrawGlowText(ctx, [@"↑ " stringByAppendingString:_upText],
                       CGRectMake(CGRectGetMaxX(g) - tw, CGRectGetMaxY(g) - 30, tw, 14), traffic, trafficColor,
                       NSTextAlignmentRight, 2);
    if ([_downText length])
        LRDrawGlowText(ctx, [@"↓ " stringByAppendingString:_downText],
                       CGRectMake(CGRectGetMaxX(g) - tw, CGRectGetMaxY(g) - 15, tw, 14), traffic, trafficColor,
                       NSTextAlignmentRight, 2);
    LRDrawGloss(ctx, [self glassRect], 6);
}
@end
