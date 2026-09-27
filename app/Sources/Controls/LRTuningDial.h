/* the receiver's dial window: a lit glass scale with a mark for every
   station and a red pointer on the selected one. tap or drag to tune; the
   control sends UIControlEventValueChanged with selectedIndex set */
#import <UIKit/UIKit.h>

@interface LRTuningDial : UIControl {
    NSArray *_labels;
    NSInteger _selectedIndex;
    NSInteger _trackingIndex;
    CALayer *_pointer;
    UIImage *_background;
}
@property (nonatomic, retain) NSArray *labels;   /* short station labels */
@property (nonatomic, assign) NSInteger selectedIndex;
- (void)setSelectedIndex:(NSInteger)index animated:(BOOL)animated;
@end
