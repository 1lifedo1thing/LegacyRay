#import "LRDraw.h"

#pragma mark colors

static void LRRGBA(UIColor *color, CGFloat out[4]) {
    CGColorRef c = color.CGColor;
    size_t n = CGColorGetNumberOfComponents(c);
    const CGFloat *comp = CGColorGetComponents(c);
    if (n == 2) {
        out[0] = out[1] = out[2] = comp[0];
        out[3] = comp[1];
    } else if (n >= 4) {
        out[0] = comp[0]; out[1] = comp[1]; out[2] = comp[2]; out[3] = comp[3];
    } else {
        out[0] = out[1] = out[2] = 0; out[3] = 1;
    }
}

UIColor *LRColorMix(UIColor *a, UIColor *b, CGFloat t) {
    CGFloat x[4], y[4];
    LRRGBA(a, x);
    LRRGBA(b, y);
    return [UIColor colorWithRed:x[0] + (y[0] - x[0]) * t green:x[1] + (y[1] - x[1]) * t
                            blue:x[2] + (y[2] - x[2]) * t alpha:x[3] + (y[3] - x[3]) * t];
}

UIColor *LRColorAlpha(UIColor *c, CGFloat alpha) {
    CGFloat x[4];
    LRRGBA(c, x);
    return [UIColor colorWithRed:x[0] green:x[1] blue:x[2] alpha:alpha];
}

static UIColor *W(CGFloat white, CGFloat alpha) {
    return [UIColor colorWithWhite:white alpha:alpha];
}

#pragma mark paths and fills

void LRAddRoundRect(CGContextRef ctx, CGRect r, CGFloat radius) {
    radius = MIN(radius, MIN(r.size.width, r.size.height) / 2);
    CGFloat minx = CGRectGetMinX(r), midx = CGRectGetMidX(r), maxx = CGRectGetMaxX(r);
    CGFloat miny = CGRectGetMinY(r), midy = CGRectGetMidY(r), maxy = CGRectGetMaxY(r);
    CGContextMoveToPoint(ctx, minx, midy);
    CGContextAddArcToPoint(ctx, minx, miny, midx, miny, radius);
    CGContextAddArcToPoint(ctx, maxx, miny, maxx, midy, radius);
    CGContextAddArcToPoint(ctx, maxx, maxy, midx, maxy, radius);
    CGContextAddArcToPoint(ctx, minx, maxy, minx, midy, radius);
    CGContextClosePath(ctx);
}

CGPathRef LRCreateRoundRectPath(CGRect r, CGFloat radius) {
    radius = MIN(radius, MIN(r.size.width, r.size.height) / 2);
    CGMutablePathRef p = CGPathCreateMutable();
    CGFloat minx = CGRectGetMinX(r), midx = CGRectGetMidX(r), maxx = CGRectGetMaxX(r);
    CGFloat miny = CGRectGetMinY(r), midy = CGRectGetMidY(r), maxy = CGRectGetMaxY(r);
    CGPathMoveToPoint(p, NULL, minx, midy);
    CGPathAddArcToPoint(p, NULL, minx, miny, midx, miny, radius);
    CGPathAddArcToPoint(p, NULL, maxx, miny, maxx, midy, radius);
    CGPathAddArcToPoint(p, NULL, maxx, maxy, midx, maxy, radius);
    CGPathAddArcToPoint(p, NULL, minx, maxy, minx, midy, radius);
    CGPathCloseSubpath(p);
    return p;
}

static CGGradientRef LRCreateGradient(NSArray *colors, const CGFloat *locations) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    NSMutableArray *cg = [NSMutableArray arrayWithCapacity:[colors count]];
    for (UIColor *c in colors) {
        CGFloat v[4];
        LRRGBA(c, v);
        CGColorRef rgb = CGColorCreate(space, v);
        [cg addObject:(id)rgb];
        CGColorRelease(rgb);
    }
    CGGradientRef g = CGGradientCreateWithColors(space, (CFArrayRef)cg, locations);
    CGColorSpaceRelease(space);
    return g;
}

