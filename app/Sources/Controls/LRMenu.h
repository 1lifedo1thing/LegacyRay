/* an action menu. on the iphone it rises from the bottom as a panel of
   hardware keys; on the ipad it floats next to the control that opened it,
   like a popover, and a tap outside closes it */
#import <UIKit/UIKit.h>

@interface LRMenu : UIView {
    NSString *_title;
    NSMutableArray *_items;    /* NSDictionary: title, style, action */
    UIView *_panel;
    UIView *_dim;
    UIView *_anchor;
    CGRect _anchorRect;
}
+ (LRMenu *)menuWithTitle:(NSString *)title;
- (void)addItem:(NSString *)title action:(void (^)(void))action;
- (void)addDestructiveItem:(NSString *)title action:(void (^)(void))action;
- (NSUInteger)itemCount;
/* anchor may be nil: the menu is then centred (ipad) or at the bottom */
- (void)showFromView:(UIView *)anchor;
- (void)dismiss;
@end
