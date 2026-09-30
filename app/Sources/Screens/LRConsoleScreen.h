/* the main screen: one button, what the tunnel is doing under it, and the
   station it connects to. lays itself out for whatever box it gets: a phone
   screen or the right pane of the ipad */
#import "LRScreen.h"

@class LRPowerButton, LRServerCard;

@interface LRConsoleScreen : LRScreen {
    LRPowerButton *_power;
    UILabel *_status;
    UILabel *_detail;
    LRServerCard *_card;
    BOOL _embedded;
    BOOL _stale;                /* something changed while off screen */
    NSString *_shownError;
}
/* inside the ipad split the stations are beside the console: the card opens
   the station's details and the bar has a Check key instead of Add */
@property (nonatomic, assign) BOOL embedded;
@end