void LRFillLinear(CGContextRef ctx, CGPoint start, CGPoint end, NSArray *colors,
                  const CGFloat *locations) {
    CGGradientRef g = LRCreateGradient(colors, locations);
    CGContextDrawLinearGradient(ctx, g, start, end,
                                kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(g);
}

void LRFillVertical(CGContextRef ctx, CGRect r, UIColor *top, UIColor *bottom) {
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, r);
    LRFillLinear(ctx, CGPointMake(0, CGRectGetMinY(r)), CGPointMake(0, CGRectGetMaxY(r)),
                 [NSArray arrayWithObjects:top, bottom, nil], NULL);
    CGContextRestoreGState(ctx);
}

void LRFillRadial(CGContextRef ctx, CGPoint center, CGFloat r0, CGFloat r1,
                  UIColor *inner, UIColor *outer) {
    CGGradientRef g = LRCreateGradient([NSArray arrayWithObjects:inner, outer, nil], NULL);
    CGContextDrawRadialGradient(ctx, g, center, r0, center, r1, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(g);
}

#pragma mark textures

static NSMutableDictionary *gCache = nil;

static id LRCached(NSString *key) {
    return [gCache objectForKey:key];
}

static void LRCache(NSString *key, id value) {
    if (!gCache) gCache = [[NSMutableDictionary alloc] init];
    if (value) [gCache setObject:value forKey:key];
}

void LRFlushSkinCaches(void) {
    /* tiles do not depend on the skin; everything sized does */
    NSMutableArray *drop = [NSMutableArray array];
    for (NSString *key in gCache)
        if (![key hasPrefix:@"tile."]) [drop addObject:key];
    [gCache removeObjectsForKeys:drop];
}

UIImage *LRDenimTile(void) {
    /* imageNamed picks denim@2x.png on a retina screen and keeps it cached */
    return [UIImage imageNamed:@"denim.png"];
}

void LRDrawDenim(CGContextRef ctx, CGRect r, CGFloat shade) {
    CGContextSaveGState(ctx);
    UIImage *tile = LRDenimTile();
    /* a pattern colour keeps the twill the right way up; CGContextDrawTiledImage
       would draw it flipped in a UIKit context */
    [(tile ? [UIColor colorWithPatternImage:tile] : W(0.10f, 1)) setFill];
    CGContextFillRect(ctx, r);
    if (shade > 0) {
        CGContextSetRGBFillColor(ctx, 0, 0, 0, shade);
        CGContextFillRect(ctx, r);
    }
    CGContextRestoreGState(ctx);
}

UIColor *LRDenimPageColor(void) {
    UIColor *c = LRCached(@"tile.denim.page");
    if (c) return c;
    UIImage *tile = LRDenimTile();
    if (!tile) return W(0.08f, 1);
    UIImage *shaded = LRImageWithSize(tile.size, YES, ^(CGContextRef ctx, CGRect rect) {
        LRDrawDenim(ctx, rect, 0.18f);
    });
    c = [UIColor colorWithPatternImage:shaded];
    LRCache(@"tile.denim.page", c);
    return c;
}

UIImage *LRVignetteImage(void) {
    UIImage *img = LRCached(@"tile.vignette");
    if (img) return img;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(256, 256), NO, 1);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat locs[3] = { 0, 0.45f, 1 };
    CGGradientRef g = LRCreateGradient([NSArray arrayWithObjects:W(1, 0.06f), W(0, 0), W(0, 0.55f), nil], locs);
    CGContextDrawRadialGradient(ctx, g, CGPointMake(128, 128), 0, CGPointMake(128, 128), 128,
                                kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(g);
    img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    LRCache(@"tile.vignette", img);
    return img;
}

UIColor *LRPinstripeColor(void) {
    UIColor *c = LRCached(@"tile.pinstripe");
    if (c) return c;
    /* five points of the base grey and two of a lighter one, repeated */
    UIImage *tile = LRImageWithSize(CGSizeMake(7, 1), YES, ^(CGContextRef ctx, CGRect rect) {
        CGContextSetRGBFillColor(ctx, 0xC5 / 255.0f, 0xCC / 255.0f, 0xD4 / 255.0f, 1);
        CGContextFillRect(ctx, rect);
        CGContextSetRGBFillColor(ctx, 0xCB / 255.0f, 0xD2 / 255.0f, 0xD8 / 255.0f, 1);
        CGContextFillRect(ctx, CGRectMake(5, 0, 2, 1));
    });
    c = [UIColor colorWithPatternImage:tile];
    LRCache(@"tile.pinstripe", c);
    return c;
}

#pragma mark thread

/* the shadow pass sits 0.8 lower and a little wider, like the holes the
   needle left; then the thread itself */
static void LRStitchPasses(CGContextRef ctx, void (^path)(CGFloat dy), CGFloat on, CGFloat off) {
    if (SKIN->flat) return;
    CGFloat dash[2] = { on, off };
    for (int pass = 0; pass < 2; ++pass) {
        CGContextSaveGState(ctx);
        CGContextSetLineDash(ctx, 0, dash, 2);
        CGContextSetLineCap(ctx, kCGLineCapButt);
        if (pass == 0) {
            CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.55f);
            CGContextSetLineWidth(ctx, 1.9f);
        } else {
            [SKIN->stitch setStroke];
            CGContextSetLineWidth(ctx, 1.3f);
        }
        CGContextBeginPath(ctx);
        path(pass == 0 ? 0.8f : 0);
        CGContextStrokePath(ctx);
        CGContextRestoreGState(ctx);
    }
}

