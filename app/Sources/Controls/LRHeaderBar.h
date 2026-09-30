/* the header of every screen: a denim navigation bar with a copper seam and
   ios 6 bar keys (classic), or the ios 7 bar (flat). replaces
   UINavigationBar so the look is the same from ios 4 to ios 7 */
#import <UIKit/UIKit.h>
#import "LRButton.h"

#define LR_HEADER_HEIGHT 44.0f

@interface LRHeaderBar : UIView {
    UILabel *_titleLabel;
    LRButton *_leftButton;
    LRButton *_rightButton;
    LRButton *_extraButton;
    UIView *_rightView;
    UIView *_blur;       /* a UIToolbar: the one public ios 7 blur */
    UIView *_hairline;
    CGFloat _topInset;
    BOOL _translucent;
}
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, retain) LRButton *leftButton;
@property (nonatomic, retain) LRButton *rightButton;
/* a second key, left of the right one */
@property (nonatomic, retain) LRButton *extraButton;
@property (nonatomic, copy) NSString *title;
/* the strip under the status bar on ios 7; the bar is drawn through it and
   the title and keys sit below it */
@property (nonatomic, assign) CGFloat topInset;
/* the flat skin on ios 7: frosted, content scrolls underneath */
@property (nonatomic, assign) BOOL translucent;

- (LRButton *)setBackButtonWithTitle:(NSString *)title action:(void (^)(LRButton *b))action;
- (LRButton *)setLeftTitle:(NSString *)title style:(LRButtonStyle)style action:(void (^)(LRButton *b))action;
- (LRButton *)setRightTitle:(NSString *)title style:(LRButtonStyle)style action:(void (^)(LRButton *b))action;
- (LRButton *)setRightGlyph:(UIImage *)glyph action:(void (^)(LRButton *b))action;
- (LRButton *)setExtraGlyph:(UIImage *)glyph action:(void (^)(LRButton *b))action;
/* the ink glyphs on header keys are drawn in */
+ (UIColor *)glyphColor;
@end
