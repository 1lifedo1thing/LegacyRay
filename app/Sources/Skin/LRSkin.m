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
        &tint, &background, &separator, &barInk, &barShadow, &stitch, &pageInk, &pageMuted,
        &pageShadow, &groupTop, &groupBottom, &groupInk, &groupMuted, &groupDetail, &groupLine,
        &groupEdge, &groupPressed, &groupPressedBottom, &groupHeader, &groupHeaderShadow,
        &ledGreen, &ledAmber, &ledRed, &good, &warn, &bad, &link };
    for (size_t i = 0; i < sizeof all / sizeof all[0]; ++i) [*all[i] release];
    [super dealloc];
}

#define SET(field, value) do { [field release]; field = [(value) retain]; } while (0)

- (void)configureFlat {
    flat = YES;
    UIColor *white = H(0xFFFFFF, 1), *ink = H(0x000000, 1), *clear = [UIColor clearColor];
    UIColor *muted = H(0x8E8E93, 1), *line = H(0xC8C7CC, 1), *blue = H(0x007AFF, 1);
    SET(tint, blue);
    SET(background, H(0xEFEFF4, 1));
    SET(separator, line);
    SET(barInk, ink);
    SET(barShadow, clear);
    SET(stitch, clear);
    SET(pageInk, ink);
    SET(pageMuted, muted);
    SET(pageShadow, clear);
    SET(groupTop, white);
    SET(groupBottom, white);
    SET(groupInk, ink);
    SET(groupMuted, muted);
    SET(groupDetail, muted);
    SET(groupLine, line);
    SET(groupEdge, line);
    SET(groupPressed, H(0xD9D9D9, 1));
    SET(groupPressedBottom, H(0xD9D9D9, 1));
    SET(groupHeader, H(0x6D6D72, 1));
    SET(groupHeaderShadow, clear);
    SET(ledGreen, H(0x4CD964, 1));
    SET(ledAmber, H(0xFF9500, 1));
    SET(ledRed, H(0xFF3B30, 1));
    SET(good, H(0x2BB24C, 1));
    SET(warn, H(0xFF9500, 1));
    SET(bad, H(0xFF3B30, 1));
    SET(link, blue);
}

/* the values of scripts/design/classic.py */
- (void)configureClassic {
    flat = NO;
    UIColor *detail = H(0x385487, 1);
    SET(tint, detail);
    SET(background, H(0xC5CCD4, 1));
    SET(separator, H(0xE0E0E0, 1));
    SET(barInk, H(0xFFFFFF, 1));
    SET(barShadow, H(0x000000, 0.6f));
    SET(stitch, H(0xB8966F, 1));
    SET(pageInk, H(0xFFFFFF, 1));
    SET(pageMuted, H(0xA4A8AE, 1));
    SET(pageShadow, H(0x000000, 0.8f));
    SET(groupTop, H(0xFFFFFF, 1));
    SET(groupBottom, H(0xFFFFFF, 1));
    SET(groupInk, H(0x000000, 1));
    SET(groupMuted, H(0x7F7F7F, 1));
    SET(groupDetail, detail);
    SET(groupLine, H(0xE0E0E0, 1));
    SET(groupEdge, H(0xABABAB, 1));
    SET(groupPressed, H(0x058CF5, 1));
    SET(groupPressedBottom, H(0x015EE6, 1));
    SET(groupHeader, H(0x4C566C, 1));
    SET(groupHeaderShadow, H(0xFFFFFF, 1));
    SET(ledGreen, H(0x4DB853, 1));
    SET(ledAmber, H(0xE3A437, 1));
    SET(ledRed, H(0xD5483B, 1));
    SET(good, H(0x3E8E41, 1));
    SET(warn, H(0xC07A12, 1));
    SET(bad, H(0xC4372B, 1));
    SET(link, detail);
}

+ (LRSkin *)current {
    if (!gSkin) [self reload];
    return gSkin;
}

+ (void)reload {
    LRSkin *skin = [[LRSkin alloc] init];
    if ([LRPrefs flatSkinActive]) [skin configureFlat];
    else [skin configureClassic];
    [gSkin release];
    gSkin = skin;
}

+ (UIFont *)font:(NSString *)name size:(CGFloat)size fallbackBold:(BOOL)bold {
    UIFont *f = [UIFont fontWithName:name size:size];
    if (f) return f;
    return bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
}

/* the flat skin speaks helvetica neue like ios 7; -Medium and -Light only
   exist from ios 5, so the lookup falls back to the classic faces. the
   classic skin speaks plain helvetica, like ios 6 */
+ (BOOL)flatFonts {
    return gSkin && gSkin->flat;
}

+ (UIFont *)titleFont:(CGFloat)size {
    if ([self flatFonts]) return [self font:@"HelveticaNeue-Medium" size:size fallbackBold:YES];
    return [self font:@"Helvetica-Bold" size:size fallbackBold:YES];
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
+ (UIFont *)thinFont:(CGFloat)size {
    /* the ios 7 weight for big numbers: Thin arrived with ios 7, UltraLight
       with ios 5; both keep the digits one width, so a clock does not jitter */
    UIFont *f = [UIFont fontWithName:@"HelveticaNeue-Thin" size:size];
    if (!f) f = [UIFont fontWithName:@"HelveticaNeue-UltraLight" size:size];
    return f ? f : [self lightFont:size];
}
+ (UIFont *)lightFont:(CGFloat)size {
    UIFont *f = [UIFont fontWithName:@"HelveticaNeue-Light" size:size];
    return f ? f : [self font:@"Helvetica" size:size fallbackBold:NO];
}
@end