void LRDrawStitchLine(CGContextRef ctx, CGPoint a, CGPoint b) {
    LRStitchPasses(ctx, ^(CGFloat dy) {
        CGContextMoveToPoint(ctx, a.x, a.y + dy);
        CGContextAddLineToPoint(ctx, b.x, b.y + dy);
    }, 4.0f, 2.5f);
}

void LRDrawStitchCircle(CGContextRef ctx, CGPoint c, CGFloat radius) {
    /* a whole number of stitches round the circle, so the seam closes */
    CGFloat circ = (CGFloat)M_PI * 2 * radius;
    CGFloat n = MAX(8.0f, roundf(circ / 6.5f));
    CGFloat on = circ / n * 0.64f, off = circ / n - on;
    LRStitchPasses(ctx, ^(CGFloat dy) {
        CGContextAddEllipseInRect(ctx, CGRectMake(c.x - radius, c.y - radius + dy, radius * 2, radius * 2));
    }, on, off);
}

void LRDrawStitchRoundRect(CGContextRef ctx, CGRect r, CGFloat radius) {
    LRStitchPasses(ctx, ^(CGFloat dy) {
        LRAddRoundRect(ctx, CGRectOffset(r, 0, dy), radius);
    }, 4.0f, 2.5f);
}

#pragma mark chrome

void LRDrawBar(CGContextRef ctx, CGRect r) {
    LRSkin *s = SKIN;
    if (s->flat) {
        CGContextSetRGBFillColor(ctx, 0.97f, 0.97f, 0.97f, 1);
        CGContextFillRect(ctx, r);
        [s->separator setFill];
        CGContextFillRect(ctx, CGRectMake(r.origin.x, CGRectGetMaxY(r) - LRHairline(), r.size.width, LRHairline()));
        return;
    }
    LRDrawDenim(ctx, r, 0);
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, r);
    CGFloat locs[4] = { 0, 0.5f, 0.5f, 1 };
    LRFillLinear(ctx, CGPointMake(0, CGRectGetMinY(r)), CGPointMake(0, CGRectGetMaxY(r)),
                 [NSArray arrayWithObjects:W(1, 0.13f), W(1, 0.05f), W(1, 0), W(0, 0.12f), nil], locs);
    CGContextRestoreGState(ctx);
    CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.16f);
    CGContextFillRect(ctx, CGRectMake(r.origin.x, r.origin.y, r.size.width, 1));
    CGFloat seam = CGRectGetMaxY(r) - 4.5f;
    LRDrawStitchLine(ctx, CGPointMake(r.origin.x, seam), CGPointMake(CGRectGetMaxX(r), seam));
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.85f);
    CGContextFillRect(ctx, CGRectMake(r.origin.x, CGRectGetMaxY(r) - 1, r.size.width, 1));
}

#pragma mark grouped rows

