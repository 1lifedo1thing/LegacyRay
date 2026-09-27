/* updates: check github for a newer release, the daily check, github legacy,
   and installing a downloaded .deb */
#import "LRTableScreen.h"
#import "LRUpdateChecker.h"

@interface LRUpdatesScreen : LRTableScreen {
    LRRelease *_release;
    NSString *_status;
    BOOL _checking;
}
@end
