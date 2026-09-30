/* routing profiles, happ style: a named set of rules plus the default for
   everything else. they arrive as happ://routing/add/<base64 json> (onadd
   also switches to it), as that json on its own, or from a subscription.
   the lists speak xray's language (geosite:, geoip:, domain:, full:,
   keyword:, cidrs) and are turned into legacyray rules.

   also here: amnezia's site-based split tunnelling lists, which travel as
   json exports or plain text, one site per line */
#import <Foundation/Foundation.h>

extern NSString * const LRRoutingProfilesDidChangeNotification;

/* how a split tunnelling site is matched (lr_site.h) */
typedef enum {
    LRSiteExact = 0,   /* a specific domain: xyz.abc.com, every page of it, nothing else */
    LRSiteHead         /* the head domain: abc.com and every name under it */
} LRSiteMode;

/* what lr_site_parse made of an entry */
typedef enum {
    LRSiteName = 0,
    LRSiteAddress,
    LRSiteRange
} LRSiteKind;

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

/* split tunnelling sites. siteHost: what a typed or pasted site is (a url,
   "*.abc.com", "пример.рф"...) as the ascii host a rule matches, or nil */
+ (NSString *)siteHost:(NSString *)input kind:(LRSiteKind *)kind wildcard:(BOOL *)wildcard;
/* music.youtube.com -> youtube.com, news.bbc.co.uk -> bbc.co.uk */
+ (NSString *)headDomain:(NSString *)host;
/* xn-- names back in their own letters, for showing */
+ (NSString *)displaySite:(NSString *)host;
/* the rule for a site in a mode: [action, type, value]; a "*." site is its
   own head domain whatever the mode; nil when it is not a site */
+ (NSArray *)ruleSpecForSite:(NSString *)input mode:(LRSiteMode)mode action:(NSString *)action;
/* how a saved rule reads, the way the ui writes it: xyz.abc.com, then a
   slash and a star, for a specific domain; star-dot-abc.com and the same for
   a head domain; an address range as it is */
+ (NSString *)patternForRuleType:(NSString *)type value:(NSString *)value;

/* amnezia split tunnelling lists */
+ (NSArray *)sitesFromText:(NSString *)text;     /* hostnames / ips, cleaned */
/* specs are [type, value]: a head domain goes out as "*.abc.com" */
+ (NSString *)amneziaExportForRuleSpecs:(NSArray *)specs;
/* one entry of a list as a legacyray rule spec with the given action */
+ (NSArray *)ruleSpecForEntry:(NSString *)entry action:(NSString *)action;
@end
