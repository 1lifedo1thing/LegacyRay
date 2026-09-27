/* the drawing primitives the receiver is built from. all of it is plain
   CoreGraphics so it renders identically from ios 4 to ios 7 and at any
   scale; the expensive textures are generated once and cached */
#import <UIKit/UIKit.h>
#import "LRSkin.h"

/* paths and fills */
void LRAddRoundRect(CGContextRef ctx, CGRect r, CGFloat radius);
CGPathRef LRCreateRoundRectPath(CGRect r, CGFloat radius) CF_RETURNS_RETAINED;
void LRFillVertical(CGContextRef ctx, CGRect r, UIColor *top, UIColor *bottom);
/* colors: UIColor array; locations may be NULL for even spacing */
void LRFillLinear(CGContextRef ctx, CGPoint start, CGPoint end, NSArray *colors,
                  const CGFloat *locations);
void LRFillRadial(CGContextRef ctx, CGPoint center, CGFloat r0, CGFloat r1,
                  UIColor *inner, UIColor *outer);

/* cached texture tiles */
UIImage *LRNoiseTile(void);
UIImage *LRPebbleTile(void);
UIImage *LRLinenTile(void);

/* surfaces (current skin) */
void LRDrawBrushedMetal(CGContextRef ctx, CGRect r, UIColor *top, UIColor *bottom,
                        UIColor *light, UIColor *dark, unsigned seed);
UIImage *LRFaceplateImage(CGSize size);   /* cached per size and skin */
void LRDrawLeather(CGContextRef ctx, CGRect r);
UIImage *LRLeatherImage(CGSize size);
void LRDrawLinen(CGContextRef ctx, CGRect r);
UIImage *LRLinenImage(CGSize size);
void LRDrawWalnut(CGContextRef ctx, CGRect r);
void LRDrawStitching(CGContextRef ctx, CGRect r, CGFloat radius, CGFloat inset, UIColor *thread);
void LRDrawNoise(CGContextRef ctx, CGRect r, CGFloat alpha);
void LRFlushSkinCaches(void);

/* hardware */
void LRDrawScrew(CGContextRef ctx, CGPoint c, CGFloat radius, CGFloat angle);
void LRDrawInsetWell(CGContextRef ctx, CGRect r, CGFloat radius, UIColor *top,
                     UIColor *bottom, CGFloat depth);
void LRDrawBezel(CGContextRef ctx, CGRect r, CGFloat radius);
void LRDrawGloss(CGContextRef ctx, CGRect r, CGFloat radius);
void LRDrawLED(CGContextRef ctx, CGPoint c, CGFloat radius, UIColor *color, BOOL on);
void LRDrawPaperCard(CGContextRef ctx, CGRect r, CGFloat radius);
void LRDrawBrassPlate(CGContextRef ctx, CGRect r, CGFloat radius);
void LRDrawSeekGlyph(CGContextRef ctx, CGPoint c, CGFloat size, int direction, UIColor *color);
void LRDrawChevron(CGContextRef ctx, CGPoint c, CGFloat size, BOOL down, UIColor *color, CGFloat width);

/* text; these draw into the current UIKit context */
void LRDrawEngraved(NSString *text, CGRect rect, UIFont *font, NSTextAlignment align,
                    UIColor *color, UIColor *shadow, CGFloat dy);
CGFloat LRTrackedWidth(NSString *text, UIFont *font, CGFloat tracking);
/* x is the left, centre or right edge per align, y the top of the line */
CGFloat LRDrawTracked(NSString *text, CGFloat x, CGFloat y, UIFont *font, CGFloat tracking,
                      NSTextAlignment align, UIColor *color, UIColor *shadow, CGFloat dy);
void LRDrawGlowText(CGContextRef ctx, NSString *text, CGRect rect, UIFont *font,
                    UIColor *color, NSTextAlignment align, CGFloat blur);
CGFloat LRSevenSegmentWidth(NSString *text, CGFloat height);
CGFloat LRDrawSevenSegment(CGContextRef ctx, NSString *text, CGPoint origin, CGFloat height,
                           UIColor *on, UIColor *off);

/* flags from the bundle: flags/flag-xx.png */
UIImage *LRFlagImage(NSString *code);
void LRDrawFlag(CGContextRef ctx, NSString *code, CGRect rect);

UIColor *LRColorMix(UIColor *a, UIColor *b, CGFloat t);
UIColor *LRColorAlpha(UIColor *c, CGFloat alpha);
