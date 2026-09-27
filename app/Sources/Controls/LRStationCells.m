#import "LRStationCells.h"
#import "LRDraw.h"
#import "LRModels.h"
#import "LRCatalog.h"

@interface LRStationCard : UIView {
@public
    NSString *name, *detail, *country, *pingText;
    UIColor *pingColor;
    NSInteger bars;
    BOOL busy, selected, live, pressed, last;
    CGFloat margin;
}
@end

@implementation LRStationCard
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)dealloc {
    [name release];
    [detail release];
    [country release];
    [pingText release];
    [pingColor release];
    [super dealloc];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    LRSkin *s = SKIN;
    CGRect b = self.bounds;
    CGRect card;
    if (s->flat) {
        card = b;
        [(pressed ? s->groupPressed : s->cardTop) setFill];
        CGContextFillRect(ctx, card);
        [s->separator setFill];
        CGFloat hair = LRHairline();
        CGContextFillRect(ctx, CGRectMake(last ? 0 : 58, b.size.height - hair,
                                          b.size.width - (last ? 0 : 58), hair));
    } else {
        card = CGRectMake(margin, 3, b.size.width - margin * 2, b.size.height - 8);
        LRDrawPaperCard(ctx, card, 5);
        if (pressed) {
            CGContextSaveGState(ctx);
            LRAddRoundRect(ctx, card, 5);
            CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.08f);
            CGContextFillPath(ctx);
            CGContextRestoreGState(ctx);
        }
    }
    CGFloat midY = CGRectGetMidY(card);
    CGFloat x = card.origin.x + (s->flat ? 16 : 12);
    UIColor *ledColor = live ? s->ledGreen : (s->flat ? s->tint : s->ledAmber);
    LRDrawLED(ctx, CGPointMake(x + 4, midY), s->flat ? 4 : 3.5f, ledColor, selected || live);
    x += 16;
    if ([country length] == 2) {
        LRDrawFlag(ctx, country, CGRectMake(x, midY - 18, 20, 20));
    }
    CGFloat textX = x + ([country length] == 2 ? 28 : 0);
    CGFloat right = CGRectGetMaxX(card) - (s->flat ? 16 : 12);
    UIFont *pingFont = [LRSkin bodyFont:s->flat ? 13 : 11];
    CGFloat pingW = [pingText length] ? [pingText sizeWithFont:pingFont].width : 0;
    CGFloat barsW = 26;
    CGFloat textRight = right - MAX(pingW, barsW) - 10;
    UIFont *nameFont = s->flat ? [LRSkin bodyFont:17] : [LRSkin boldFont:15];
    [s->cardInk set];
    [name drawInRect:CGRectMake(textX, midY - (s->flat ? 21 : 19), textRight - textX, 22)
            withFont:nameFont lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentLeft];
    [s->cardMuted set];
    [detail drawInRect:CGRectMake(x, midY + 3, textRight - x, 16) withFont:[LRSkin bodyFont:s->flat ? 12 : 10.5f]
         lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentLeft];
    if ([pingText length]) {
        [pingColor set];
        [pingText drawInRect:CGRectMake(right - pingW, midY - 18, pingW, 16) withFont:pingFont
               lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentRight];
    }
    /* radio style bars */
    CGFloat bx = right - barsW, by = midY + 15;
    for (int i = 0; i < 5; ++i) {
        CGFloat h = 4 + i * 2.2f;
        UIColor *c = i < bars ? pingColor : LRColorAlpha(s->cardMuted, 0.25f);
        if (busy) c = LRColorAlpha(s->cardMuted, 0.25f + 0.12f * i);
        [c setFill];
        CGContextFillRect(ctx, CGRectMake(bx + i * 5.2f, by - h, 3.4f, h));
    }
}
@end

@implementation LRStationCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier])) {
        self.backgroundColor = [UIColor clearColor];
        self.backgroundView = [[[UIView alloc] init] autorelease];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _card = [[LRStationCard alloc] initWithFrame:self.contentView.bounds];
        _card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:_card];
    }
    return self;
}

- (void)dealloc {
    [_card release];
    [super dealloc];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    ((LRStationCard *)_card)->pressed = highlighted;
    [_card setNeedsDisplay];
}

static void LRSetString(NSString **slot, NSString *value) {
    [*slot release];
    *slot = [value copy];
}

- (void)showServer:(LRServer *)server name:(NSString *)name ping:(NSNumber *)ping
          selected:(BOOL)selected live:(BOOL)live margin:(CGFloat)margin last:(BOOL)last {
    LRStationCard *c = (LRStationCard *)_card;
    LRSkin *s = SKIN;
    LRSetString(&c->name, name);
    NSString *detail = [server protocolSummary];
    if (!server.supported) detail = [detail stringByAppendingFormat:@" · %@", L(@"unsupported")];
    LRSetString(&c->detail, detail);
    LRSetString(&c->country, [server countryCode]);
    c->busy = ping && [ping intValue] == LR_PING_RUNNING;
    NSString *text = nil;
    UIColor *color = s->cardMuted;
    NSInteger bars = 0;
    if (c->busy) text = L(@"checking");
    else if (ping && [ping intValue] < 0) { text = L(@"no signal"); color = s->bad; }
    else if (ping) {
        int v = [ping intValue];
        text = [NSString stringWithFormat:@"%d ms", v];
        bars = v < 80 ? 5 : v < 150 ? 4 : v < 250 ? 3 : v < 450 ? 2 : 1;
        color = v < 150 ? s->good : (v < 450 ? s->warn : s->bad);
    }
    LRSetString(&c->pingText, text);
    [c->pingColor release];
    c->pingColor = [color retain];
    c->bars = bars;
    c->selected = selected;
    c->live = live;
    c->margin = margin;
    c->last = last;
    [c setNeedsDisplay];
}