void LRAddCellPath(CGContextRef ctx, CGRect r, LRPlatePosition position, CGFloat radius) {
    BOOL top = position == LRPlateSingle || position == LRPlateTop;
    BOOL bottom = position == LRPlateSingle || position == LRPlateBottom;
    CGFloat minx = CGRectGetMinX(r), maxx = CGRectGetMaxX(r), midx = CGRectGetMidX(r);
    CGFloat miny = CGRectGetMinY(r), maxy = CGRectGetMaxY(r);
    radius = MIN(radius, r.size.height / 2);
    CGContextMoveToPoint(ctx, minx, top ? miny + radius : miny);
    if (top) {
        CGContextAddArcToPoint(ctx, minx, miny, midx, miny, radius);
        CGContextAddArcToPoint(ctx, maxx, miny, maxx, miny + radius, radius);
    } else {
        CGContextAddLineToPoint(ctx, maxx, miny);
    }
    if (bottom) {
        CGContextAddArcToPoint(ctx, maxx, maxy, midx, maxy, radius);
        CGContextAddArcToPoint(ctx, minx, maxy, minx, maxy - radius, radius);
    } else {
        CGContextAddLineToPoint(ctx, maxx, maxy);
        CGContextAddLineToPoint(ctx, minx, maxy);
    }
    CGContextClosePath(ctx);
}

/* the grey rim: the sides always, the top on a first row, the bottom on a
   last one; rows in between are divided by a lighter line */
static void LRAddCellRim(CGContextRef ctx, CGRect r, LRPlatePosition position, CGFloat radius) {
    CGFloat minx = CGRectGetMinX(r), maxx = CGRectGetMaxX(r), midx = CGRectGetMidX(r);
    CGFloat miny = CGRectGetMinY(r), maxy = CGRectGetMaxY(r);
    radius = MIN(radius, r.size.height / 2);
    switch (position) {
        case LRPlateSingle:
            LRAddRoundRect(ctx, r, radius);
            break;
        case LRPlateTop:
            CGContextMoveToPoint(ctx, minx, maxy);
            CGContextAddArcToPoint(ctx, minx, miny, midx, miny, radius);
            CGContextAddArcToPoint(ctx, maxx, miny, maxx, maxy, radius);
            CGContextAddLineToPoint(ctx, maxx, maxy);
            break;
        case LRPlateMiddle:
            CGContextMoveToPoint(ctx, minx, miny);
            CGContextAddLineToPoint(ctx, minx, maxy);
            CGContextMoveToPoint(ctx, maxx, miny);
            CGContextAddLineToPoint(ctx, maxx, maxy);
            break;
        case LRPlateBottom:
            CGContextMoveToPoint(ctx, minx, miny);
            CGContextAddArcToPoint(ctx, minx, maxy, midx, maxy, radius);
            CGContextAddArcToPoint(ctx, maxx, maxy, maxx, miny, radius);
            CGContextAddLineToPoint(ctx, maxx, miny);
            break;
    }
}

void LRDrawGroupCell(CGContextRef ctx, CGRect r, LRPlatePosition position, BOOL pressed, BOOL onDark) {
    LRSkin *s = SKIN;
    const CGFloat radius = 10;
    BOOL bottom = position == LRPlateSingle || position == LRPlateBottom;
    CGContextSaveGState(ctx);
    if (bottom && !onDark) {
        /* the white lip the last row leaves on the pinstripes */
        LRAddCellPath(ctx, CGRectOffset(CGRectMake(r.origin.x, r.origin.y, r.size.width, r.size.height - 1), 0, 1),
                      position, radius);
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.8f);
        CGContextFillPath(ctx);
    }
    CGRect body = r;
    if (bottom) body.size.height -= 1;
    CGContextSaveGState(ctx);
    LRAddCellPath(ctx, body, position, radius);
    CGContextClip(ctx);
    if (pressed) LRFillVertical(ctx, body, s->groupPressed, s->groupPressedBottom);
    else if (onDark) LRFillVertical(ctx, body, W(0.992f, 1), W(0.929f, 1));
    else LRFillVertical(ctx, body, s->groupTop, s->groupBottom);
    if (!bottom && !pressed) {
        [s->groupLine setFill];
        CGContextFillRect(ctx, CGRectMake(body.origin.x, CGRectGetMaxY(body) - 1, body.size.width, 1));
    }
    CGContextRestoreGState(ctx);
    CGContextBeginPath(ctx);
    LRAddCellRim(ctx, CGRectInset(body, 0.5f, position == LRPlateMiddle ? 0 : 0.5f), position, radius - 0.5f);
    if (onDark) CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.75f);
    else [s->groupEdge setStroke];
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
}

