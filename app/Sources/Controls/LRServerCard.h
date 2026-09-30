/* the station the main screen will connect to: one grouped row laid on the
   denim (classic) or a white card (flat) with the flag, the name, the
   protocol and the latency. a tap opens the stations; a swipe seeks */
#import <UIKit/UIKit.h>

@interface LRServerCard : UIControl {
    NSString *_countryCode;
    NSString *_title;
    NSString *_detail;
    NSString *_value;
    UIColor *_valueColor;
}
@property (nonatomic, copy) NSString *countryCode;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, retain) UIColor *valueColor;
+ (CGFloat)height;
@end
