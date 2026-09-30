/* the two finishes. "classic" is what apple shipped on ios 6, dressed in the
   icon's black denim: denim bars with a copper seam, a denim main screen
   with one pearl button, and the stock grouped tables (pinstripes, white
   rows, blue values) everywhere else. "flat" is ios 7: white cards on grey,
   hairlines, tint text. every drawing routine reads its colours from here, so
   a theme switch is a rebuild */
#import <UIKit/UIKit.h>

@interface LRSkin : NSObject {
@public
    /* the flat, ios 7 style finish: no textures, hairlines instead of bevels,
       tint coloured text buttons. every primitive in LRDraw honours it */
    BOOL flat;
    UIColor *tint, *background, *separator;
    /* the chrome: title and keys on the bars, the copper thread */
    UIColor *barInk, *barShadow, *stitch;
    /* text laid straight onto the main screen */
    UIColor *pageInk, *pageMuted, *pageShadow;
    /* grouped rows */
    UIColor *groupTop, *groupBottom, *groupInk, *groupMuted, *groupDetail, *groupLine, *groupEdge,
            *groupPressed, *groupPressedBottom, *groupHeader, *groupHeaderShadow;
    /* status colours: lamps (the power glyph, dots) and text */
    UIColor *ledGreen, *ledAmber, *ledRed, *good, *warn, *bad, *link;
}

+ (LRSkin *)current;
/* recompute from the theme setting */
+ (void)reload;

/* fonts that exist on every ios from 4.0 */
+ (UIFont *)titleFont:(CGFloat)size;      /* bar titles */
+ (UIFont *)labelFont:(CGFloat)size;      /* small bold captions */
+ (UIFont *)bodyFont:(CGFloat)size;
+ (UIFont *)boldFont:(CGFloat)size;
+ (UIFont *)monoFont:(CGFloat)size;
/* thin numerals for the flat clock and big figures */
+ (UIFont *)lightFont:(CGFloat)size;
+ (UIFont *)thinFont:(CGFloat)size;
@end

#define SKIN ([LRSkin current])
