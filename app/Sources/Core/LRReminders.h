/* local notifications a few days before a subscription runs out, the way
   happ reminds you to renew. rebuilt from the catalog on every reload */
#import <Foundation/Foundation.h>

@interface LRReminders : NSObject
+ (BOOL)enabled;
+ (void)setEnabled:(BOOL)on;
+ (void)scheduleForSubscriptions:(NSArray *)subscriptions;
@end
