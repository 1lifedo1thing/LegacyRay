/* a switch. classic: the ios 6 one (a blue ON / grey OFF track that slides
   under a round knob), drawn so it looks the same on ios 4, 5 and 6 and
   under the classic theme on ios 7; flat: the ios 7 one. drop-in for
   UISwitch, whose look changes with the system */
#import <UIKit/UIKit.h>

/* 79x27 ios 6 switch, or the 51x31 ios 7 one in the flat skin */
CGSize LRToggleSwitchSize(void);
#define LR_TOGGLE_SIZE LRToggleSwitchSize()

@interface LRToggleSwitch : UIControl {
    BOOL _on;
    UIImageView *_knob;
    UIView *_clip;          /* classic: the rounded window the track slides in */
    UIImageView *_track;
    UIImageView *_rim;
    CGFloat _dragStartX;
    BOOL _dragged;
}
@property (nonatomic, getter = isOn) BOOL on;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end
