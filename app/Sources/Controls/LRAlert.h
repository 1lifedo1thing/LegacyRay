/* modal panels: the ios 6 alert (charcoal glass, white rim, glossy keys) or
   the ios 7 one, with a title, a message, optional text fields and keys.
   replaces UIAlertView, which has no text input on ios 4 and turns flat on
   ios 7 */
#import <UIKit/UIKit.h>
#import "LRButton.h"

@interface LRAlert : UIView <UITextFieldDelegate> {
    NSString *_title;
    NSString *_message;
    NSMutableArray *_fields;
    NSMutableArray *_buttons;
    NSMutableArray *_actions;
    UIView *_panel;
    UIView *_dim;
    UILabel *_titleLabel;
    UILabel *_messageLabel;
    CGFloat _keyboardHeight;
}
+ (LRAlert *)alertWithTitle:(NSString *)title message:(NSString *)message;
- (void)addButton:(NSString *)title style:(LRButtonStyle)style action:(void (^)(LRAlert *alert))action;
- (UITextField *)addFieldWithPlaceholder:(NSString *)placeholder text:(NSString *)text;
- (NSArray *)fields;
- (NSString *)textAtIndex:(NSUInteger)index;
- (void)show;
- (void)dismiss;

/* the common shapes */
+ (void)showTitle:(NSString *)title message:(NSString *)message;
+ (void)confirmTitle:(NSString *)title message:(NSString *)message button:(NSString *)button
         destructive:(BOOL)destructive action:(void (^)(void))action;
+ (void)confirmTitle:(NSString *)title message:(NSString *)message button:(NSString *)button
         destructive:(BOOL)destructive action:(void (^)(void))action cancel:(void (^)(void))cancel;
+ (void)promptTitle:(NSString *)title message:(NSString *)message placeholder:(NSString *)placeholder
               text:(NSString *)text button:(NSString *)button done:(void (^)(NSString *value))done;
@end
