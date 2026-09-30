/* the drawing primitives the app is built from. all of it is plain
   CoreGraphics so it renders identically from ios 4 to ios 7 and at any
   scale; textures are small pattern tiles and anything screen sized is drawn
   once and cached. scripts/design/classic.py is the same code in cairo */
#import <UIKit/UIKit.h>
#import "LRSkin.h"

/* where a row sits in its group: decides the rounded corners */
typedef enum {
    LRPlateSingle = 0,
    LRPlateTop,
    LRPlateMiddle,
    LRPlateBottom
} LRPlatePosition;

/* paths and fills */
void LRAddRoundRect(CGContextRef ctx, CGRect r, CGFloat radius);
CGPathRef LRCreateRoundRectPath(CGRect r, CGFloat radius) CF_RETURNS_RETAINED;
void LRFillVertical(CGContextRef ctx, CGRect r, UIColor *top, UIColor *bottom);
/* colors: UIColor array; locations may be NULL for even spacing */
void LRFillLinear(CGContextRef ctx, CGPoint start, CGPoint end, NSArray *colors,
                  const CGFloat *locations);
void LRFillRadial(CGContextRef ctx, CGPoint center, CGFloat r0, CGFloat r1,
                  UIColor *inner, UIColor *outer);

/* the denim of the icon: a 105 point twill tile from the bundle */
UIImage *LRDenimTile(void);
void LRDrawDenim(CGContextRef ctx, CGRect r, CGFloat shade);
/* the main screen: the denim a shade darker, as a pattern colour, and a
   small radial light to stretch over it (no screen sized bitmaps) */
UIColor *LRDenimPageColor(void);
UIImage *LRVignetteImage(void);
/* the grouped table background: ios 6 pinstripes as a pattern colour */
UIColor *LRPinstripeColor(void);
void LRFlushSkinCaches(void);

/* copper thread, sewn: a dashed line with the shadow of its holes */
void LRDrawStitchLine(CGContextRef ctx, CGPoint a, CGPoint b);
void LRDrawStitchCircle(CGContextRef ctx, CGPoint c, CGFloat radius);
void LRDrawStitchRoundRect(CGContextRef ctx, CGRect r, CGFloat radius);

/* a navigation bar: denim, a soft top light, a seam above the bottom edge */
void LRDrawBar(CGContextRef ctx, CGRect r);

/* grouped rows: the outline of a row at a position, and the whole row */
void LRAddCellPath(CGContextRef ctx, CGRect r, LRPlatePosition position, CGFloat radius);
/* onDark: a single row laid on the denim (dark rim, no lip) */
void LRDrawGroupCell(CGContextRef ctx, CGRect r, LRPlatePosition position, BOOL pressed, BOOL onDark);
void LRDrawChevron(CGContextRef ctx, CGPoint c, CGFloat size, BOOL down, UIColor *color, CGFloat width);
void LRDrawCheckmark(CGContextRef ctx, CGPoint start, UIColor *color);
/* the blue (>) detail key of ios 6, 29 points square */
UIImage *LRDetailDisclosureImage(BOOL pressed);
/* a status lamp */
void LRDrawLED(CGContextRef ctx, CGPoint c, CGFloat radius, UIColor *color, BOOL on);

/* text; these draw into the current UIKit context */
void LRDrawEngraved(NSString *text, CGRect rect, UIFont *font, NSTextAlignment align,
                    UIColor *color, UIColor *shadow, CGFloat dy);

/* flags from the bundle: flags/flag-xx.png */
UIImage *LRFlagImage(NSString *code);
/* a round badge with a little glass on it */
void LRDrawFlag(CGContextRef ctx, NSString *code, CGRect rect);

UIColor *LRColorMix(UIColor *a, UIColor *b, CGFloat t);
UIColor *LRColorAlpha(UIColor *c, CGFloat alpha);
