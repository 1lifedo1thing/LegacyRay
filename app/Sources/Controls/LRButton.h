/* buttons. the look is generated from CoreGraphics into stretchable
   background images, so a button costs one small bitmap per style, height
   and state. classic: the ios 6 keys (white rounded rects on the tables,
   translucent keys on the denim bars, glossy colour for the actions);
   flat: ios 7 tint text and solid fills */
#import <UIKit/UIKit.h>

typedef enum {
    LRButtonMetal = 0,     /* the plain key: a white rounded rect (flat: tint text) */
    LRButtonDark,          /* dark glossy: cancel keys, keys over dark things */
    LRButtonGreen,         /* glossy green: connect, save */
    LRButtonRed,           /* glossy red: delete, disconnect */
    LRButtonBack,          /* the back key of a bar, pointed on the left */
    LRButtonBar,           /* a key on a denim bar */
    LRButtonDone,          /* the blue key on a bar */
    LRButtonRow,           /* a row of a popover or a sheet: bare, blue when pressed */
    LRButtonAlert,         /* a key on an alert panel */
    LRButtonAlertDefault   /* the alert's primary key */
} LRButtonStyle;

@interface LRButton : UIButton {
    LRButtonStyle _style;
    void (^_action)(LRButton *button);
    UIImage *_glyph;
}
@property (nonatomic, assign) LRButtonStyle style;
@property (nonatomic, copy) void (^action)(LRButton *button);

+ (LRButton *)buttonWithStyle:(LRButtonStyle)style title:(NSString *)title
                       action:(void (^)(LRButton *button))action;
/* a centred drawn glyph instead of text (plus, gear, dots) */
- (void)setGlyph:(UIImage *)glyph;
@end

/* small glyph images, drawn in the given colour */
UIImage *LRGlyphPlus(CGFloat size, UIColor *color);
UIImage *LRGlyphGear(CGFloat size, UIColor *color);
UIImage *LRGlyphList(CGFloat size, UIColor *color);
UIImage *LRGlyphRefresh(CGFloat size, UIColor *color);
UIImage *LRGlyphClose(CGFloat size, UIColor *color);
UIImage *LRGlyphDots(CGFloat size, UIColor *color);
/* a glyph with a one point shadow above it, the way ios 6 sets bar icons */
UIImage *LRShadowedGlyph(UIImage *glyph, UIColor *shadow);
