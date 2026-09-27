/* the user's own servers, set up and managed over ssh the way the amnezia
   client does it. LRServerHost is one saved server (address, sign-in, the
   host key it answered with the first time); LRSSHJob runs one command of
   Resources/server/lr-server.sh on it through /usr/bin/legacyray-ssh and
   hands back the marked lines the script prints */
#import <Foundation/Foundation.h>

typedef enum {
    LRSSHAuthPassword = 0,
    LRSSHAuthKey
} LRSSHAuth;

@interface LRServerHost : NSObject {
    NSString *_ident;
    NSString *_name;
    NSString *_host;
    NSInteger _port;
    NSString *_user;
    LRSSHAuth _auth;
    NSString *_secret;      /* password, or the private key text */
    NSString *_passphrase;  /* for an encrypted key */
    NSString *_hostKey;     /* sha256, base64, pinned on first contact */
    NSString *_hostKeyType;
    BOOL _hasXray;
    BOOL _hasAWG;
}
@property (nonatomic, copy) NSString *ident;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, copy) NSString *user;
@property (nonatomic, assign) LRSSHAuth auth;
@property (nonatomic, copy) NSString *secret;
@property (nonatomic, copy) NSString *passphrase;
@property (nonatomic, copy) NSString *hostKey;
@property (nonatomic, copy) NSString *hostKeyType;
@property (nonatomic, assign) BOOL hasXray;
@property (nonatomic, assign) BOOL hasAWG;
- (NSString *)displayName;
@end

@interface LRServerHosts : NSObject
+ (NSArray *)hosts;
+ (void)save:(LRServerHost *)host;     /* by ident; the file stays 0600 */
+ (void)remove:(LRServerHost *)host;
@end

extern NSString * const LRServerHostsDidChangeNotification;

/* a marked line from the script: kind is STEP, INFO, LINK, CONF, CLIENT,
   ERROR or DONE; plain output comes as OUT / ERR */
typedef void (^LRSSHLineBlock)(NSString *kind, NSString *text);

@interface LRSSHJob : NSObject {
    int _pid;
    int _out;
    BOOL _cancelled;
}
/* connect, report the host key and stop: the first contact with a server */
+ (void)probeKeyOf:(LRServerHost *)host
              done:(void (^)(NSString *type, NSString *hash, NSString *error))done;

/* run one lr-server.sh command; vars are LR_* values (names, sni, port) and
   are checked against a strict alphabet before they reach the shell */
+ (LRSSHJob *)run:(NSString *)command vars:(NSDictionary *)vars on:(LRServerHost *)host
             line:(LRSSHLineBlock)line done:(void (^)(BOOL ok, NSString *error))done;
- (void)cancel;
@end

/* SHA256:xxxx the way ssh prints it, for the confirmation question */
NSString *LRSSHFingerprint(NSString *hash);
