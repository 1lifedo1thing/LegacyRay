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

/* deterministic noise so a texture looks the same every launch */
static unsigned gSeed = 1;
static void LRSeed(unsigned s) { gSeed = s ? s : 1; }
static CGFloat LRRand(void) {
    gSeed = gSeed * 1103515245u + 12345u;
    return (CGFloat)((gSeed >> 8) & 0xffff) / 65535.0f;
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

#pragma mark texture tiles

static NSMutableDictionary *gCache = nil;

/* d(ay) / n(ight) / f(lat): every sized image is keyed by the finish */
static NSString *LRSkinKey(void) {
    return SKIN->flat ? @"f" : (SKIN->night ? @"n" : @"d");
}

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

UIImage *LRNoiseTile(void) {
    UIImage *tile = LRCached(@"tile.noise");
    if (tile) return tile;
    const size_t side = 96;
    unsigned char *px = calloc(side * side * 4, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bm = CGBitmapContextCreate(px, side, side, 8, side * 4, space,
                                            kCGImageAlphaPremultipliedLast);
    LRSeed(97);
    for (size_t i = 0; i < side * side; ++i) {
        CGFloat v = LRRand();
        unsigned char a, c;
        if (v < 0.5f) { c = 0; a = (unsigned char)((0.5f - v) * 2.0f * 255.0f); }
        else { c = 255; a = (unsigned char)((v - 0.5f) * 1.2f * 255.0f); }
        unsigned char pc = (unsigned char)((unsigned)c * a / 255u);
        px[i * 4 + 0] = pc; px[i * 4 + 1] = pc; px[i * 4 + 2] = pc; px[i * 4 + 3] = a;
    }
    CGImageRef img = CGBitmapContextCreateImage(bm);
    tile = [UIImage imageWithCGImage:img];
    CGImageRelease(img);
    CGContextRelease(bm);
    CGColorSpaceRelease(space);
    free(px);
    LRCache(@"tile.noise", tile);
    return tile;
}

void LRDrawNoise(CGContextRef ctx, CGRect r, CGFloat alpha) {
    if (SKIN->flat) return;
    UIImage *tile = LRNoiseTile();
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, r);
    CGContextSetAlpha(ctx, alpha);
    /* tile at device pixel size so the grain stays one pixel fine */
    CGFloat s = 1.0f / LRScreenScale();
    CGContextDrawTiledImage(ctx, CGRectMake(0, 0, 96 * s, 96 * s), tile.CGImage);
    CGContextRestoreGState(ctx);
}

UIImage *LRPebbleTile(void) {
    UIImage *tile = LRCached(@"tile.pebble");
    if (tile) return tile;
    const CGFloat side = 128;
    tile = LRImageWithSize(CGSizeMake(side, side), NO, ^(CGContextRef ctx, CGRect rect) {
        LRSeed(4242);
        for (int i = 0; i < 1100; ++i) {
            CGFloat x = LRRand() * side, y = LRRand() * side;
            CGFloat r = 0.6f + LRRand() * 1.7f;
            BOOL dark = LRRand() < 0.55f;
            CGFloat a = dark ? 0.10f + LRRand() * 0.12f : 0.04f + LRRand() * 0.06f;
            CGContextSetRGBFillColor(ctx, dark ? 0 : 1, dark ? 0 : 1, dark ? 0 : 1, a);
            for (int dx = -1; dx <= 1; ++dx)
                for (int dy = -1; dy <= 1; ++dy)
                    CGContextFillEllipseInRect(ctx, CGRectMake(x - r + dx * side, y - r + dy * side,
                                                               r * 2, r * 1.7f));
        }
        /* a few creases */
        for (int i = 0; i < 26; ++i) {
            CGFloat x = LRRand() * side, y = LRRand() * side;
            CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.10f);
            CGContextSetLineWidth(ctx, 0.6f);
            CGContextMoveToPoint(ctx, x, y);
            CGContextAddQuadCurveToPoint(ctx, x + LRRand() * 8 - 4, y + LRRand() * 6,
                                         x + LRRand() * 14 - 7, y + LRRand() * 10 - 5);
            CGContextStrokePath(ctx);
        }
    });
    LRCache(@"tile.pebble", tile);
    return tile;
}