void LRDrawChevron(CGContextRef ctx, CGPoint c, CGFloat size, BOOL down, UIColor *color, CGFloat width) {
    CGContextSaveGState(ctx);
    [color setStroke];
    CGContextSetLineWidth(ctx, width);
    CGContextSetLineCap(ctx, kCGLineCapSquare);
    CGContextSetLineJoin(ctx, kCGLineJoinMiter);
    if (down) {
        CGContextMoveToPoint(ctx, c.x - size, c.y - size * 0.5f);
        CGContextAddLineToPoint(ctx, c.x, c.y + size * 0.5f);
        CGContextAddLineToPoint(ctx, c.x + size, c.y - size * 0.5f);
    } else {
        CGContextMoveToPoint(ctx, c.x - size * 0.5f, c.y - size);
        CGContextAddLineToPoint(ctx, c.x + size * 0.5f, c.y);
        CGContextAddLineToPoint(ctx, c.x - size * 0.5f, c.y + size);
    }
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
}

void LRDrawCheckmark(CGContextRef ctx, CGPoint p, UIColor *color) {
    CGContextSaveGState(ctx);
    [color setStroke];
    CGContextSetLineWidth(ctx, SKIN->flat ? 2 : 2.8f);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGContextMoveToPoint(ctx, p.x, p.y);
    CGContextAddLineToPoint(ctx, p.x + 4.5f, p.y + 5);
    CGContextAddLineToPoint(ctx, p.x + 13, p.y - 7);
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
}

UIImage *LRDetailDisclosureImage(BOOL pressed) {
    NSString *key = [NSString stringWithFormat:@"disclosure.%d.%d", pressed, SKIN->flat];
    UIImage *img = LRCached(key);
    if (img) return img;
    BOOL flat = SKIN->flat;
    UIColor *tint = SKIN->tint;
    img = LRImageWithSize(CGSizeMake(29, 29), NO, ^(CGContextRef ctx, CGRect rect) {
        CGPoint c = CGPointMake(14.5f, 14.5f);
        CGFloat r = 10.5f;
        CGRect disc = CGRectMake(c.x - r, c.y - r, r * 2, r * 2);
        if (flat) {
            /* the ios 7 (i): a thin ring and a letter */
            [(pressed ? LRColorAlpha(tint, 0.3f) : tint) setStroke];
            CGContextSetLineWidth(ctx, 1);
            CGContextStrokeEllipseInRect(ctx, CGRectInset(disc, 0.5f, 0.5f));
            [(pressed ? LRColorAlpha(tint, 0.3f) : tint) setFill];
            CGContextFillEllipseInRect(ctx, CGRectMake(c.x - 1.2f, c.y - 6.5f, 2.4f, 2.4f));
            CGContextFillRect(ctx, CGRectMake(c.x - 1, c.y - 2.5f, 2, 8));
            return;
        }
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.9f);
        CGContextFillEllipseInRect(ctx, CGRectOffset(disc, 0, 1));
        CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.35f);
        CGContextFillEllipseInRect(ctx, disc);
        CGRect inner = CGRectInset(disc, 1, 1);
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, inner);
        CGContextClip(ctx);
        CGFloat locs[3] = { 0, 0.5f, 1 };
        NSArray *colors = pressed
            ? [NSArray arrayWithObjects:[UIColor colorWithRed:0.20f green:0.43f blue:0.78f alpha:1],
               [UIColor colorWithRed:0.10f green:0.33f blue:0.70f alpha:1],
               [UIColor colorWithRed:0.05f green:0.24f blue:0.60f alpha:1], nil]
            : [NSArray arrayWithObjects:[UIColor colorWithRed:0.365f green:0.612f blue:0.957f alpha:1],
               [UIColor colorWithRed:0.165f green:0.463f blue:0.890f alpha:1],
               [UIColor colorWithRed:0.078f green:0.349f blue:0.812f alpha:1], nil];
        LRFillLinear(ctx, CGPointMake(0, inner.origin.y), CGPointMake(0, CGRectGetMaxY(inner)), colors, locs);
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.22f);
        CGContextFillEllipseInRect(ctx, CGRectMake(c.x - r * 1.05f, c.y - r * 0.9f - r * 1.05f, r * 2.1f, r * 2.1f));
        CGContextRestoreGState(ctx);
        CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 0.9f);
        CGContextSetLineWidth(ctx, 2);
        CGContextStrokeEllipseInRect(ctx, inner);
        LRDrawChevron(ctx, CGPointMake(c.x + 0.8f, c.y), 3.6f, NO, [UIColor whiteColor], 2.6f);
    });
    LRCache(key, img);
    return img;
}

