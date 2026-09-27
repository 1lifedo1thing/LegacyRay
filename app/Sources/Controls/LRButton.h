/* hardware buttons. the look is generated from CoreGraphics into stretchable
   background images, so a button costs one bitmap per style and height */
#import <UIKit/UIKit.h>

typedef enum {
    LRButtonMetal = 0,   /* follows the skin: silver by day, gunmetal by night */
    LRButtonDark,        /* black glossy, for use on light plates */
    LRButtonGreen,       /* candy green: connect, save */
    LRButtonRed,         /* candy red: delete, disconnect */
    LRButtonBrass,
    LRButtonBack,        /* metal with a pointed left edge, for the header */
    LRButtonKey          /* a flat key for segmented rows; selected = lit */
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
/* a centred drawn glyph instead of text (seek arrows, plus, gear) */
- (void)setGlyph:(UIImage *)glyph;
@end

/* "S T A T I O N S": hair spaces between letters for a tracked panel legend */
NSString *LRSpaced(NSString *text);

/* small glyph images, drawn in the given colour */
UIImage *LRGlyphPlus(CGFloat size, UIColor *color);
UIImage *LRGlyphGear(CGFloat size, UIColor *color);
UIImage *LRGlyphSeek(CGFloat size, int direction, UIColor *color);
UIImage *LRGlyphList(CGFloat size, UIColor *color);
UIImage *LRGlyphRefresh(CGFloat size, UIColor *color);
UIImage *LRGlyphClose(CGFloat size, UIColor *color);
UIImage *LRGlyphDots(CGFloat size, UIColor *color);
