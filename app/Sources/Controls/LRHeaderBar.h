/* the header of every screen: a strip of the faceplate with the title
   engraved into it and hardware buttons at the ends. replaces the navigation
   bar so the look is the same from ios 4 to ios 7 */
#import <UIKit/UIKit.h>
#import "LRButton.h"

#define LR_HEADER_HEIGHT 44.0f

@interface LRHeaderBar : UIView {
    UILabel *_titleLabel;
    LRButton *_leftButton;
    LRButton *_rightButton;
    LRButton *_extraButton;
    UIView *_rightView;
}
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, retain) LRButton *leftButton;
@property (nonatomic, retain) LRButton *rightButton;
/* a second key, left of the right one */
@property (nonatomic, retain) LRButton *extraButton;
@property (nonatomic, copy) NSString *title;

- (LRButton *)setBackButtonWithTitle:(NSString *)title action:(void (^)(LRButton *b))action;
- (LRButton *)setLeftTitle:(NSString *)title style:(LRButtonStyle)style action:(void (^)(LRButton *b))action;
- (LRButton *)setRightTitle:(NSString *)title style:(LRButtonStyle)style action:(void (^)(LRButton *b))action;
- (LRButton *)setRightGlyph:(UIImage *)glyph action:(void (^)(LRButton *b))action;
- (LRButton *)setExtraGlyph:(UIImage *)glyph action:(void (^)(LRButton *b))action;
/* the ink glyphs on header keys are drawn in */
+ (UIColor *)glyphColor;
@end
