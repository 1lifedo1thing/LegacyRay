/* the station log rows: a paper index card per server and a brass plate per
   subscription (flat: plain rows and grey section bars) */
#import <UIKit/UIKit.h>

@class LRServer, LRSection;

@interface LRStationCell : UITableViewCell {
    UIView *_card;
}
- (void)showServer:(LRServer *)server name:(NSString *)name ping:(NSNumber *)ping
          selected:(BOOL)selected live:(BOOL)live margin:(CGFloat)margin last:(BOOL)last;
- (void)showTitle:(NSString *)title detail:(NSString *)detail selected:(BOOL)selected live:(BOOL)live
           margin:(CGFloat)margin last:(BOOL)last;
@end

@interface LRPlateHeaderCell : UITableViewCell {
    UIView *_plate;
}
- (void)showTitle:(NSString *)title country:(NSString *)code meta:(NSString *)meta
        collapsed:(BOOL)collapsed margin:(CGFloat)margin;
@end

#define LR_STATION_ROW_HEIGHT 58.0f
#define LR_PLATE_ROW_HEIGHT 42.0f