UIImage *LRLinenTile(void) {
    UIImage *tile = LRCached(@"tile.linen");
    if (tile) return tile;
    const CGFloat side = 64;
    tile = LRImageWithSize(CGSizeMake(side, side), NO, ^(CGContextRef ctx, CGRect rect) {
        LRSeed(1313);
        CGContextSetLineWidth(ctx, 0.5f);
        for (CGFloat y = 0.25f; y < side; y += 1.0f) {
            CGFloat a = 0.03f + LRRand() * 0.09f;
            CGContextSetRGBStrokeColor(ctx, 1, 1, 1, a);
            CGContextMoveToPoint(ctx, 0, y);
            CGContextAddLineToPoint(ctx, side, y);
            CGContextStrokePath(ctx);
        }
        for (CGFloat x = 0.25f; x < side; x += 1.0f) {
            CGFloat a = 0.03f + LRRand() * 0.09f;
            CGContextSetRGBStrokeColor(ctx, 0, 0, 0, a);
            CGContextMoveToPoint(ctx, x, 0);
            CGContextAddLineToPoint(ctx, x, side);
            CGContextStrokePath(ctx);
        }
        for (int i = 0; i < 70; ++i) {
            CGFloat x = LRRand() * side, y = LRRand() * side;
            CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.05f);
            CGContextFillRect(ctx, CGRectMake(x, y, 2 + LRRand() * 5, 0.8f));
        }
    });
    LRCache(@"tile.linen", tile);
    return tile;
}

#pragma mark surfaces

void LRDrawBrushedMetal(CGContextRef ctx, CGRect r, UIColor *top, UIColor *bottom,
                        UIColor *light, UIColor *dark, unsigned seed) {
    if (SKIN->flat) {
        if (top) {
            [top setFill];
            CGContextFillRect(ctx, r);
        }
        return;
    }
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, r);
    if (top && bottom) LRFillVertical(ctx, r, top, bottom);
    CGFloat lc[4], dc[4];
    LRRGBA(light, lc);
    LRRGBA(dark, dc);
    LRSeed(seed);
    CGFloat step = 1.0f / LRScreenScale();
    CGContextSetLineWidth(ctx, step);
    for (CGFloat y = CGRectGetMinY(r); y < CGRectGetMaxY(r); y += step * (1.0f + LRRand() * 1.4f)) {
        BOOL isLight = LRRand() < 0.5f;
        CGFloat *c = isLight ? lc : dc;
        CGContextSetRGBStrokeColor(ctx, c[0], c[1], c[2], c[3] * (0.35f + LRRand() * 0.95f));
        CGFloat x0 = CGRectGetMinX(r) + (LRRand() * 0.4f - 0.1f) * r.size.width;
        CGFloat len = r.size.width * (0.5f + LRRand() * 0.8f);
        CGContextMoveToPoint(ctx, x0, y + step / 2);
        CGContextAddLineToPoint(ctx, x0 + len, y + step / 2);
        CGContextStrokePath(ctx);
    }
    /* a soft diagonal sheen, like light across satin aluminium */
    CGFloat locs[3] = { 0.0f, 0.46f, 0.62f };
    LRFillLinear(ctx, r.origin, CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r)),
                 [NSArray arrayWithObjects:[UIColor colorWithWhite:1 alpha:0],
                  [UIColor colorWithWhite:1 alpha:0.09f], [UIColor colorWithWhite:1 alpha:0], nil],
                 locs);
    CGContextRestoreGState(ctx);
}

UIImage *LRFaceplateImage(CGSize size) {
    NSString *key = [NSString stringWithFormat:@"plate.%@.%.0fx%.0f", LRSkinKey(), size.width, size.height];
    UIImage *img = LRCached(key);
    if (img) return img;
    img = LRImageWithSize(size, YES, ^(CGContextRef ctx, CGRect rect) {
        LRSkin *s = SKIN;
        LRDrawBrushedMetal(ctx, rect, s->plateTop, s->plateBottom, s->hairLight, s->hairDark, 7);
        LRDrawNoise(ctx, rect, 0.10f);
    });
    LRCache(key, img);
    return img;
}

