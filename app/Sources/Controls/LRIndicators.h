/* a progress gauge for subscription traffic and installs: the ios 6 bar (a
   sunken grey track, a glossy blue fill that turns amber and red towards
   the limit), or the ios 7 hairline one */
#import <UIKit/UIKit.h>

@interface LRTubeGauge : UIView {
    double _fraction;   /* 0..1, or < 0 for "no limit" */
}
@property (nonatomic, assign) double fraction;
@end
