/* small instruments: an led, radio style signal bars for latency, and a
   glass tube gauge for subscription traffic */
#import <UIKit/UIKit.h>

@interface LRLEDView : UIView {
    UIColor *_color;
    BOOL _on;
}
@property (nonatomic, retain) UIColor *color;
@property (nonatomic, assign) BOOL on;
@end

@interface LRSignalBars : UIView {
    NSInteger _level;     /* 0..5 */
    UIColor *_color;
    BOOL _busy;
}
@property (nonatomic, assign) NSInteger level;
@property (nonatomic, retain) UIColor *color;
@property (nonatomic, assign) BOOL busy;
/* bars and colour for a latency reading (nil = never checked) */
- (void)showPing:(NSNumber *)ms;
@end

@interface LRTubeGauge : UIView {
    double _fraction;   /* 0..1, or < 0 for "no limit" */
}
@property (nonatomic, assign) double fraction;
@end
