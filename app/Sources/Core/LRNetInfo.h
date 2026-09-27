/* what the device is connected to, for the display legends and diagnostics */
#import <Foundation/Foundation.h>

@interface LRNetInfo : NSObject
/* "Wi-Fi", "Cellular" or "Offline" */
+ (NSString *)interfaceKind;
+ (BOOL)online;
+ (NSString *)localIPv4;
/* the joined wi-fi name (ios 4.1+), nil elsewhere */
+ (NSString *)wifiName;
@end
