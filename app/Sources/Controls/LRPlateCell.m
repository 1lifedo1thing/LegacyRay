#import "LRPlateCell.h"
#import "LRDraw.h"

CGFloat LRPlateMargin(CGFloat width) {
    if (SKIN->flat) return 0;
    /* the insets of ios 6 grouped tables: phone, form sheet, full ipad */
    return width >= 700 ? 45 : (width >= 480 ? 30 : 10);
}

@implementation LRRow
@synthesize kind = _kind, style = _style, title = _title, detail = _detail, subtitle = _subtitle,
            flagCode = _flagCode, icon = _icon, detailColor = _detailColor, on = _on,
            enabled = _enabled, chevron = _chevron, monospace = _monospace, action = _action,
            changed = _changed, userInfo = _userInfo;

- (id)init {
    if ((self = [super init])) _enabled = YES;
    return self;
}

- (void)dealloc {
    [_title release];
    [_detail release];
    [_subtitle release];
    [_flagCode release];
    [_icon release];
    [_detailColor release];
    [_action release];
    [_changed release];
    [_userInfo release];
    [super dealloc];
}

+ (LRRow *)value:(NSString *)title detail:(NSString *)detail
          action:(void (^)(LRRow *, UIView *))action {
    LRRow *r = [[[LRRow alloc] init] autorelease];
    r.kind = LRRowValue;
    r.title = title;
    r.detail = detail;
    r.action = action;
    r.chevron = action != nil;
    return r;
}

+ (LRRow *)toggle:(NSString *)title on:(BOOL)on changed:(void (^)(BOOL))changed {
    LRRow *r = [[[LRRow alloc] init] autorelease];
    r.kind = LRRowSwitch;
    r.title = title;
    r.on = on;
    r.changed = changed;
    return r;
}

+ (LRRow *)button:(NSString *)title style:(LRRowStyle)style action:(void (^)(LRRow *, UIView *))action {
    LRRow *r = [[[LRRow alloc] init] autorelease];
    r.kind = LRRowButton;
    r.title = title;
    r.style = style;
    r.action = action;
    return r;
}

+ (LRRow *)text:(NSString *)text {
    LRRow *r = [[[LRRow alloc] init] autorelease];
    r.kind = LRRowText;
    r.title = text;
    return r;
}

+ (LRRow *)check:(NSString *)title on:(BOOL)on action:(void (^)(LRRow *, UIView *))action {
    LRRow *r = [[[LRRow alloc] init] autorelease];
    r.kind = LRRowCheck;
    r.title = title;
    r.on = on;
    r.action = action;
    return r;
}
@end

#pragma mark plate background

@interface LRPlateBackground : UIView {
@public
    LRPlatePosition position;
    CGFloat margin;
    BOOL pressed;
}
@end

@implementation LRPlateBackground

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)drawFlat:(CGContextRef)ctx {
    LRSkin *s = SKIN;
    CGRect b = self.bounds;
    [(pressed ? s->groupPressed : s->groupTop) setFill];
    CGContextFillRect(ctx, b);
    CGFloat hair = LRHairline();
    [s->separator setFill];
    if (position == LRPlateSingle || position == LRPlateTop)
        CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, hair));
    if (position == LRPlateSingle || position == LRPlateBottom)
        CGContextFillRect(ctx, CGRectMake(0, b.size.height - hair, b.size.width, hair));
    else
        CGContextFillRect(ctx, CGRectMake(15, b.size.height - hair, b.size.width - 15, hair));
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (SKIN->flat) {
        [self drawFlat:ctx];
        return;
    }
    CGRect b = self.bounds;
    LRDrawGroupCell(ctx, CGRectMake(margin, 0, b.size.width - margin * 2, b.size.height), position, pressed, NO);
}
@end

#pragma mark decorations

/* chevron, check mark, icon and flag, drawn above the plate */
@interface LRCellDecor : UIView {
@public
    LRRow *row;
    CGRect inner;
    BOOL lit;       /* the row is pressed: white on blue */
}
@end

@implementation LRCellDecor
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)dealloc {
    [row release];
    [super dealloc];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    LRSkin *s = SKIN;
    CGFloat midY = CGRectGetMidY(inner);
    BOOL white = lit && !s->flat;
    if (row.chevron) {
        UIColor *c = white ? [UIColor whiteColor]
            : (s->flat ? [UIColor colorWithWhite:0.78f alpha:1] : [UIColor colorWithWhite:0.55f alpha:1]);
        LRDrawChevron(ctx, CGPointMake(CGRectGetMaxX(inner) - 3, midY), 4.5f, NO, c, s->flat ? 2 : 2.6f);
    }
    if (row.kind == LRRowCheck && row.on)
        LRDrawCheckmark(ctx, CGPointMake(CGRectGetMaxX(inner) - 14, midY),
                        white ? [UIColor whiteColor] : (s->flat ? s->tint : s->groupDetail));
    CGFloat iconY = [row.subtitle length] ? 8 : midY - 12;
    if ([row.flagCode length]) {
        LRDrawFlag(ctx, row.flagCode, CGRectMake(inner.origin.x, iconY + 1, 22, 22));
    } else if (row.icon) {
        [row.icon drawInRect:CGRectMake(inner.origin.x, iconY, 24, 24)];
    }
}
@end

