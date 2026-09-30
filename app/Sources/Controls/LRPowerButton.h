/* the one button of the main screen. classic: a pearl cap sewn into the
   denim (a copper stitched ring, a soft well) whose engraved glyph lights up
   with the tunnel: grey at rest, amber while connecting, green when on, red
   on a fault. flat: the ios 7 disc in a thin ring */
#import <UIKit/UIKit.h>

typedef enum {
    LRPowerOff = 0,
    LRPowerTuning,
    LRPowerOn,
    LRPowerFault
} LRPowerState;

@interface LRPowerButton : UIControl {
    LRPowerState _powerState;
    CAShapeLayer *_ring;      /* flat */
    UIImageView *_cap;
    UIImageView *_glyph;
    CGFloat _builtFor;
}
@property (nonatomic, assign) LRPowerState powerState;
/* the button's radius for a frame this size, and the size a radius needs */
+ (CGFloat)radiusForSide:(CGFloat)side;
+ (CGFloat)sideForRadius:(CGFloat)radius;
@end
