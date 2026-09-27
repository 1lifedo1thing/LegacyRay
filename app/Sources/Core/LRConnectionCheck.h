/* the connection quality check: is the daemon there, is there a network, does
   dns answer, does the server complete a handshake, does http work through the
   tunnel, and does the device's normal path leave through the same exit (if
   it does not, traffic is leaking around the tunnel) */
#import <Foundation/Foundation.h>

typedef enum {
    LRCheckPending = 0,
    LRCheckRunning,
    LRCheckPassed,
    LRCheckWarning,
    LRCheckFailed,
    LRCheckSkipped
} LRCheckResult;

@interface LRCheckStep : NSObject {
    NSString *_name;
    NSString *_detail;
    LRCheckResult _result;
    int _ms;
}
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, assign) LRCheckResult result;
@property (nonatomic, assign) int ms;
@end

@interface LRConnectionCheck : NSObject {
    NSMutableArray *_steps;
    NSString *_verdict;
    LRCheckResult _overall;
    BOOL _running;
    BOOL _cancelled;
    void (^_update)(LRConnectionCheck *check);
    NSString *_tunnelIP;
    NSString *_directIP;
}
@property (nonatomic, readonly) NSArray *steps;
@property (nonatomic, readonly) NSString *verdict;
@property (nonatomic, readonly) LRCheckResult overall;
@property (nonatomic, readonly) BOOL running;

- (void)startWithUpdate:(void (^)(LRConnectionCheck *check))update;
- (void)cancel;
/* the report text for the diagnostics bundle */
- (NSString *)textReport;
@end

/* one http GET of a small plain text resource, directly or through a SOCKS5
   proxy on 127.0.0.1; returns the body or nil and fills *error. blocking */
NSString *LRHTTPGetText(NSString *host, NSString *path, int socksPort, int timeoutMs,
                        int *elapsedMs, NSString **error);