#pragma mark cell

@implementation LRPlateCell
@synthesize row = _row, toggle = _toggle;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier])) {
        self.backgroundColor = [UIColor clearColor];
        LRPlateBackground *bg = [[[LRPlateBackground alloc] initWithFrame:self.bounds] autorelease];
        LRPlateBackground *sel = [[[LRPlateBackground alloc] initWithFrame:self.bounds] autorelease];
        sel->pressed = YES;
        self.backgroundView = bg;
        self.selectedBackgroundView = sel;
        _plate = bg;
        _pressedPlate = sel;
        _title = [[UILabel alloc] init];
        _detail = [[UILabel alloc] init];
        _subtitle = [[UILabel alloc] init];
        for (UILabel *l in [NSArray arrayWithObjects:_title, _detail, _subtitle, nil]) {
            l.backgroundColor = [UIColor clearColor];
            l.highlightedTextColor = nil;
            [self.contentView addSubview:l];
        }
        _detail.textAlignment = NSTextAlignmentRight;
        _decor = [[LRCellDecor alloc] initWithFrame:self.bounds];
        [self.contentView addSubview:_decor];
        _toggle = [[LRToggleSwitch alloc] initWithFrame:CGRectZero];
        [_toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_toggle];
    }
    return self;
}

- (void)dealloc {
    [_decor release];
    [_row release];
    [_title release];
    [_detail release];
    [_subtitle release];
    [_toggle release];
    [super dealloc];
}

- (void)toggled:(LRToggleSwitch *)t {
    _row.on = t.on;
    if (_row.changed) _row.changed(t.on);
}

static UIFont *LRRowTitleFont(LRRow *row) {
    if (row.kind == LRRowText) return [LRSkin bodyFont:SKIN->flat ? 14 : 15];
    if (SKIN->flat) return [LRSkin bodyFont:17];
    return [LRSkin boldFont:17];
}

/* a long value gives way to the title a little earlier on the phone */
static UIFont *LRRowDetailFont(LRRow *row) {
    if (row.monospace) return [LRSkin monoFont:13];
    return [LRSkin bodyFont:SKIN->flat ? 17 : 16];
}

+ (CGFloat)heightForRow:(LRRow *)row width:(CGFloat)width margin:(CGFloat)margin {
    CGFloat inner = width - margin * 2 - (SKIN->flat ? 30 : 20);
    if (row.kind == LRRowText) {
        CGSize s = [row.title sizeWithFont:LRRowTitleFont(row) constrainedToSize:CGSizeMake(inner, 4000)
                             lineBreakMode:NSLineBreakByWordWrapping];
        return MAX(44.0f, ceilf(s.height) + 22);
    }
    CGFloat h = 44;
    if ([row.subtitle length]) {
        CGSize s = [row.subtitle sizeWithFont:[LRSkin bodyFont:SKIN->flat ? 12 : 13] constrainedToSize:CGSizeMake(inner, 400)
                                lineBreakMode:NSLineBreakByWordWrapping];
        h = MAX(h, 32 + ceilf(s.height) + 8);
    }
    return h;
}

