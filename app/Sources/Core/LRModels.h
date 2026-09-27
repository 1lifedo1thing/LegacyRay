/* what the daemon reports, as plain objects. the daemon owns every piece of
   this state; the app rebuilds these from each LIST / RULES / DIAG answer */
#import <Foundation/Foundation.h>

@interface LRServer : NSObject {
    int _index;
    BOOL _selected;
    int _group;
    NSString *_proto;
    NSString *_net;
    NSString *_security;
    BOOL _supported;
    NSString *_host;
    int _port;
    NSString *_remark;
}
@property (nonatomic, assign) int index;
@property (nonatomic, assign) BOOL selected;
/* the subscription index that owns this server, -1 for manual servers */
@property (nonatomic, assign) int group;
@property (nonatomic, copy) NSString *proto;
@property (nonatomic, copy) NSString *net;
@property (nonatomic, copy) NSString *security;
@property (nonatomic, assign) BOOL supported;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) int port;
@property (nonatomic, copy) NSString *remark;

/* the remark without flag emoji and panel noise, never empty */
- (NSString *)displayName;
/* iso 3166 alpha-2 code for the flag, from regional indicator emoji or a
   leading country code in the remark; nil when there is none */
- (NSString *)countryCode;
/* "VLESS · REALITY · XHTTP" */
- (NSString *)protocolSummary;
@end

@interface LRSubscription : NSObject {
    int _index;
    NSString *_name;
    NSString *_url;
    NSString *_header;
    unsigned long long _expire;
    unsigned long long _upload;
    unsigned long long _download;
    unsigned long long _total;
    NSString *_summary;
    NSString *_supportURL;
    unsigned int _updateIntervalHours;
    unsigned long long _refillDate;
    NSString *_webPageURL;
    NSString *_routingLink;
}
@property (nonatomic, assign) int index;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *header;
@property (nonatomic, assign) unsigned long long expire;
@property (nonatomic, assign) unsigned long long upload;
@property (nonatomic, assign) unsigned long long download;
@property (nonatomic, assign) unsigned long long total;
/* the panel's description / announce text */
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy) NSString *supportURL;
@property (nonatomic, assign) unsigned int updateIntervalHours;
@property (nonatomic, assign) unsigned long long refillDate;
@property (nonatomic, copy) NSString *webPageURL;
/* a happ routing profile the panel offers with the feed, or nil */
@property (nonatomic, copy) NSString *routingLink;

- (unsigned long long)used;
/* 0..1, or -1 when the panel sets no limit */
- (double)usageFraction;
/* days until expiry, rounded up; NSIntegerMax without an expiry */
- (NSInteger)daysLeft;
@end

@interface LRRule : NSObject {
    int _index;
    NSString *_action;
    NSString *_type;
    NSString *_value;
    unsigned long long _hits;
}
@property (nonatomic, assign) int index;
/* proxy | direct | block */
@property (nonatomic, copy) NSString *action;
/* domain-suffix | domain-keyword | domain | ip-cidr | port */
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, assign) unsigned long long hits;
@end

@interface LRDiagFact : NSObject {
    NSString *_key;
    NSString *_value;
}
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *value;
@end

@interface LRCheckStage : NSObject {
    NSString *_name;
    int _ms;
    BOOL _ok;
}
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) int ms;
@property (nonatomic, assign) BOOL ok;
@end
