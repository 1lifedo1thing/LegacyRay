#import "LRSkin.h"
#import "LRPrefs.h"

static LRSkin *gSkin = nil;

static UIColor *H(unsigned rgb, CGFloat a) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0f green:((rgb >> 8) & 0xff) / 255.0f
                            blue:(rgb & 0xff) / 255.0f alpha:a];
}

@implementation LRSkin

- (void)dealloc {
    UIColor **all[] = {
        &plateTop, &plateBottom, &hairLight, &hairDark, &engrave, &engraveShadow,
        &glassTop, &glassBottom, &glow, &glowDim, &meterTop, &meterBottom, &meterInk,
        &meterRed, &meterNeedle, &meterLamp, &leather, &leatherDark, &stitch, &cardTop,
        &cardBottom, &cardInk, &cardMuted, &cardEdge, &brassTop, &brassBottom, &brassInk,
        &brassShine, &walnut, &walnutDark, &linen, &linenThread, &groupTop, &groupBottom,
        &groupInk, &groupMuted, &groupLine, &groupEdge, &groupPressed, &groupHeader,
        &groupHeaderShadow, &ledGreen, &ledAmber, &ledRed, &good, &warn, &bad, &link,
        &tint, &background, &separator };
    for (size_t i = 0; i < sizeof all / sizeof all[0]; ++i) [*all[i] release];
    [super dealloc];
}

#define SET(field, value) do { [field release]; field = [(value) retain]; } while (0)

- (void)configureFlat {
    flat = YES;
    night = NO;
    UIColor *white = H(0xFFFFFF, 1), *bg = H(0xEFEFF4, 1), *ink = H(0x000000, 1);
    UIColor *muted = H(0x8E8E93, 1), *line = H(0xC8C7CC, 1), *blue = H(0x007AFF, 1);
    UIColor *clear = [UIColor clearColor];
    SET(tint, blue);
    SET(background, bg);
    SET(separator, line);
    SET(ledGreen, H(0x4CD964, 1));
    SET(ledAmber, H(0xFF9500, 1));
    SET(ledRed, H(0xFF3B30, 1));
    SET(walnut, bg);
    SET(walnutDark, bg);
    SET(plateTop, H(0xF7F7F7, 1));
    SET(plateBottom, H(0xF7F7F7, 1));
    SET(hairLight, clear);
    SET(hairDark, clear);
    SET(engrave, ink);
    SET(engraveShadow, clear);
    engraveOffset = 0;
    SET(glassTop, white);
    SET(glassBottom, white);
    SET(glow, blue);
    SET(glowDim, H(0x000000, 0.06));
    SET(meterTop, white);
    SET(meterBottom, white);
    SET(meterInk, muted);
    SET(meterRed, H(0xFF3B30, 1));
    SET(meterNeedle, H(0xFF9500, 1));
    SET(meterLamp, clear);
    SET(leather, bg);
    SET(leatherDark, bg);
    SET(stitch, clear);
    SET(cardTop, white);
    SET(cardBottom, white);
    SET(cardInk, ink);
    SET(cardMuted, muted);
    SET(cardEdge, clear);
    SET(brassTop, bg);
    SET(brassBottom, bg);
    SET(brassInk, H(0x6D6D72, 1));
    SET(brassShine, clear);
    SET(linen, bg);
    SET(linenThread, clear);
    SET(groupTop, white);
    SET(groupBottom, white);
    SET(groupInk, ink);
    SET(groupMuted, muted);
    SET(groupLine, line);
    SET(groupEdge, line);
    SET(groupPressed, H(0xD9D9D9, 1));
    SET(groupHeader, H(0x6D6D72, 1));
    SET(groupHeaderShadow, clear);
    SET(good, H(0x2BB24C, 1));
    SET(warn, H(0xFF9500, 1));
    SET(bad, H(0xFF3B30, 1));
    SET(link, blue);
}

