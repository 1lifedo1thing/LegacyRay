#import "LRMenu.h"
#import "LRDraw.h"
#import "LRButton.h"

@interface LRMenuPanel : UIView {
@public
    CGFloat arrowX;     /* ipad: x of the arrow tip in panel coordinates, <0 none */
    BOOL arrowUp;
    BOOL floating;      /* the ipad popover, not the phone's sheet */
    NSMutableArray *groups;       /* flat skin: white rounded groups */
    NSMutableArray *separators;   /* flat skin: hairlines between rows */
}
@end

@implementation LRMenuPanel
- (void)dealloc {
    [groups release];
    [separators release];
    [super dealloc];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    LRSkin *s = SKIN;
    CGRect b = self.bounds;
    if (s->flat) {
        for (NSValue *v in groups) {
            CGRect g = [v CGRectValue];
            LRAddRoundRect(ctx, g, 12);
            if (arrowX >= 0) {
                CGFloat ay = arrowUp ? g.origin.y : CGRectGetMaxY(g);
                CGFloat tip = arrowUp ? ay - 10 : ay + 10;
                CGContextMoveToPoint(ctx, arrowX - 11, ay);
                CGContextAddLineToPoint(ctx, arrowX, tip);
                CGContextAddLineToPoint(ctx, arrowX + 11, ay);
                CGContextClosePath(ctx);
            }
            [[UIColor colorWithWhite:0.975f alpha:1] setFill];
            CGContextFillPath(ctx);
        }
        [s->separator setFill];
        for (NSValue *v in separators) CGContextFillRect(ctx, [v CGRectValue]);
        return;
    }
    if (!floating) {
        /* the black translucent action sheet */
        CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.78f);
        CGContextFillRect(ctx, b);
        LRFillVertical(ctx, CGRectMake(0, 0, b.size.width, 40), [UIColor colorWithWhite:1 alpha:0.12f],
                       [UIColor colorWithWhite:1 alpha:0]);
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.25f);
        CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
        return;
    }
    /* the ios 6 popover: a dark glassy frame with an arrow, white rows in it */
    CGRect body = b;
    if (arrowX >= 0) {
        if (arrowUp) { body.origin.y += 10; body.size.height -= 10; }
        else body.size.height -= 10;
    }
    CGContextSaveGState(ctx);
    LRAddRoundRect(ctx, body, 10);
    if (arrowX >= 0) {
        CGFloat ay = arrowUp ? body.origin.y + 1 : CGRectGetMaxY(body) - 1;
        CGFloat tip = arrowUp ? ay - 11 : ay + 11;
        CGContextMoveToPoint(ctx, arrowX - 12, ay);
        CGContextAddLineToPoint(ctx, arrowX, tip);
        CGContextAddLineToPoint(ctx, arrowX + 12, ay);
        CGContextClosePath(ctx);
    }
    CGContextClip(ctx);
    LRFillVertical(ctx, b, [UIColor colorWithRed:0.26f green:0.27f blue:0.29f alpha:1],
                   [UIColor colorWithRed:0.08f green:0.09f blue:0.10f alpha:1]);
    LRFillVertical(ctx, CGRectMake(0, body.origin.y, b.size.width, 22), [UIColor colorWithWhite:1 alpha:0.14f],
                   [UIColor colorWithWhite:1 alpha:0.03f]);
    CGContextRestoreGState(ctx);
    for (NSValue *v in groups) {
        CGRect g = [v CGRectValue];
        CGContextSaveGState(ctx);
        LRAddRoundRect(ctx, g, 5);
        [[UIColor whiteColor] setFill];
        CGContextFillPath(ctx);
        CGContextRestoreGState(ctx);
    }
    [s->groupLine setFill];
    for (NSValue *v in separators) CGContextFillRect(ctx, [v CGRectValue]);
}
@end

@implementation LRMenu

+ (LRMenu *)menuWithTitle:(NSString *)title {
    LRMenu *m = [[[LRMenu alloc] initWithFrame:CGRectZero] autorelease];
    m->_title = [title copy];
    return m;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _items = [[NSMutableArray alloc] init];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)dealloc {
    [_title release];
    [_items release];
    [_panel release];
    [_dim release];
    [_anchor release];
    [super dealloc];
}