void LRDrawLED(CGContextRef ctx, CGPoint c, CGFloat r, UIColor *color, BOOL on) {
    CGRect disc = CGRectMake(c.x - r, c.y - r, r * 2, r * 2);
    if (SKIN->flat) {
        [(on ? color : W(0.78f, 1)) setFill];
        CGContextFillEllipseInRect(ctx, disc);
        return;
    }
    CGContextSaveGState(ctx);
    CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.6f);
    CGContextFillEllipseInRect(ctx, CGRectOffset(disc, 0, 0.8f));
    [(on ? color : W(0.72f, 1)) setFill];
    CGContextFillEllipseInRect(ctx, disc);
    CGContextAddEllipseInRect(ctx, disc);
    CGContextClip(ctx);
    LRFillRadial(ctx, CGPointMake(c.x - r * 0.3f, c.y - r * 0.4f), 0, r * 1.2f, W(1, 0.6f), W(1, 0));
    CGContextRestoreGState(ctx);
    CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.3f);
    CGContextSetLineWidth(ctx, 0.8f);
    CGContextStrokeEllipseInRect(ctx, CGRectInset(disc, 0.4f, 0.4f));
}

#pragma mark text

void LRDrawEngraved(NSString *text, CGRect rect, UIFont *font, NSTextAlignment align,
                    UIColor *color, UIColor *shadow, CGFloat dy) {
    if (![text length]) return;
    if (shadow) {
        [shadow set];
        [text drawInRect:CGRectOffset(rect, 0, dy) withFont:font
           lineBreakMode:NSLineBreakByTruncatingTail alignment:align];
    }
    [color set];
    [text drawInRect:rect withFont:font lineBreakMode:NSLineBreakByTruncatingTail alignment:align];
}

#pragma mark flags

UIImage *LRFlagImage(NSString *code) {
    if ([code length] != 2) return nil;
    NSString *key = [@"tile.flag." stringByAppendingString:code];
    UIImage *img = LRCached(key);
    if (img) return img;
    NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"flags/flag-%@.png", [code lowercaseString]]];
    img = [UIImage imageWithContentsOfFile:path];
    if (img) LRCache(key, img);
    return img;
}

void LRDrawFlag(CGContextRef ctx, NSString *code, CGRect disc) {
    UIImage *img = LRFlagImage(code);
    if (SKIN->flat) {
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, disc);
        CGContextClip(ctx);
        if (img) [img drawInRect:disc];
        else { [SKIN->separator setFill]; CGContextFillRect(ctx, disc); }
        CGContextRestoreGState(ctx);
        [W(0, 0.12f) setStroke];
        CGContextSetLineWidth(ctx, LRHairline());
        CGContextStrokeEllipseInRect(ctx, CGRectInset(disc, 0.25f, 0.25f));
        return;
    }
    CGContextSaveGState(ctx);
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.25f);
    CGContextFillEllipseInRect(ctx, CGRectOffset(disc, 0, 0.6f));
    CGContextAddEllipseInRect(ctx, disc);
    CGContextClip(ctx);
    if (img) [img drawInRect:disc];
    else LRFillVertical(ctx, disc, W(0.80f, 1), W(0.62f, 1));
    /* a little glass over the top half */
    LRFillVertical(ctx, CGRectMake(disc.origin.x, disc.origin.y, disc.size.width, disc.size.height / 2),
                   W(1, 0.35f), W(1, 0.06f));
    CGContextRestoreGState(ctx);
    CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.28f);
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokeEllipseInRect(ctx, CGRectInset(disc, 0.5f, 0.5f));
}
