/* the receiver: display, tuning dial, the two meters, the power knob with the
   seek keys, the quick switches and the front panel keys. lays itself out for
   whatever box it gets: a phone screen, the right half of a landscape ipad or
   the top of a portrait one */
#import "LRScreen.h"

@class LRDisplayView, LRTuningDial, LRVUMeter, LRPowerButton, LRToggleSwitch;

@interface LRConsoleScreen : LRScreen {
    UIView *_decor;
    LRDisplayView *_display;
    LRTuningDial *_dial;
    LRVUMeter *_upMeter;
    LRVUMeter *_downMeter;
    LRPowerButton *_power;
    LRButton *_seekBack;
    LRButton *_seekForward;
    UILabel *_powerCaption;
    UILabel *_seekCaptions[2];
    NSArray *_toggles;          /* LRToggleSwitch */
    NSArray *_toggleCaptions;   /* UILabel */
    NSArray *_keys;             /* LRButton, the front panel keys */
    NSArray *_dialServers;
    BOOL _embedded;
    BOOL _stale;                /* something changed while off screen */
    NSString *_shownError;
}
/* inside the ipad split the station log is beside the console, so the keys
   change: no STATIONS key, a CHECK key instead */
@property (nonatomic, assign) BOOL embedded;
@end
