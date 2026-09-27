/* transient messages as embossed label-maker tape that drops in from the top:
   black tape for news, red for errors, green for things that worked */
#import <UIKit/UIKit.h>

@interface LRToast : UIView {
    NSString *_text;
    UIColor *_tape;
}
+ (void)show:(NSString *)text;
+ (void)showError:(NSString *)text;
+ (void)showSuccess:(NSString *)text;
@end