void LRDrawLeather(CGContextRef ctx, CGRect r) {
    LRSkin *s = SKIN;
    if (s->flat) {
        [s->leather setFill];
        CGContextFillRect(ctx, r);
        return;
    }
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, r);
    [s->leatherDark setFill];
    CGContextFillRect(ctx, r);
    LRFillRadial(ctx, CGPointMake(CGRectGetMidX(r), CGRectGetMinY(r) + r.size.height * 0.3f), 10,
                 MAX(r.size.width, r.size.height) * 0.85f, s->leather, s->leatherDark);
    UIImage *tile = LRPebbleTile();
    CGContextDrawTiledImage(ctx, CGRectMake(0, 0, 128, 128), tile.CGImage);
    LRDrawNoise(ctx, r, 0.12f);
    CGContextRestoreGState(ctx);
}

UIImage *LRLeatherImage(CGSize size) {
    NSString *key = [NSString stringWithFormat:@"leather.%@.%.0fx%.0f", LRSkinKey(), size.width, size.height];
    UIImage *img = LRCached(key);
    if (img) return img;
    img = LRImageWithSize(size, YES, ^(CGContextRef ctx, CGRect rect) {
        LRDrawLeather(ctx, rect);
    });
    LRCache(key, img);
    return img;
}

void LRDrawLinen(CGContextRef ctx, CGRect r) {
    LRSkin *s = SKIN;
    if (s->flat) {
        [s->linen setFill];
        CGContextFillRect(ctx, r);
        return;
    }
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, r);
    [s->linen setFill];
    CGContextFillRect(ctx, r);
    CGContextDrawTiledImage(ctx, CGRectMake(0, 0, 64, 64), LRLinenTile().CGImage);
    /* vignette */
    LRFillRadial(ctx, CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r)),
                 MIN(r.size.width, r.size.height) * 0.3f, MAX(r.size.width, r.size.height) * 0.8f,
                 [UIColor colorWithWhite:0 alpha:0], [UIColor colorWithWhite:0 alpha:s->night ? 0.35f : 0.12f]);
    CGContextRestoreGState(ctx);
}

UIImage *LRLinenImage(CGSize size) {
    NSString *key = [NSString stringWithFormat:@"linen.%@.%.0fx%.0f", LRSkinKey(), size.width, size.height];
    UIImage *img = LRCached(key);
    if (img) return img;
    img = LRImageWithSize(size, YES, ^(CGContextRef ctx, CGRect rect) { LRDrawLinen(ctx, rect); });
    LRCache(key, img);
    return img;
}

void LRDrawWalnut(CGContextRef ctx, CGRect r) {
    LRSkin *s = SKIN;
    if (s->flat) {
        [s->background setFill];
        CGContextFillRect(ctx, r);
        return;
    }
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, r);
    LRFillLinear(ctx, r.origin, CGPointMake(CGRectGetMaxX(r), r.origin.y),
                 [NSArray arrayWithObjects:s->walnutDark, s->walnut,
                  LRColorMix(s->walnut, [UIColor blackColor], 0.15f), s->walnutDark, nil], NULL);
    LRSeed(2718);
    for (int i = 0; i < 260; ++i) {
        CGFloat x = CGRectGetMinX(r) + LRRand() * r.size.width;
        CGFloat wob = 3 + LRRand() * 9;
        CGContextSetRGBStrokeColor(ctx, 0.08f, 0.04f, 0.01f, 0.05f + LRRand() * 0.10f);
        CGContextSetLineWidth(ctx, 0.4f + LRRand() * 1.6f);
        CGContextMoveToPoint(ctx, x, CGRectGetMinY(r));
        CGFloat y0 = CGRectGetMinY(r), h = r.size.height;
        CGContextAddCurveToPoint(ctx, x + wob, y0 + h * 0.3f, x - wob, y0 + h * 0.65f,
                                 x + wob * 0.5f, y0 + h);
        CGContextStrokePath(ctx);
    }
    LRDrawNoise(ctx, r, 0.10f);
    CGContextRestoreGState(ctx);
}

