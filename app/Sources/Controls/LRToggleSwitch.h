/* an illuminated slide switch: a recessed slot, a chunky knurled knob and a
   green lamp on the side the knob uncovers. drop-in for UISwitch (whose look
   changes to the flat ios 7 one even in legacy apps) */
#import <UIKit/UIKit.h>

/* 64x28 slide switch, or the 51x31 ios 7 switch in the flat skin */
CGSize LRToggleSwitchSize(void);
#define LR_TOGGLE_SIZE LRToggleSwitchSize()

@interface LRToggleSwitch : UIControl {
    BOOL _on;
    UIImageView *_knob;
    CGFloat _dragStartX;
    BOOL _dragged;
}
@property (nonatomic, getter = isOn) BOOL on;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end