- (void)addItem:(NSString *)title style:(LRButtonStyle)style action:(void (^)(void))action {
    id block = action ? [[action copy] autorelease] : (id)[NSNull null];
    [_items addObject:[NSDictionary dictionaryWithObjectsAndKeys:title, @"title",
                       [NSNumber numberWithInt:style], @"style", block, @"action", nil]];
}

- (void)addItem:(NSString *)title action:(void (^)(void))action {
    [self addItem:title style:LRButtonMetal action:action];
}

- (void)addDestructiveItem:(NSString *)title action:(void (^)(void))action {
    [self addItem:title style:LRButtonRed action:action];
}

- (NSUInteger)itemCount {
    return [_items count];
}

- (void)itemTapped:(LRButton *)b {
    id action = [[[[_items objectAtIndex:(NSUInteger)b.tag] objectForKey:@"action"] retain] autorelease];
    [self retain];
    [self dismiss];
    if (action != [NSNull null]) ((void (^)(void))action)();
    [self release];
}

- (BOOL)floating {
    return LRIsPad();
}

- (void)buildPanel {
    LRMenuPanel *panel = [[LRMenuPanel alloc] initWithFrame:CGRectZero];
    panel->arrowX = -1;
    panel->floating = [self floating];
    panel.backgroundColor = [UIColor clearColor];
    panel.contentMode = UIViewContentModeRedraw;
    panel.layer.shadowColor = [UIColor blackColor].CGColor;
    panel.layer.shadowOpacity = SKIN->flat ? (LRIsPad() ? 0.2f : 0) : ([self floating] ? 0.5f : 0);
    panel.layer.shadowRadius = 8;
    panel.layer.shadowOffset = CGSizeMake(0, 3);
    _panel = panel;
    LRSkin *s = SKIN;
    BOOL popover = !s->flat && [self floating];
    if ([_title length]) {
        UILabel *t = [[[UILabel alloc] init] autorelease];
        t.tag = 900;
        t.text = _title;
        t.numberOfLines = 2;
        t.font = s->flat ? [LRSkin bodyFont:13] : (popover ? [LRSkin boldFont:15] : [LRSkin bodyFont:14]);
        t.textAlignment = NSTextAlignmentCenter;
        t.backgroundColor = [UIColor clearColor];
        t.textColor = s->flat ? s->groupMuted : (popover ? [UIColor whiteColor] : [UIColor colorWithWhite:0.82f alpha:1]);
        t.shadowColor = s->flat ? nil : [UIColor colorWithWhite:0 alpha:0.6f];
        t.shadowOffset = CGSizeMake(0, -1);
        [_panel addSubview:t];
    }
    NSUInteger i = 0;
    for (NSDictionary *item in _items) {
        LRButtonStyle style = (LRButtonStyle)[[item objectForKey:@"style"] intValue];
        BOOL destructive = style == LRButtonRed;
        LRButtonStyle shown = s->flat ? LRButtonMetal
            : (popover ? LRButtonRow : (destructive ? LRButtonRed : LRButtonAlert));
        LRButton *b = [LRButton buttonWithStyle:shown title:[item objectForKey:@"title"] action:nil];
        b.frame = CGRectMake(0, 0, 100, 44);
        b.titleLabel.font = s->flat ? [LRSkin bodyFont:19] : [LRSkin boldFont:popover ? 17 : 18];
        if (destructive && (s->flat || popover)) [b setTitleColor:s->flat ? s->ledRed : s->bad forState:UIControlStateNormal];
        if (popover) {
            b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            b.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
        }
        b.tag = (NSInteger)i++;
        [b addTarget:self action:@selector(itemTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_panel addSubview:b];
    }
    if (![self floating]) {
        LRButton *cancel = [LRButton buttonWithStyle:s->flat ? LRButtonMetal : LRButtonDark
                                               title:L(@"Cancel") action:nil];
        cancel.frame = CGRectMake(0, 0, 100, 44);
        cancel.titleLabel.font = s->flat ? [LRSkin boldFont:19] : [LRSkin boldFont:18];
        cancel.tag = 901;
        [cancel addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
        [_panel addSubview:cancel];
    }
}

/* the ios 6 popover: a title in the frame, white rows under it */
- (CGFloat)layoutPopoverRows:(CGFloat)width top:(CGFloat)top {
    LRMenuPanel *panel = (LRMenuPanel *)_panel;
    [panel->groups release];
    panel->groups = [[NSMutableArray alloc] init];
    [panel->separators release];
    panel->separators = [[NSMutableArray alloc] init];
    CGFloat frame = 7, y = top + frame;
    CGFloat w = width - frame * 2;
    UILabel *t = (UILabel *)[_panel viewWithTag:900];
    if (t) {
        CGSize ts = [t.text sizeWithFont:t.font constrainedToSize:CGSizeMake(w - 20, 60)];
        t.frame = CGRectMake(frame + 10, y + 2, w - 20, ceilf(ts.height));
        y += ceilf(ts.height) + 12;
    }
    CGFloat groupTop = y;
    BOOL first = YES;
    for (UIView *v in _panel.subviews) {
        if (![v isKindOfClass:[LRButton class]] || v.tag == 901) continue;
        if (!first) [panel->separators addObject:[NSValue valueWithCGRect:CGRectMake(frame, y, w, 1)]];
        v.frame = CGRectMake(frame, y + (first ? 0 : 1), w, first ? 44 : 43);
        y += 44;
        first = NO;
    }
    [panel->groups addObject:[NSValue valueWithCGRect:CGRectMake(frame, groupTop, w, y - groupTop)]];
    return y + frame;
}

/* flat rows: full width, 50 points, hairlines between; the cancel key gets
   a group of its own like the ios 7 action sheet */
- (CGFloat)layoutFlatRows:(CGFloat)width top:(CGFloat)top {
    LRMenuPanel *panel = (LRMenuPanel *)_panel;
    [panel->groups release];
    panel->groups = [[NSMutableArray alloc] init];
    [panel->separators release];
    panel->separators = [[NSMutableArray alloc] init];
    CGFloat inset = [self floating] ? 0 : 8;
    CGFloat w = width - inset * 2, hair = LRHairline();
    CGFloat y = top + ([self floating] ? 0 : 8), groupTop = y;
    UILabel *t = (UILabel *)[_panel viewWithTag:900];
    BOOL first = YES;
    if (t) {
        CGSize ts = [t.text sizeWithFont:t.font constrainedToSize:CGSizeMake(w - 28, 60)];
        t.frame = CGRectMake(inset + 14, y + 12, w - 28, ceilf(ts.height));
        y += ceilf(ts.height) + 24;
        first = NO;
    }
    for (UIView *v in _panel.subviews) {
        if (![v isKindOfClass:[LRButton class]] || v.tag == 901) continue;
        if (!first) [panel->separators addObject:[NSValue valueWithCGRect:CGRectMake(inset, y, w, hair)]];
        v.frame = CGRectMake(inset, y, w, 50);
        y += 50;
        first = NO;
    }
    [panel->groups addObject:[NSValue valueWithCGRect:CGRectMake(inset, groupTop, w, y - groupTop)]];
    UIView *cancel = [_panel viewWithTag:901];
    if (cancel) {
        y += 8;
        cancel.frame = CGRectMake(inset, y, w, 50);
        [panel->groups addObject:[NSValue valueWithCGRect:cancel.frame]];
        y += 50;
    }
    return y + ([self floating] ? 0 : 8);
}

/* lays the rows out for a panel width and returns the height */
- (CGFloat)layoutRows:(CGFloat)width top:(CGFloat)top {
    if (SKIN->flat) return [self layoutFlatRows:width top:top];
    if ([self floating]) return [self layoutPopoverRows:width top:top];
    CGFloat pad = 20, y = top + 16;
    UILabel *t = (UILabel *)[_panel viewWithTag:900];
    if (t) {
        CGSize ts = [t.text sizeWithFont:t.font constrainedToSize:CGSizeMake(width - pad * 2, 60)];
        t.frame = CGRectMake(pad, y, width - pad * 2, ceilf(ts.height));
        y += ceilf(ts.height) + 10;
    }
    for (UIView *v in _panel.subviews) {
        if (![v isKindOfClass:[LRButton class]] || v.tag == 901) continue;
        v.frame = CGRectMake(pad, y, width - pad * 2, 44);
        y += 52;
    }
    UIView *cancel = [_panel viewWithTag:901];
    if (cancel) {
        y += 10;
        cancel.frame = CGRectMake(pad, y, width - pad * 2, 44);
        y += 52;
    }
    return y + 8;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _dim.frame = self.bounds;
    [self placePanel];
}

- (void)placePanel {
    CGRect b = self.bounds;
    LRMenuPanel *panel = (LRMenuPanel *)_panel;
    if (![self floating]) {
        CGFloat w = MIN(b.size.width, 420);
        CGFloat h = [self layoutRows:w top:0];
        panel->arrowX = -1;
        if (SKIN->flat) {
            _panel.frame = CGRectMake(roundf((b.size.width - w) / 2), b.size.height - h, w, h);
            [_panel setNeedsDisplay];
            return;
        }
        _panel.frame = CGRectMake(roundf((b.size.width - w) / 2), b.size.height - h, w, h);
        [_panel setNeedsDisplay];
        return;
    }
    CGFloat w = SKIN->flat ? 290 : 300;
    CGRect a = _anchor ? [self convertRect:_anchor.bounds fromView:_anchor] : CGRectZero;
    BOOL anchored = _anchor && !CGRectIsEmpty(a) && CGRectIntersectsRect(a, b);
    if (!anchored) {
        CGFloat h = [self layoutRows:w top:0];
        panel->arrowX = -1;
        _panel.frame = CGRectMake(roundf((b.size.width - w) / 2), roundf((b.size.height - h) / 2), w, h);
        return;
    }
    BOOL below = CGRectGetMidY(a) < b.size.height / 2;
    CGFloat h = [self layoutRows:w top:below ? 10 : 0] + 10;
    CGFloat x = MIN(MAX(10, CGRectGetMidX(a) - w / 2), b.size.width - w - 10);
    CGFloat y = below ? CGRectGetMaxY(a) + 2 : a.origin.y - h - 2;
    y = MAX(10, MIN(y, b.size.height - h - 10));
    panel->arrowUp = below;
    panel->arrowX = MIN(MAX(24, CGRectGetMidX(a) - x), w - 24);
    _panel.frame = CGRectMake(roundf(x), roundf(y), w, h);
    [_panel setNeedsDisplay];
}

- (void)showFromView:(UIView *)anchor {
    UIViewController *top = LRTopViewController();
    UIView *host = top.view;
    if (!host) return;
    [_anchor release];
    _anchor = [anchor retain];
    self.frame = host.bounds;
    _dim = [[UIView alloc] initWithFrame:self.bounds];
    _dim.backgroundColor = [UIColor colorWithWhite:0 alpha:[self floating] ? 0.12f : 0.45f];
    UITapGestureRecognizer *tap = [[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                           action:@selector(dismiss)] autorelease];
    [_dim addGestureRecognizer:tap];
    [self addSubview:_dim];
    [self buildPanel];
    [self addSubview:_panel];
    [host addSubview:self];
    [self placePanel];
    _dim.alpha = 0;
    CGRect rest = _panel.frame;
    if ([self floating]) {
        _panel.alpha = 0;
        _panel.transform = CGAffineTransformMakeScale(0.92f, 0.92f);
    } else {
        _panel.frame = CGRectOffset(rest, 0, rest.size.height);
    }
    LRAnimateIn(0.22, ^{
        _dim.alpha = 1;
        _panel.alpha = 1;
        _panel.transform = CGAffineTransformIdentity;
        _panel.frame = rest;
    });
}

- (void)dismiss {
    [self retain];
    CGRect gone = CGRectOffset(_panel.frame, 0, [self floating] ? 0 : _panel.frame.size.height);
    [UIView animateWithDuration:0.18 animations:^{
        _dim.alpha = 0;
        if ([self floating]) _panel.alpha = 0;
        else _panel.frame = gone;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        [self release];
    }];
}
@end
