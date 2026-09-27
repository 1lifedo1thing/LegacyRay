/* routing profiles, happ style: a named set of rules plus the default for
   everything else. they arrive as happ://routing/add/<base64 json> (onadd
   also switches to it), as that json on its own, or from a subscription.
   the lists speak xray's language (geosite:, geoip:, domain:, full:,
   keyword:, cidrs) and are turned into legacyray rules.

   also here: amnezia's site-based split tunnelling lists, which travel as
   json exports or plain text, one site per line */
#import <Foundation/Foundation.h>

extern NSString * const LRRoutingProfilesDidChangeNotification;

@interface LRRoutingProfile : NSObject {
    NSString *_name;
    NSArray *_rules;          /* [action, type, value] */
    NSString *_defaultAction; /* proxy | direct */
    NSString *_remoteDNS;     /* an ipv4 resolver, or nil */
    NSUInteger _skipped;      /* entries legacyray cannot express (regexp, ipv6 ...) */
}
@property (nonatomic, copy) NSString *name;
@property (nonatomic, retain) NSArray *rules;
@property (nonatomic, copy) NSString *defaultAction;
@property (nonatomic, copy) NSString *remoteDNS;
@property (nonatomic, assign) NSUInteger skipped;
- (BOOL)usesGeo;
- (NSDictionary *)dictionary;
+ (LRRoutingProfile *)profileWithDictionary:(NSDictionary *)d;
/* a one line description: "Proxy · 12 rules · geosite:category-ru ..." */
- (NSString *)summary;
/* back to happ's json and link, for sharing */
- (NSDictionary *)happJSON;
- (NSString *)happLink;
@end

@interface LRRoutingProfiles : NSObject
+ (NSArray *)profiles;
+ (NSString *)activeName;
+ (void)save:(LRRoutingProfile *)profile;        /* replaces one of the same name */
+ (void)remove:(LRRoutingProfile *)profile;

/* happ's json (keys in any case); nil and a reason when it is not one */
+ (LRRoutingProfile *)profileFromHappJSON:(id)json error:(NSString **)error;
/* happ://routing/add/... or .../onadd/...; activate tells which */
+ (LRRoutingProfile *)profileFromHappLink:(NSString *)link activate:(BOOL *)activate
                                   error:(NSString **)error;
+ (BOOL)isHappRoutingLink:(NSString *)text;

/* rewrite the daemon's rules to the profile: disconnects first when the
   tunnel is up (the daemon only takes rule changes then), fetches geo data
   the rules need, and reconnects. progress gets short status lines */
+ (void)apply:(LRRoutingProfile *)profile progress:(void (^)(NSString *line))progress
         done:(void (^)(BOOL ok, NSString *message))done;

/* a subscription carrying a routing link the user has not answered yet gets
   one question; the answer is remembered per link */
+ (void)offerProviderRoutingFrom:(NSArray *)subscriptions;

/* the daemon takes rule changes only while no tunnel is up: this takes it
   down if needed, runs work, and brings it back once work calls finish */
+ (void)changeRules:(void (^)(void (^finish)(void)))work;

/* amnezia split tunnelling lists */
+ (NSArray *)sitesFromText:(NSString *)text;     /* hostnames / ips, cleaned */
+ (NSString *)amneziaExportForSites:(NSArray *)sites;
/* one entry of a list as a legacyray rule spec with the given action */
+ (NSArray *)ruleSpecForEntry:(NSString *)entry action:(NSString *)action;
@end