- (void)showTitle:(NSString *)title detail:(NSString *)detail selected:(BOOL)selected live:(BOOL)live
           margin:(CGFloat)margin last:(BOOL)last {
    LRStationCard *c = (LRStationCard *)_card;
    LRSetString(&c->name, title);
    LRSetString(&c->detail, detail);
    LRSetString(&c->country, nil);
    LRSetString(&c->pingText, nil);
    c->bars = 0;
    c->busy = NO;
    c->selected = selected;
    c->live = live;
    c->margin = margin;
    c->last = last;
    [c setNeedsDisplay];
}
@end

@interface LRPlateHeaderView : UIView {
@public
    NSString *title, *country, *meta;
    BOOL collapsed, pressed;
    CGFloat margin;
}
@end

@implementation LRPlateHeaderView
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)dealloc {
    [title release];
    [country release];
    [meta release];
    [super dealloc];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    LRSkin *s = SKIN;
    CGRect b = self.bounds;
    CGRect plate;
    UIColor *ink;
    if (s->flat) {
        plate = CGRectMake(0, 0, b.size.width, b.size.height);
        [(pressed ? s->groupPressed : s->background) setFill];
        CGContextFillRect(ctx, plate);
        [s->separator setFill];
        CGContextFillRect(ctx, CGRectMake(0, b.size.height - LRHairline(), b.size.width, LRHairline()));
        ink = s->groupHeader;
    } else {
        plate = CGRectMake(margin, 8, b.size.width - margin * 2, b.size.height - 12);
        LRDrawBrassPlate(ctx, plate, 4);
        if (pressed) {
            CGContextSaveGState(ctx);
            LRAddRoundRect(ctx, plate, 4);
            CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.12f);
            CGContextFillPath(ctx);
            CGContextRestoreGState(ctx);
        }
        ink = s->brassInk;
    }
    CGFloat midY = CGRectGetMidY(plate);
    CGFloat x = plate.origin.x + (s->flat ? 16 : 20);
    if ([country length] == 2) {
        LRDrawFlag(ctx, country, CGRectMake(x, midY - 8, 16, 16));
        x += 22;
    }
    CGFloat right = CGRectGetMaxX(plate) - (s->flat ? 16 : 20);
    LRDrawChevron(ctx, CGPointMake(right - 4, midY), 4, !collapsed, ink, 1.8f);
    right -= 16;
    UIFont *metaFont = [LRSkin bodyFont:s->flat ? 12 : 10];
    CGFloat metaW = [meta length] ? MIN([meta sizeWithFont:metaFont].width, (right - x) * 0.45f) : 0;
    if (metaW > 0) {
        LRDrawEngraved(meta, CGRectMake(right - metaW, midY - 7, metaW, 14), metaFont, NSTextAlignmentRight,
                       ink, s->flat ? nil : s->brassShine, 1);
    }
    NSString *shown = s->flat ? [title uppercaseString] : [title uppercaseString];
    UIFont *tf = s->flat ? [LRSkin bodyFont:13] : [LRSkin labelFont:11];
    CGFloat titleW = right - metaW - 8 - x;
    if (s->flat) {
        LRDrawEngraved(shown, CGRectMake(x, midY - 8, titleW, 16), tf, NSTextAlignmentLeft, ink, nil, 0);
    } else {
        CGFloat tracked = LRTrackedWidth(shown, tf, 1.0f);
        if (tracked <= titleW)
            LRDrawTracked(shown, x, midY - 7, tf, 1.0f, NSTextAlignmentLeft, ink, s->brassShine, 1);
        else
            LRDrawEngraved(shown, CGRectMake(x, midY - 7, titleW, 14), tf, NSTextAlignmentLeft, ink,
                           s->brassShine, 1);
    }
}
@end

@implementation LRPlateHeaderCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier])) {
        self.backgroundColor = [UIColor clearColor];
        self.backgroundView = [[[UIView alloc] init] autorelease];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _plate = [[LRPlateHeaderView alloc] initWithFrame:self.contentView.bounds];
        _plate.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:_plate];
    }
    return self;
}

- (void)dealloc {
    [_plate release];
    [super dealloc];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    ((LRPlateHeaderView *)_plate)->pressed = highlighted;
    [_plate setNeedsDisplay];
}

- (void)showTitle:(NSString *)title country:(NSString *)code meta:(NSString *)meta
        collapsed:(BOOL)collapsed margin:(CGFloat)margin {
    LRPlateHeaderView *p = (LRPlateHeaderView *)_plate;
    [p->title release]; p->title = [title copy];
    [p->country release]; p->country = [code copy];
    [p->meta release]; p->meta = [meta copy];
    p->collapsed = collapsed;
    p->margin = margin;
    [p setNeedsDisplay];
}
@end
