/* a backlit moving-coil meter: cream (or amber) scale, red zone, black
   needle with a little spring in it. value is 0..1; setSpeed maps a byte
   rate onto the log scale printed on the face (1K .. 10M) */
#import <UIKit/UIKit.h>

@interface LRVUMeter : UIView {
    NSString *_caption;
    UIView *_well;
    CALayer *_needle;
    CALayer *_needleShadow;
    UIImageView *_glass;
    double _value;
    double _target;
    double _velocity;
    id _link;
}
@property (nonatomic, copy) NSString *caption;
- (void)setValue:(double)value animated:(BOOL)animated;
- (void)setSpeed:(double)bytesPerSecond;
@end
