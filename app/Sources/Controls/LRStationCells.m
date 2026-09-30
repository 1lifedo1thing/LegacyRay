#import "LRStationCells.h"
#import "LRModels.h"
#import "LRCatalog.h"

/* room kept at the right of a row for the detail key */
#define LR_INFO_WIDTH 40.0f

@interface LRStationCard : UIView {
@public
    NSString *name, *detail, *country, *pingText;
    UIColor *pingColor;
    BOOL selected, live, pressed, hasInfo;
    CGFloat margin;
    LRPlatePosition position;
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
    CGRect row;
    BOOL white = pressed && !s->flat;
    if (s->flat) {
        row = b;
        [(pressed ? s->groupPressed : s->groupTop) setFill];
        CGContextFillRect(ctx, row);
        [s->separator setFill];
        BOOL last = position == LRPlateBottom || position == LRPlateSingle;
        CGFloat hair = LRHairline();
        CGContextFillRect(ctx, CGRectMake(last ? 0 : 44, b.size.height - hair, b.size.width - (last ? 0 : 44), hair));
    } else {
        row = CGRectMake(margin, 0, b.size.width - margin * 2, b.size.height);
        LRDrawGroupCell(ctx, row, position, pressed, NO);
        BOOL bottom = position == LRPlateBottom || position == LRPlateSingle;
        if (bottom) row.size.height -= 1;
    }
    CGFloat midY = CGRectGetMidY(row);
    CGFloat x = row.origin.x + (s->flat ? 14 : 10);
    if (selected) {
        UIColor *check = white ? [UIColor whiteColor] : (live ? s->good : (s->flat ? s->tint : s->groupDetail));
        LRDrawCheckmark(ctx, CGPointMake(x, midY), check);
    }
    x += 22;
    if ([country length] == 2) LRDrawFlag(ctx, country, CGRectMake(x, roundf(midY - 12), 24, 24));
    CGFloat textX = x + 34;
    CGFloat right = CGRectGetMaxX(row) - (hasInfo ? LR_INFO_WIDTH : 12);
    UIFont *pingFont = [LRSkin bodyFont:14];
    CGFloat pingW = [pingText length] ? MIN([pingText sizeWithFont:pingFont].width, 90) : 0;
    if (pingW > 0) {
        [(white ? [UIColor whiteColor] : pingColor) set];
        [pingText drawInRect:CGRectMake(right - pingW, midY - 9, pingW, 18) withFont:pingFont
               lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentRight];
        pingW += 8;
    }
    CGFloat textW = right - pingW - textX;
    UIFont *nameFont = s->flat ? [LRSkin bodyFont:17] : [LRSkin boldFont:17];
    UIColor *nameInk = white ? [UIColor whiteColor]
        : (selected && !s->flat ? s->groupDetail : s->groupInk);
    [nameInk set];
    [name drawInRect:CGRectMake(textX, midY - 20, textW, 22) withFont:nameFont
       lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentLeft];
    [(white ? [UIColor whiteColor] : s->groupMuted) set];
    [detail drawInRect:CGRectMake(textX, midY + 3, textW, 17) withFont:[LRSkin bodyFont:13]
         lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentLeft];
}
@end

@implementation LRStationCell
@synthesize infoAction = _infoAction;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier])) {
        self.backgroundColor = [UIColor clearColor];
        self.backgroundView = [[[UIView alloc] init] autorelease];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _card = [[LRStationCard alloc] initWithFrame:self.contentView.bounds];
        _card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:_card];
        _info = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        [_info setImage:LRDetailDisclosureImage(NO) forState:UIControlStateNormal];
        [_info setImage:LRDetailDisclosureImage(YES) forState:UIControlStateHighlighted];
        [_info addTarget:self action:@selector(infoTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_info];
    }
    return self;
}

- (void)dealloc {
    [_card release];
    [_info release];
    [_infoAction release];
    [super dealloc];
}

- (void)infoTapped {
    if (_infoAction) _infoAction();
}