void LRDrawStitching(CGContextRef ctx, CGRect r, CGFloat radius, CGFloat inset, UIColor *thread) {
    if (SKIN->flat) return;
    CGRect s = CGRectInset(r, inset, inset);
    CGFloat dash[2] = { 5, 3 };
    CGContextSaveGState(ctx);
    CGContextSetLineDash(ctx, 0, dash, 2);
    LRAddRoundRect(ctx, CGRectOffset(s, 0, 1), radius);
    CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.4f);
    CGContextSetLineWidth(ctx, 2.2f);
    CGContextStrokePath(ctx);
    LRAddRoundRect(ctx, s, radius);
    [thread setStroke];
    CGContextSetLineWidth(ctx, 1.5f);
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
}

#pragma mark hardware

void LRDrawScrew(CGContextRef ctx, CGPoint c, CGFloat r, CGFloat angle) {
    if (SKIN->flat) return;
    CGContextSaveGState(ctx);
    CGRect disc = CGRectMake(c.x - r, c.y - r, r * 2, r * 2);
    /* the countersink */
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.25f);
    CGContextFillEllipseInRect(ctx, CGRectInset(disc, -1, -1));
    CGContextAddEllipseInRect(ctx, disc);
    CGContextClip(ctx);
    LRFillRadial(ctx, CGPointMake(c.x - r * 0.35f, c.y - r * 0.35f), r * 0.1f, r * 1.6f,
                 [UIColor colorWithWhite:0.97f alpha:1], [UIColor colorWithWhite:0.50f alpha:1]);
    CGContextRestoreGState(ctx);
    CGContextSaveGState(ctx);
    CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.5f);
    CGContextSetLineWidth(ctx, 0.7f);
    CGContextStrokeEllipseInRect(ctx, disc);
    CGFloat dx = cosf(angle) * r * 0.72f, dy = sinf(angle) * r * 0.72f;
    CGContextSetLineCap(ctx, kCGLineCapButt);
    CGContextSetLineWidth(ctx, MAX(1.0f, r * 0.34f));
    CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 0.6f);
    CGContextMoveToPoint(ctx, c.x - dx, c.y - dy + 0.6f);
    CGContextAddLineToPoint(ctx, c.x + dx, c.y + dy + 0.6f);
    CGContextStrokePath(ctx);
    CGContextSetRGBStrokeColor(ctx, 0.22f, 0.23f, 0.25f, 0.95f);
    CGContextMoveToPoint(ctx, c.x - dx, c.y - dy);
    CGContextAddLineToPoint(ctx, c.x + dx, c.y + dy);
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
}

void LRDrawInsetWell(CGContextRef ctx, CGRect r, CGFloat radius, UIColor *top, UIColor *bottom,
                     CGFloat depth) {
    if (SKIN->flat) {
        /* a flat well is a filled card with a hairline */
        CGContextSaveGState(ctx);
        LRAddRoundRect(ctx, r, radius);
        [bottom setFill];
        CGContextFillPath(ctx);
        LRAddRoundRect(ctx, CGRectInset(r, 0.25f, 0.25f), radius);
        [SKIN->separator setStroke];
        CGContextSetLineWidth(ctx, LRHairline());
        CGContextStrokePath(ctx);
        CGContextRestoreGState(ctx);
        return;
    }
    CGContextSaveGState(ctx);
    /* light lip below, dark rim around */
    LRAddRoundRect(ctx, CGRectMake(r.origin.x - 1, r.origin.y - 1, r.size.width + 2, r.size.height + 3),
                   radius + 1);
    CGContextSetRGBFillColor(ctx, 1, 1, 1, (SKIN->night ? 0.10f : 0.40f) * depth);
    CGContextFillPath(ctx);
    LRAddRoundRect(ctx, CGRectInset(r, -1, -1), radius + 1);
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.6f * depth);
    CGContextFillPath(ctx);
    LRAddRoundRect(ctx, r, radius);
    CGContextClip(ctx);
    LRFillVertical(ctx, r, top, bottom);
    /* inner shadow along the top edge */
    CGFloat sh = MIN(12.0f, r.size.height * 0.3f);
    LRFillVertical(ctx, CGRectMake(r.origin.x, r.origin.y, r.size.width, sh),
                   [UIColor colorWithWhite:0 alpha:0.55f * depth], [UIColor colorWithWhite:0 alpha:0]);
    CGContextRestoreGState(ctx);
}