- (void)configureNight:(BOOL)isNight {
    night = isNight;
    flat = NO;
    SET(tint, H(0x2F5E9E, 1));
    SET(background, isNight ? H(0x2B2D31, 1) : H(0xD5D8DD, 1));
    SET(separator, isNight ? H(0x24262A, 1) : H(0xD0D3D8, 1));
    /* shared */
    SET(ledGreen, H(0x3BEA6A, 1));
    SET(ledAmber, H(0xFFB02E, 1));
    SET(ledRed, H(0xFF3B30, 1));
    SET(walnut, H(0x5B3A22, 1));
    SET(walnutDark, H(0x2E1B0E, 1));
    SET(meterRed, H(0xC8321E, 1));
    if (!isNight) {
        SET(plateTop, H(0xE6E8EA, 1));
        SET(plateBottom, H(0xC3C6CA, 1));
        SET(hairLight, H(0xFFFFFF, 0.13));
        SET(hairDark, H(0x000000, 0.055));
        SET(engrave, H(0x34373B, 1));
        SET(engraveShadow, H(0xFFFFFF, 0.8));
        engraveOffset = 1;
        SET(glassTop, H(0x0E171C, 1));
        SET(glassBottom, H(0x04080A, 1));
        SET(glow, H(0x8FE3FF, 1));
        SET(glowDim, H(0x8FE3FF, 0.13));
        SET(meterTop, H(0xF7EDCF, 1));
        SET(meterBottom, H(0xE3CF97, 1));
        SET(meterInk, H(0x2A2218, 1));
        SET(meterNeedle, H(0x15100C, 1));
        SET(meterLamp, H(0xFFE9A8, 0.45));
        SET(leather, H(0x6A4125, 1));
        SET(leatherDark, H(0x3E2413, 1));
        SET(stitch, H(0xE9D8AE, 0.85));
        SET(cardTop, H(0xFBF6E8, 1));
        SET(cardBottom, H(0xEFE6CD, 1));
        SET(cardInk, H(0x3A2A1B, 1));
        SET(cardMuted, H(0x8A7458, 1));
        SET(cardEdge, H(0xFFFFFF, 0.6));
        SET(brassTop, H(0xE0C27A, 1));
        SET(brassBottom, H(0xA47F3A, 1));
        SET(brassInk, H(0x3B2A12, 1));
        SET(brassShine, H(0xFFF3D6, 0.6));
        SET(linen, H(0xD5D8DD, 1));
        SET(linenThread, H(0xFFFFFF, 0.22));
        SET(groupTop, H(0xFFFFFF, 1));
        SET(groupBottom, H(0xF3F4F6, 1));
        SET(groupInk, H(0x24272B, 1));
        SET(groupMuted, H(0x6E7580, 1));
        SET(groupLine, H(0xD0D3D8, 1));
        SET(groupEdge, H(0xABB0B7, 1));
        SET(groupPressed, H(0xDDE3EA, 1));
        SET(groupHeader, H(0x4C566A, 1));
        SET(groupHeaderShadow, H(0xFFFFFF, 0.9));
        SET(good, H(0x2E9E4F, 1));
        SET(warn, H(0xC98A1B, 1));
        SET(bad, H(0xB8392B, 1));
        SET(link, H(0x2F5E9E, 1));
    } else {
        SET(plateTop, H(0x45484C, 1));
        SET(plateBottom, H(0x26282B, 1));
        SET(hairLight, H(0xFFFFFF, 0.065));
        SET(hairDark, H(0x000000, 0.11));
        SET(engrave, H(0xC8CCD1, 1));
        SET(engraveShadow, H(0x000000, 0.85));
        engraveOffset = -1;
        SET(glassTop, H(0x150F08, 1));
        SET(glassBottom, H(0x070503, 1));
        SET(glow, H(0xFFB04A, 1));
        SET(glowDim, H(0xFFB04A, 0.12));
        SET(meterTop, H(0x3B2B13, 1));
        SET(meterBottom, H(0x1C1408, 1));
        SET(meterInk, H(0xFFC46B, 1));
        SET(meterNeedle, H(0xFF6A3D, 1));
        SET(meterLamp, H(0xFF9A2E, 0.28));
        SET(leather, H(0x2A2624, 1));
        SET(leatherDark, H(0x121010, 1));
        SET(stitch, H(0x8A827A, 0.9));
        SET(cardTop, H(0x38342F, 1));
        SET(cardBottom, H(0x2B2825, 1));
        SET(cardInk, H(0xEDE7DD, 1));
        SET(cardMuted, H(0xA59D91, 1));
        SET(cardEdge, H(0xFFFFFF, 0.07));
        SET(brassTop, H(0xA48856, 1));
        SET(brassBottom, H(0x5E4A28, 1));
        SET(brassInk, H(0x1E150A, 1));
        SET(brassShine, H(0xFFE7B0, 0.25));
        SET(linen, H(0x2B2D31, 1));
        SET(linenThread, H(0xFFFFFF, 0.05));
        SET(groupTop, H(0x3A3D42, 1));
        SET(groupBottom, H(0x303236, 1));
        SET(groupInk, H(0xE8EAED, 1));
        SET(groupMuted, H(0x9CA3AD, 1));
        SET(groupLine, H(0x24262A, 1));
        SET(groupEdge, H(0x161719, 1));
        SET(groupPressed, H(0x4A4E55, 1));
        SET(groupHeader, H(0xB9C0CA, 1));
        SET(groupHeaderShadow, H(0x000000, 0.9));
        SET(good, H(0x5BD37E, 1));
        SET(warn, H(0xF0B34A, 1));
        SET(bad, H(0xFF6A5A, 1));
        SET(link, H(0x8DB8F0, 1));
    }
}

