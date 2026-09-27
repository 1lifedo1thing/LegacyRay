/* the big knob: machined chrome cap, knurled skirt and an led ring that says
   what the tunnel is doing (red standby, pulsing amber tuning, green on) */
#import <UIKit/UIKit.h>

typedef enum {
    LRPowerOff = 0,
    LRPowerTuning,
    LRPowerOn,
    LRPowerFault
} LRPowerState;

@interface LRPowerButton : UIControl {
    LRPowerState _powerState;
    CAShapeLayer *_ring;
    UIImageView *_skirt;
    UIImageView *_cap;
}
@property (nonatomic, assign) LRPowerState powerState;
@end
