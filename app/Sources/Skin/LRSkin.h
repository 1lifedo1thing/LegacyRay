/* the finishes of the receiver: "silver" (brushed aluminium, blue lit
   display, saddle leather log) for the day, "graphite" (dark anodised metal,
   amber display, black leather) for the night, and "flat" for ios 7 and
   later: white cards on grey, hairlines, tint text. every drawing routine reads
   its colours from the current skin, so a theme switch is a rebuild */
#import <UIKit/UIKit.h>

@interface LRSkin : NSObject {
@public
    BOOL night;
    /* the flat, ios 7 style finish: no textures, hairlines instead of bevels,
       tint coloured text buttons. every primitive in LRDraw honours it */
    BOOL flat;
    UIColor *tint, *background, *separator;
    /* faceplate */
    UIColor *plateTop, *plateBottom, *hairLight, *hairDark;
    UIColor *engrave, *engraveShadow;
    CGFloat engraveOffset;      /* +1 light shadow below, -1 dark shadow above */
    /* display glass */
    UIColor *glassTop, *glassBottom, *glow, *glowDim;
    /* meters */
    UIColor *meterTop, *meterBottom, *meterInk, *meterRed, *meterNeedle, *meterLamp;
    /* station log */
    UIColor *leather, *leatherDark, *stitch;
    UIColor *cardTop, *cardBottom, *cardInk, *cardMuted, *cardEdge;
    UIColor *brassTop, *brassBottom, *brassInk, *brassShine;
    UIColor *walnut, *walnutDark;
    /* settings */
    UIColor *linen, *linenThread;
    UIColor *groupTop, *groupBottom, *groupInk, *groupMuted, *groupLine, *groupEdge,
            *groupPressed, *groupHeader, *groupHeaderShadow;
    /* status colours */
    UIColor *ledGreen, *ledAmber, *ledRed, *good, *warn, *bad, *link;
}

+ (LRSkin *)current;
/* recompute from the theme setting (and the clock for Auto) */
+ (void)reload;

/* fonts that exist on every ios from 4.0 */
+ (UIFont *)titleFont:(CGFloat)size;      /* serif, the engraved nameplate */
+ (UIFont *)labelFont:(CGFloat)size;      /* bold sans, panel legends */
+ (UIFont *)bodyFont:(CGFloat)size;
+ (UIFont *)boldFont:(CGFloat)size;
+ (UIFont *)monoFont:(CGFloat)size;
/* thin numerals for the flat clock and big figures */
+ (UIFont *)lightFont:(CGFloat)size;
+ (UIFont *)thinFont:(CGFloat)size;
@end

#define SKIN ([LRSkin current])