+ (LRSkin *)current {
    if (!gSkin) [self reload];
    return gSkin;
}

+ (void)reload {
    LRSkin *skin = [[LRSkin alloc] init];
    if ([LRPrefs flatSkinActive]) [skin configureFlat];
    else [skin configureNight:[LRPrefs nightSkinActive]];
    [gSkin release];
    gSkin = skin;
}

+ (UIFont *)font:(NSString *)name size:(CGFloat)size fallbackBold:(BOOL)bold {
    UIFont *f = [UIFont fontWithName:name size:size];
    if (f) return f;
    return bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
}

/* the flat skin speaks helvetica neue like ios 7; -Medium and -Light only
   exist from ios 5, so the lookup falls back to the classic faces */
+ (BOOL)flatFonts {
    return gSkin && gSkin->flat;
}

+ (UIFont *)titleFont:(CGFloat)size {
    if ([self flatFonts]) return [self font:@"HelveticaNeue-Medium" size:size fallbackBold:YES];
    return [self font:@"Georgia-Bold" size:size fallbackBold:YES];
}
+ (UIFont *)labelFont:(CGFloat)size {
    if ([self flatFonts]) return [self font:@"HelveticaNeue-Medium" size:size fallbackBold:YES];
    return [self font:@"Helvetica-Bold" size:size fallbackBold:YES];
}
+ (UIFont *)bodyFont:(CGFloat)size {
    if ([self flatFonts]) return [self font:@"HelveticaNeue" size:size fallbackBold:NO];
    return [self font:@"Helvetica" size:size fallbackBold:NO];
}
+ (UIFont *)boldFont:(CGFloat)size {
    if ([self flatFonts]) return [self font:@"HelveticaNeue-Medium" size:size fallbackBold:YES];
    return [self font:@"Helvetica-Bold" size:size fallbackBold:YES];
}
+ (UIFont *)monoFont:(CGFloat)size { return [self font:@"Courier-Bold" size:size fallbackBold:YES]; }
+ (UIFont *)lightFont:(CGFloat)size {
    UIFont *f = [UIFont fontWithName:@"HelveticaNeue-Light" size:size];
    return f ? f : [self font:@"Helvetica" size:size fallbackBold:NO];
}
@end
