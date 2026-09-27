/* "your own server", amnezia style: LegacyRay signs in to a VPS over ssh,
   installs Xray Reality and / or AmneziaWG, hands the connections to this
   phone and keeps managing them: status, clients to share, restart, removal */
#import "LRTableScreen.h"

@class LRServerHost;
@class LRSSHJob;

@interface LRServersScreen : LRTableScreen
@end

/* the setup form, then the install with a live log */
@interface LRServerSetupScreen : LRTableScreen {
    LRServerHost *_host;
    BOOL _xray;
    BOOL _awg;
    NSString *_sni;
    BOOL _working;
}
@end

/* one saved server */
@interface LRServerScreen : LRTableScreen {
    LRServerHost *_host;
    NSMutableDictionary *_info;
    NSMutableArray *_clients;   /* [proto, name] */
    NSString *_status;
    BOOL _loading;
    LRSSHJob *_job;
}
- (id)initWithHost:(LRServerHost *)host;
@end

/* a running command's output, line by line */
@interface LRServerLogScreen : LRScreen {
    UITextView *_log;
    UILabel *_stage;
    NSMutableString *_text;
    LRSSHJob *_job;
}
- (void)appendLine:(NSString *)line;
- (void)setStage:(NSString *)stage;
@property (nonatomic, retain) LRSSHJob *job;
@end