void LRDrawBezel(CGContextRef ctx, CGRect r, CGFloat radius) {
    if (SKIN->flat) return;
    CGContextSaveGState(ctx);
    LRAddRoundRect(ctx, CGRectOffset(r, 0, 1), radius);
    CGContextSetRGBFillColor(ctx, 1, 1, 1, SKIN->night ? 0.08f : 0.45f);
    CGContextFillPath(ctx);
    LRAddRoundRect(ctx, r, radius);
    CGContextClip(ctx);
    LRFillVertical(ctx, r, [UIColor colorWithRed:0.10f green:0.10f blue:0.11f alpha:1],
                   [UIColor colorWithRed:0.27f green:0.28f blue:0.30f alpha:1]);
    CGContextRestoreGState(ctx);
}

void LRDrawGloss(CGContextRef ctx, CGRect r, CGFloat radius) {
    if (SKIN->flat) return;
    CGContextSaveGState(ctx);
    LRAddRoundRect(ctx, r, radius);
    CGContextClip(ctx);
    CGFloat x = r.origin.x, y = r.origin.y, w = r.size.width, h = r.size.height;
    CGContextMoveToPoint(ctx, x, y);
    CGContextAddLineToPoint(ctx, x + w, y);
    CGContextAddLineToPoint(ctx, x + w, y + h * 0.20f);
    CGContextAddCurveToPoint(ctx, x + w * 0.62f, y + h * 0.40f, x + w * 0.30f, y + h * 0.30f,
                             x, y + h * 0.46f);
    CGContextClosePath(ctx);
    CGContextClip(ctx);
    LRFillVertical(ctx, CGRectMake(x, y, w, h * 0.5f), [UIColor colorWithWhite:1 alpha:0.16f],
                   [UIColor colorWithWhite:1 alpha:0.02f]);
    CGContextRestoreGState(ctx);
}

void LRDrawLED(CGContextRef ctx, CGPoint c, CGFloat r, UIColor *color, BOOL on) {
    CGRect disc = CGRectMake(c.x - r, c.y - r, r * 2, r * 2);
    if (SKIN->flat) {
        [(on ? color : [UIColor colorWithWhite:0.78f alpha:1]) setFill];
        CGContextFillEllipseInRect(ctx, disc);
        return;
    }
    CGContextSaveGState(ctx);
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.45f);
    CGContextFillEllipseInRect(ctx, CGRectInset(disc, -1.2f, -1.2f));
    if (on) {
        CGContextSetShadowWithColor(ctx, CGSizeZero, r * 2.2f, color.CGColor);
        [color setFill];
        CGContextFillEllipseInRect(ctx, disc);
        CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
        CGContextAddEllipseInRect(ctx, disc);
        CGContextClip(ctx);
        LRFillRadial(ctx, CGPointMake(c.x - r * 0.3f, c.y - r * 0.35f), 0, r * 1.3f,
                     LRColorMix(color, [UIColor whiteColor], 0.75f), LRColorAlpha(color, 0));
    } else {
        [LRColorMix(color, [UIColor blackColor], 0.72f) setFill];
        CGContextFillEllipseInRect(ctx, disc);
        CGContextAddEllipseInRect(ctx, disc);
        CGContextClip(ctx);
        LRFillRadial(ctx, CGPointMake(c.x - r * 0.3f, c.y - r * 0.35f), 0, r,
                     [UIColor colorWithWhite:1 alpha:0.35f], [UIColor colorWithWhite:1 alpha:0]);
    }
    CGContextRestoreGState(ctx);
}

void LRDrawPaperCard(CGContextRef ctx, CGRect r, CGFloat radius) {
    LRSkin *s = SKIN;
    if (s->flat) {
        [s->cardTop setFill];
        CGContextFillRect(ctx, r);
        return;
    }
    CGContextSaveGState(ctx);
    LRAddRoundRect(ctx, CGRectOffset(r, 0, 2), radius);
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.38f);
    CGContextFillPath(ctx);
    LRAddRoundRect(ctx, r, radius);
    CGContextClip(ctx);
    LRFillVertical(ctx, r, s->cardTop, s->cardBottom);
    LRDrawNoise(ctx, r, s->night ? 0.10f : 0.07f);
    CGContextRestoreGState(ctx);
    CGContextSaveGState(ctx);
    LRAddRoundRect(ctx, CGRectInset(r, 0.5f, 0.5f), radius);
    [s->cardEdge setStroke];
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
}

