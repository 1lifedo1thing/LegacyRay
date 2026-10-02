/* the station list rows, set like the ios 6 wi-fi list: a check mark by the
   chosen station (green while connected), the flag, the name and protocol,
   the latency and the blue detail key; subscriptions are section captions
   that fold. flat: the ios 7 rows and grey section bars */
#import <UIKit/UIKit.h>
#import "LRDraw.h"

@class LRServer, LRSection;

@interface LRStationCell : UITableViewCell {
    UIView *_card;
    UIButton *_info;
    void (^_infoAction)(void);
}
/* the detail key; no action, no key */
@property (nonatomic, copy) void (^infoAction)(void);
- (void)showServer:(LRServer *)server name:(NSString *)name ping:(NSNumber *)ping
          selected:(BOOL)selected live:(BOOL)live margin:(CGFloat)margin position:(LRPlatePosition)position;
- (void)showTitle:(NSString *)title detail:(NSString *)detail selected:(BOOL)selected live:(BOOL)live
           margin:(CGFloat)margin position:(LRPlatePosition)position;
@end

@interface LRPlateHeaderCell : UITableViewCell {
    UIView *_plate;
}
/* usage and note are the caption lines under a subscription's name: its
   traffic and time, then the provider's own description */
- (void)showTitle:(NSString *)title country:(NSString *)code meta:(NSString *)meta
            usage:(NSString *)usage note:(NSString *)note
        collapsed:(BOOL)collapsed margin:(CGFloat)margin;
+ (CGFloat)heightWithCountry:(NSString *)code usage:(NSString *)usage note:(NSString *)note
                       width:(CGFloat)width margin:(CGFloat)margin;
@end

#define LR_STATION_ROW_HEIGHT 56.0f
#define LR_PLATE_ROW_HEIGHT 44.0f