- (void)configure:(LRRow *)row position:(LRPlatePosition)position margin:(CGFloat)margin {
    [_row release];
    _row = [row retain];
    _position = position;
    _margin = margin;
    LRSkin *s = SKIN;
    ((LRPlateBackground *)_plate)->position = position;
    ((LRPlateBackground *)_plate)->margin = margin;
    ((LRPlateBackground *)_pressedPlate)->position = position;
    ((LRPlateBackground *)_pressedPlate)->margin = margin;
    [_plate setNeedsDisplay];
    [_pressedPlate setNeedsDisplay];

    _title.text = row.title;
    _title.font = LRRowTitleFont(row);
    _title.numberOfLines = row.kind == LRRowText ? 0 : 1;
    /* a long title (russian runs long) gives up a few points before it is cut */
    _title.adjustsFontSizeToFitWidth = row.kind != LRRowText;
    _title.minimumFontSize = 13;
    _title.lineBreakMode = row.kind == LRRowText ? NSLineBreakByWordWrapping : NSLineBreakByTruncatingTail;
    UIColor *titleColor = s->groupInk;
    if (row.style == LRRowStyleAccent) titleColor = s->flat ? s->tint : s->groupDetail;
    else if (row.style == LRRowStyleDestructive) titleColor = s->bad;
    else if (row.style == LRRowStyleMuted) titleColor = s->groupMuted;
    else if (row.kind == LRRowCheck && row.on && !s->flat) titleColor = s->groupDetail;
    else if (row.kind == LRRowText && !s->flat) titleColor = s->groupHeader;
    if (!row.enabled) titleColor = LRColorAlpha(titleColor, 0.4f);
    _title.textColor = titleColor;
    _title.textAlignment = row.kind == LRRowButton ? NSTextAlignmentCenter : NSTextAlignmentLeft;
    _title.shadowColor = nil;

    _detail.text = row.detail;
    _detail.font = LRRowDetailFont(row);
    _detail.textColor = row.detailColor ? row.detailColor : (s->flat ? s->groupMuted : s->groupDetail);
    _detail.hidden = row.kind != LRRowValue || ![row.detail length];

    _subtitle.text = row.subtitle;
    _subtitle.font = [LRSkin bodyFont:s->flat ? 12 : 13];
    _subtitle.textColor = s->groupMuted;
    UIColor *lit = s->flat ? nil : [UIColor whiteColor];
    _title.highlightedTextColor = lit;
    _detail.highlightedTextColor = lit;
    _subtitle.highlightedTextColor = lit;
    _subtitle.numberOfLines = 0;
    _subtitle.hidden = ![row.subtitle length];

    _toggle.hidden = row.kind != LRRowSwitch;
    if (row.kind == LRRowSwitch) [_toggle setOn:row.on animated:NO];
    _toggle.enabled = row.enabled;

    BOOL tappable = row.enabled && row.action != nil;
    self.selectionStyle = tappable ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;
    self.accessoryType = UITableViewCellAccessoryNone;
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

/* the decorations turn white with the text while the row is pressed */
- (void)setDecorLit:(BOOL)lit {
    LRCellDecor *decor = (LRCellDecor *)_decor;
    if (decor->lit == lit) return;
    decor->lit = lit;
    [decor setNeedsDisplay];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [self setDecorLit:highlighted || self.selected];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    [self setDecorLit:selected || self.highlighted];
}

/* the text inset: 10 points inside an ios 6 row, 15 from an ios 7 edge */
static CGFloat LRRowPad(void) {
    return SKIN->flat ? 15 : 10;
}

- (CGRect)innerRect {
    CGRect b = self.bounds;
    CGFloat pad = LRRowPad();
    return CGRectMake(_margin + pad, 0, b.size.width - _margin * 2 - pad * 2, b.size.height);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.contentView.frame = self.bounds;
    CGRect in = [self innerRect];
    LRCellDecor *decor = (LRCellDecor *)_decor;
    [decor->row release];
    decor->row = [_row retain];
    decor->inner = in;
    decor.frame = self.contentView.bounds;
    [decor setNeedsDisplay];
    CGFloat right = CGRectGetMaxX(in);
    BOOL chevron = _row.chevron || _row.kind == LRRowCheck;
    if (chevron) right -= 14;
    CGFloat left = in.origin.x;
    if (_row.icon || [_row.flagCode length]) left += 32;
    if (_row.kind == LRRowSwitch) {
        CGSize ts = LR_TOGGLE_SIZE;
        _toggle.frame = CGRectMake(CGRectGetMaxX(in) - ts.width + 4, roundf((in.size.height - ts.height) / 2),
                                   ts.width, ts.height);
        right = _toggle.frame.origin.x - 8;
    }
    if (_row.kind == LRRowText) {
        _title.frame = CGRectInset(in, 0, 10);
        return;
    }
    if (_row.kind == LRRowButton) {
        _title.frame = CGRectMake(in.origin.x, 0, in.size.width, in.size.height);
        return;
    }
    CGFloat titleTop = 0, titleH = in.size.height;
    if (!_subtitle.hidden) {
        titleTop = 8;
        titleH = 22;
        CGSize ss = [_subtitle.text sizeWithFont:_subtitle.font
                               constrainedToSize:CGSizeMake(right - left, 400)
                                   lineBreakMode:NSLineBreakByWordWrapping];
        _subtitle.frame = CGRectMake(left, 31, right - left, ceilf(ss.height));
    }
    CGFloat detailW = 0;
    if (!_detail.hidden) {
        CGFloat want = [_detail.text sizeWithFont:_detail.font].width;
        CGFloat titleW = [_title.text sizeWithFont:_title.font].width;
        detailW = MIN(want, MAX((right - left) * 0.45f, right - left - titleW - 12));
        _detail.frame = CGRectMake(right - detailW, titleTop, detailW, titleH);
    }
    _title.frame = CGRectMake(left, titleTop, right - left - detailW - (detailW > 0 ? 8 : 0), titleH);
}

@end