void LRDrawBrassPlate(CGContextRef ctx, CGRect r, CGFloat radius) {
    LRSkin *s = SKIN;
    if (s->flat) {
        [s->brassTop setFill];
        CGContextFillRect(ctx, r);
        return;
    }
    CGContextSaveGState(ctx);
    LRAddRoundRect(ctx, CGRectOffset(r, 0, 1.5f), radius);
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.5f);
    CGContextFillPath(ctx);
    LRAddRoundRect(ctx, r, radius);
    CGContextClip(ctx);
    CGFloat locs[3] = { 0, 0.5f, 1 };
    LRFillLinear(ctx, r.origin, CGPointMake(r.origin.x, CGRectGetMaxY(r)),
                 [NSArray arrayWithObjects:s->brassTop, LRColorMix(s->brassTop, s->brassBottom, 0.55f),
                  s->brassBottom, nil], locs);
    LRDrawBrushedMetal(ctx, r, nil, nil, [UIColor colorWithWhite:1 alpha:0.14f],
                       [UIColor colorWithRed:0.3f green:0.2f blue:0 alpha:0.12f],
                       (unsigned)(r.size.width * 7 + r.size.height));
    CGContextRestoreGState(ctx);
    CGContextSaveGState(ctx);
    LRAddRoundRect(ctx, CGRectInset(r, 0.5f, 0.5f), radius);
    [s->brassShine setStroke];
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
    LRDrawScrew(ctx, CGPointMake(r.origin.x + 9, CGRectGetMidY(r)), 3.2f, 0.6f);
    LRDrawScrew(ctx, CGPointMake(CGRectGetMaxX(r) - 9, CGRectGetMidY(r)), 3.2f, 2.1f);
}

void LRDrawSeekGlyph(CGContextRef ctx, CGPoint c, CGFloat size, int direction, UIColor *color) {
    CGFloat d = direction < 0 ? -1 : 1;
    [color setFill];
    for (int k = -1; k <= 1; k += 2) {
        CGFloat ox = c.x + k * size * 0.45f;
        CGContextMoveToPoint(ctx, ox - size * 0.45f * d, c.y - size * 0.55f);
        CGContextAddLineToPoint(ctx, ox + size * 0.45f * d, c.y);
        CGContextAddLineToPoint(ctx, ox - size * 0.45f * d, c.y + size * 0.55f);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    }
}

void LRDrawChevron(CGContextRef ctx, CGPoint c, CGFloat size, BOOL down, UIColor *color, CGFloat width) {
    CGContextSaveGState(ctx);
    [color setStroke];
    CGContextSetLineWidth(ctx, width);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
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

CGFloat LRTrackedWidth(NSString *text, UIFont *font, CGFloat tracking) {
    CGFloat w = 0;
    NSUInteger n = [text length];
    for (NSUInteger i = 0; i < n; ++i)
        w += [[text substringWithRange:NSMakeRange(i, 1)] sizeWithFont:font].width;
    return w + tracking * (n > 0 ? n - 1 : 0);
}

CGFloat LRDrawTracked(NSString *text, CGFloat x, CGFloat y, UIFont *font, CGFloat tracking,
                      NSTextAlignment align, UIColor *color, UIColor *shadow, CGFloat dy) {
    CGFloat width = LRTrackedWidth(text, font, tracking);
    if (align == NSTextAlignmentCenter) x -= width / 2;
    else if (align == NSTextAlignmentRight) x -= width;
    for (int pass = shadow ? 0 : 1; pass < 2; ++pass) {
        [(pass == 0 ? shadow : color) set];
        CGFloat cx = x;
        for (NSUInteger i = 0; i < [text length]; ++i) {
            NSString *ch = [text substringWithRange:NSMakeRange(i, 1)];
            [ch drawAtPoint:CGPointMake(cx, y + (pass == 0 ? dy : 0)) withFont:font];
            cx += [ch sizeWithFont:font].width + tracking;
        }
    }
    return width;
}

void LRDrawGlowText(CGContextRef ctx, NSString *text, CGRect rect, UIFont *font, UIColor *color,
                    NSTextAlignment align, CGFloat blur) {
    if (![text length]) return;
    if (SKIN->flat) {
        [color set];
        [text drawInRect:rect withFont:font lineBreakMode:NSLineBreakByTruncatingTail alignment:align];
        return;
    }
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeZero, blur, color.CGColor);
    [LRColorMix(color, [UIColor whiteColor], 0.35f) set];
    [text drawInRect:rect withFont:font lineBreakMode:NSLineBreakByTruncatingTail alignment:align];
    CGContextRestoreGState(ctx);
}