- (void)setInfoAction:(void (^)(void))action {
    [_infoAction release];
    _infoAction = [action copy];
    ((LRStationCard *)_card)->hasInfo = action != nil;
    _info.hidden = action == nil;
    [_card setNeedsDisplay];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    LRStationCard *c = (LRStationCard *)_card;
    CGRect b = self.contentView.bounds;
    CGFloat rowRight = b.size.width - c->margin;
    _info.frame = CGRectMake(rowRight - LR_INFO_WIDTH - 2, 0, LR_INFO_WIDTH, b.size.height - 1);
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
          selected:(BOOL)selected live:(BOOL)live margin:(CGFloat)margin position:(LRPlatePosition)position {
    LRStationCard *c = (LRStationCard *)_card;
    LRSkin *s = SKIN;
    LRSetString(&c->name, name);
    NSString *detail = [server protocolSummary];
    if (!server.supported) detail = [detail stringByAppendingFormat:@" · %@", L(@"unsupported")];
    LRSetString(&c->detail, detail);
    LRSetString(&c->country, [server countryCode]);
    NSString *text = nil;
    UIColor *color = s->groupMuted;
    if (ping && [ping intValue] == LR_PING_RUNNING) text = L(@"checking");
    else if (ping && [ping intValue] < 0) { text = L(@"no signal"); color = s->bad; }
    else if (ping) {
        int v = [ping intValue];
        text = [NSString stringWithFormat:@"%d ms", v];
        color = v < 150 ? s->good : (v < 450 ? s->warn : s->bad);
    }
    LRSetString(&c->pingText, text);
    [c->pingColor release];
    c->pingColor = [color retain];
    c->selected = selected;
    c->live = live;
    c->margin = margin;
    c->position = position;
    [c setNeedsDisplay];
    [self setNeedsLayout];
}

- (void)showTitle:(NSString *)title detail:(NSString *)detail selected:(BOOL)selected live:(BOOL)live
           margin:(CGFloat)margin position:(LRPlatePosition)position {
    LRStationCard *c = (LRStationCard *)_card;
    LRSetString(&c->name, title);
    LRSetString(&c->detail, detail);
    LRSetString(&c->country, nil);
    LRSetString(&c->pingText, nil);
    c->selected = selected;
    c->live = live;
    c->margin = margin;
    c->position = position;
    [c setNeedsDisplay];
    [self setNeedsLayout];
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
    UIColor *ink = s->groupHeader;
    UIColor *shadow = s->flat ? nil : s->groupHeaderShadow;
    CGFloat midY;
    CGFloat x, right;
    UIFont *tf, *mf;
    NSString *shown = title;
    if (s->flat) {
        [(pressed ? s->groupPressed : s->background) setFill];
        CGContextFillRect(ctx, b);
        [s->separator setFill];
        CGContextFillRect(ctx, CGRectMake(0, b.size.height - LRHairline(), b.size.width, LRHairline()));
        midY = CGRectGetMidY(b);
        x = 16;
        right = b.size.width - 16;
        tf = [LRSkin bodyFont:13];
        mf = [LRSkin bodyFont:12];
        shown = [title uppercaseString];
    } else {
        /* a caption over its group, like any ios 6 section header */
        midY = b.size.height - 16;
        x = margin + 9;
        right = b.size.width - margin - 9;
        tf = [LRSkin boldFont:17];
        mf = [LRSkin bodyFont:14];
        if (pressed) ink = LRColorAlpha(ink, 0.6f);
    }
    if ([country length] == 2) {
        LRDrawFlag(ctx, country, CGRectMake(x, roundf(midY - 8), 16, 16));
        x += 22;
    }
    LRDrawChevron(ctx, CGPointMake(right - 4, midY), 4, !collapsed, ink, s->flat ? 1.6f : 2);
    right -= 16;
    CGFloat metaW = [meta length] ? MIN([meta sizeWithFont:mf].width, (right - x) * 0.45f) : 0;
    if (metaW > 0)
        LRDrawEngraved(meta, CGRectMake(right - metaW, roundf(midY - mf.lineHeight / 2), metaW, mf.lineHeight),
                       mf, NSTextAlignmentRight, ink, shadow, 1);
    CGFloat titleW = right - (metaW > 0 ? metaW + 8 : 0) - x;
    LRDrawEngraved(shown, CGRectMake(x, roundf(midY - tf.lineHeight / 2), titleW, tf.lineHeight), tf,
                   NSTextAlignmentLeft, ink, shadow, 1);
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
