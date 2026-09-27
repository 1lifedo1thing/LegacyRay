/* one server: what it is, how fast it answers (tcp, handshake, real http
   delay, with the stages of the last check), and what can be done with it */
#import "LRTableScreen.h"
#import "LRModels.h"

@interface LRStationScreen : LRTableScreen {
    LRServer *_server;
    NSMutableDictionary *_results;   /* mode -> NSString */
    NSArray *_stages;
    NSString *_stagesMode;
    NSMutableSet *_running;
}
- (id)initWithServer:(LRServer *)server;
@end