/* segment polygons for a digit cell of height h, as in the prototype */
static void LRSegmentPath(CGContextRef ctx, char seg, CGFloat ox, CGFloat oy, CGFloat h) {
    CGFloat w = h * 0.55f, th = h * 0.13f, slant = h * 0.08f, half = h / 2;
    CGFloat pts[6][2];
    int n = 0;
#define P(X, Y) do { pts[n][0] = (X); pts[n][1] = (Y); ++n; } while (0)
    switch (seg) {
        case 'a': P(th * .6f, 0); P(w - th * .6f, 0); P(w - th * 1.5f, th); P(th * 1.5f, th); break;
        case 'd': P(th * 1.5f, h - th); P(w - th * 1.5f, h - th); P(w - th * .6f, h); P(th * .6f, h); break;
        case 'g': P(th, half); P(th * 1.7f, half - th / 2); P(w - th * 1.7f, half - th / 2); P(w - th, half);
                  P(w - th * 1.7f, half + th / 2); P(th * 1.7f, half + th / 2); break;
        case 'f': P(0, th * .6f); P(th, th * 1.5f); P(th, half - th * .7f); P(th * .5f, half - th * .2f);
                  P(0, half - th * .6f); break;
        case 'e': P(0, half + th * .6f); P(th * .5f, half + th * .2f); P(th, half + th * .7f);
                  P(th, h - th * 1.5f); P(0, h - th * .6f); break;
        case 'b': P(w, th * .6f); P(w, half - th * .6f); P(w - th * .5f, half - th * .2f);
                  P(w - th, half - th * .7f); P(w - th, th * 1.5f); break;
        case 'c': P(w, half + th * .6f); P(w, h - th * .6f); P(w - th, h - th * 1.5f);
                  P(w - th, half + th * .7f); P(w - th * .5f, half + th * .2f); break;
    }
#undef P
    for (int i = 0; i < n; ++i) {
        CGFloat px = ox + pts[i][0] + slant * (1 - pts[i][1] / h);
        CGFloat py = oy + pts[i][1];
        if (i == 0) CGContextMoveToPoint(ctx, px, py);
        else CGContextAddLineToPoint(ctx, px, py);
    }
    CGContextClosePath(ctx);
}

static const char *LRSegmentsFor(unichar ch) {
    switch (ch) {
        case '0': return "abcdef"; case '1': return "bc"; case '2': return "abged";
        case '3': return "abgcd"; case '4': return "fgbc"; case '5': return "afgcd";
        case '6': return "afgedc"; case '7': return "abc"; case '8': return "abcdefg";
        case '9': return "abcdfg"; case '-': return "g";
    }
    return "";
}

/* the flat skin shows the clock in thin figures instead of segments */
static UIFont *LRFlatClockFont(CGFloat h) {
    return [LRSkin lightFont:h * 1.3f];
}

CGFloat LRSevenSegmentWidth(NSString *text, CGFloat h) {
    if (SKIN->flat) return [text sizeWithFont:LRFlatClockFont(h)].width;
    CGFloat w = 0, th = h * 0.13f;
    for (NSUInteger i = 0; i < [text length]; ++i)
        w += [text characterAtIndex:i] == ':' ? th * 2.2f : h * 0.55f + th * 0.9f;
    return w;
}

