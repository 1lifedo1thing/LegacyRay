/* one subscription: the panel's usage figures and dates, its links, the
   device id and user agent it is fetched with, and what can be done with it */
#import "LRTableScreen.h"
#import "LRModels.h"

@interface LRSubscriptionScreen : LRTableScreen {
    LRSubscription *_sub;
    NSString *_hwid;
    BOOL _updating;
}
- (id)initWithSubscription:(LRSubscription *)sub;
@end
