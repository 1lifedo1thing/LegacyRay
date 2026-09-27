/* the vacuum fluorescent display: status headline, the station with its
   flag, the protocol stack, a seven segment session clock and the traffic
   totals, plus small legends that light up like the ones on a receiver */
#import <UIKit/UIKit.h>

@interface LRDisplayView : UIControl {
    NSString *_status;
    NSString *_station;
    NSString *_countryCode;
    NSString *_detail;
    NSString *_message;     /* replaces the detail line, e.g. an error */
    long _seconds;
    NSString *_upText;
    NSString *_downText;
    NSArray *_legends;      /* NSString */
    NSSet *_litLegends;
    BOOL _compact;
    UIImage *_glass;
}
@property (nonatomic, copy) NSString *status;
@property (nonatomic, copy) NSString *station;
@property (nonatomic, copy) NSString *countryCode;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) long seconds;
@property (nonatomic, copy) NSString *upText;
@property (nonatomic, copy) NSString *downText;
@property (nonatomic, retain) NSArray *legends;
@property (nonatomic, retain) NSSet *litLegends;
@property (nonatomic, assign) BOOL compact;
@end