CGFloat LRDrawSevenSegment(CGContextRef ctx, NSString *text, CGPoint o, CGFloat h,
                           UIColor *on, UIColor *off) {
    if (SKIN->flat) {
        UIFont *f = LRFlatClockFont(h);
        [on set];
        /* baseline on the bottom of the segment box */
        CGSize size = [text drawAtPoint:CGPointMake(o.x, o.y + h - f.ascender) withFont:f];
        return size.width;
    }
    CGFloat th = h * 0.13f, slant = h * 0.08f, x = o.x;
    CGContextSaveGState(ctx);
    for (NSUInteger i = 0; i < [text length]; ++i) {
        unichar ch = [text characterAtIndex:i];
        if (ch == ':') {
            CGContextSetShadowWithColor(ctx, CGSizeZero, th * 1.5f, on.CGColor);
            [on setFill];
            CGFloat ys[2] = { h * 0.32f, h * 0.72f };
            for (int k = 0; k < 2; ++k) {
                CGFloat cx = x + th * 0.9f + slant * (1 - ys[k] / h);
                CGContextFillEllipseInRect(ctx, CGRectMake(cx - th * 0.55f, o.y + ys[k] - th * 0.55f,
                                                           th * 1.1f, th * 1.1f));
            }
            x += th * 2.2f;
            continue;
        }
        const char *lit = LRSegmentsFor(ch);
        const char *all = "abcdefg";
        for (int k = 0; k < 7; ++k) {
            BOOL isOn = strchr(lit, all[k]) != NULL;
            LRSegmentPath(ctx, all[k], x, o.y, h);
            if (isOn) {
                CGContextSetShadowWithColor(ctx, CGSizeZero, th * 1.6f, on.CGColor);
                [on setFill];
            } else {
                CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
                [off setFill];
            }
            CGContextFillPath(ctx);
        }
        x += h * 0.55f + th * 0.9f;
    }
    CGContextRestoreGState(ctx);
    return x - o.x;
}

#pragma mark flags

UIImage *LRFlagImage(NSString *code) {
    if ([code length] != 2) return nil;
    NSString *key = [@"flag." stringByAppendingString:code];
    UIImage *img = LRCached(key);
    if (img) return img;
    NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"flags/flag-%@.png", [code lowercaseString]]];
    img = [UIImage imageWithContentsOfFile:path];
    if (img) LRCache(key, img);
    return img;
}

/* an enamel pin: the flag in a round badge with a metal rim and a highlight */
void LRDrawFlag(CGContextRef ctx, NSString *code, CGRect rect) {
    UIImage *img = LRFlagImage(code);
    CGRect disc = rect;
    if (SKIN->flat) {
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, disc);
        CGContextClip(ctx);
        if (img) [img drawInRect:disc];
        else { [SKIN->separator setFill]; CGContextFillRect(ctx, disc); }
        CGContextRestoreGState(ctx);
        [[UIColor colorWithWhite:0 alpha:0.12f] setStroke];
        CGContextSetLineWidth(ctx, LRHairline());
        CGContextStrokeEllipseInRect(ctx, CGRectInset(disc, 0.25f, 0.25f));
        return;
    }
    CGContextSaveGState(ctx);
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.35f);
    CGContextFillEllipseInRect(ctx, CGRectOffset(disc, 0, 0.8f));
    CGContextAddEllipseInRect(ctx, disc);
    CGContextClip(ctx);
    if (img) {
        [img drawInRect:disc];
    } else {
        LRFillVertical(ctx, disc, [UIColor colorWithWhite:0.75f alpha:1], [UIColor colorWithWhite:0.5f alpha:1]);
    }
    LRFillLinear(ctx, disc.origin, CGPointMake(disc.origin.x, CGRectGetMaxY(disc)),
                 [NSArray arrayWithObjects:[UIColor colorWithWhite:1 alpha:0.45f],
                  [UIColor colorWithWhite:1 alpha:0.05f], [UIColor colorWithWhite:0 alpha:0.18f], nil], NULL);
    CGContextRestoreGState(ctx);
    CGContextSaveGState(ctx);
    CGContextSetRGBStrokeColor(ctx, 0.85f, 0.86f, 0.88f, 0.9f);
    CGContextSetLineWidth(ctx, 1.0f);
    CGContextStrokeEllipseInRect(ctx, CGRectInset(disc, 0.5f, 0.5f));
    CGContextRestoreGState(ctx);
}
