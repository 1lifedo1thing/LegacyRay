#import "LRRoutingProfiles.h"
#import "LRDaemonClient.h"
#import "LRDaemonSettings.h"
#import "LRTunnel.h"
#import "LRPrefs.h"
#import "LRActivityLog.h"
#import "LRJSON.h"
#import "LRAlert.h"
#import "LRToast.h"
#import "LRModels.h"
#import <arpa/inet.h>
#include "b64.h"

NSString * const LRRoutingProfilesDidChangeNotification = @"LRRoutingProfilesDidChangeNotification";

#define LR_ROUTING_KEY @"LRRoutingProfiles"
#define LR_ROUTING_ACTIVE @"LRRoutingActive"

@implementation LRRoutingProfile
@synthesize name = _name, rules = _rules, defaultAction = _defaultAction, remoteDNS = _remoteDNS,
            skipped = _skipped;

- (void)dealloc {
    [_name release];
    [_rules release];
    [_defaultAction release];
    [_remoteDNS release];
    [super dealloc];
}

- (BOOL)usesGeo {
    for (NSArray *r in _rules) {
        NSString *t = [r objectAtIndex:1];
        if ([t isEqualToString:@"geosite"] || [t isEqualToString:@"geoip"]) return YES;
    }
    return NO;
}

- (NSDictionary *)dictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (_name) [d setObject:_name forKey:@"name"];
    [d setObject:_rules ? _rules : [NSArray array] forKey:@"rules"];
    [d setObject:_defaultAction ? _defaultAction : @"proxy" forKey:@"default"];
    if (_remoteDNS) [d setObject:_remoteDNS forKey:@"dns"];
    [d setObject:[NSNumber numberWithUnsignedInteger:_skipped] forKey:@"skipped"];
    return d;
}

+ (LRRoutingProfile *)profileWithDictionary:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    LRRoutingProfile *p = [[[LRRoutingProfile alloc] init] autorelease];
    p.name = [d objectForKey:@"name"];
    NSArray *rules = [d objectForKey:@"rules"];
    p.rules = [rules isKindOfClass:[NSArray class]] ? rules : [NSArray array];
    p.defaultAction = [[d objectForKey:@"default"] isEqualToString:@"direct"] ? @"direct" : @"proxy";
    p.remoteDNS = [d objectForKey:@"dns"];
    p.skipped = [[d objectForKey:@"skipped"] unsignedIntegerValue];
    return p;
}

- (NSString *)summary {
    NSMutableArray *parts = [NSMutableArray array];
    [parts addObject:[_defaultAction isEqualToString:@"direct"] ? L(@"Direct by default") : L(@"Proxy by default")];
    [parts addObject:[NSString stringWithFormat:@"%lu %@", (unsigned long)[_rules count],
                      LRPlural((NSInteger)[_rules count], L(@"rule"), L(@"rules (few)"), L(@"rules"))]];
    NSMutableArray *geo = [NSMutableArray array];
    for (NSArray *r in _rules) {
        NSString *t = [r objectAtIndex:1];
        if (([t isEqualToString:@"geosite"] || [t isEqualToString:@"geoip"]) && [geo count] < 3)
            [geo addObject:[NSString stringWithFormat:@"%@:%@", t, [r objectAtIndex:2]]];
    }
    if ([geo count]) [parts addObject:[geo componentsJoinedByString:@", "]];
    return [parts componentsJoinedByString:@" · "];
}
- (NSDictionary *)happJSON {
    NSMutableDictionary *lists = [NSMutableDictionary dictionary];
    for (NSString *k in [NSArray arrayWithObjects:@"DirectSites", @"DirectIp", @"ProxySites", @"ProxyIp",
                         @"BlockSites", @"BlockIp", nil])
        [lists setObject:[NSMutableArray array] forKey:k];
    for (NSArray *r in _rules) {
        NSString *action = [r objectAtIndex:0], *type = [r objectAtIndex:1], *value = [r objectAtIndex:2];
        BOOL ip = [type isEqualToString:@"ip-cidr"] || [type isEqualToString:@"geoip"];
        NSString *entry = [type isEqualToString:@"geosite"] ? [@"geosite:" stringByAppendingString:value]
            : [type isEqualToString:@"geoip"] ? [@"geoip:" stringByAppendingString:value]
            : [type isEqualToString:@"domain"] ? [@"full:" stringByAppendingString:value]
            : [type isEqualToString:@"domain-keyword"] ? [@"keyword:" stringByAppendingString:value]
            : [type isEqualToString:@"domain-suffix"] ? [@"domain:" stringByAppendingString:value]
            : [type isEqualToString:@"ip-cidr"] ? value : nil;
        if (!entry) continue;
        NSString *prefix = [action isEqualToString:@"direct"] ? @"Direct"
                         : [action isEqualToString:@"block"] ? @"Block" : @"Proxy";
        [[lists objectForKey:[prefix stringByAppendingString:ip ? @"Ip" : @"Sites"]] addObject:entry];
    }
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:lists];
    [d setObject:_name ? _name : @"LegacyRay" forKey:@"Name"];
    [d setObject:[_defaultAction isEqualToString:@"direct"] ? @"false" : @"true" forKey:@"GlobalProxy"];
    if (_remoteDNS) [d setObject:_remoteDNS forKey:@"RemoteDns"];
    [d setObject:@"IPIfNonMatch" forKey:@"DomainStrategy"];
    return d;
}

- (NSString *)happLink {
    NSString *json = LRJSONString([self happJSON]);
    NSData *raw = [json dataUsingEncoding:NSUTF8StringEncoding];
    size_t cap = b64_encoded_maxlen([raw length]) + 1;
    char *out = malloc(cap);
    size_t n = 0;
    NSString *link = nil;
    if (out && b64_encode([raw bytes], [raw length], out, cap, &n) == 0)
        link = [@"happ://routing/add/" stringByAppendingString:
                [[[NSString alloc] initWithBytes:out length:n encoding:NSASCIIStringEncoding] autorelease]];
    free(out);
    return link;
}
@end

@implementation LRRoutingProfiles

+ (NSArray *)profiles {
    NSMutableArray *list = [NSMutableArray array];
    for (NSDictionary *d in [[NSUserDefaults standardUserDefaults] arrayForKey:LR_ROUTING_KEY]) {
        LRRoutingProfile *p = [LRRoutingProfile profileWithDictionary:d];
        if (p) [list addObject:p];
    }
    return list;
}

+ (NSString *)activeName {
    return [[NSUserDefaults standardUserDefaults] stringForKey:LR_ROUTING_ACTIVE];
}

+ (void)store:(NSArray *)profiles {
    NSMutableArray *out = [NSMutableArray array];
    for (LRRoutingProfile *p in profiles) [out addObject:[p dictionary]];
    [[NSUserDefaults standardUserDefaults] setObject:out forKey:LR_ROUTING_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:LRRoutingProfilesDidChangeNotification object:nil];
}

+ (void)save:(LRRoutingProfile *)profile {
    NSMutableArray *list = [NSMutableArray array];
    for (LRRoutingProfile *p in [self profiles])
        if (![p.name isEqualToString:profile.name]) [list addObject:p];
    [list addObject:profile];
    [self store:list];
}

+ (void)remove:(LRRoutingProfile *)profile {
    NSMutableArray *list = [NSMutableArray array];
    for (LRRoutingProfile *p in [self profiles])
        if (![p.name isEqualToString:profile.name]) [list addObject:p];
    [self store:list];
    if ([[self activeName] isEqualToString:profile.name]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:LR_ROUTING_ACTIVE];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark translation

static BOOL LRIsIPv4Text(NSString *s) {
    struct in_addr a;
    return inet_pton(AF_INET, [s UTF8String], &a) == 1;
}

+ (NSArray *)ruleSpecForEntry:(NSString *)entry action:(NSString *)action {
    NSString *e = LRTrim(entry);
    if (![e length] || [e hasPrefix:@"#"]) return nil;
    NSString *lower = [e lowercaseString];
    NSString *type = nil, *value = nil;
    NSArray *prefixes = [NSArray arrayWithObjects:@"geosite:", @"geoip:", @"domain:", @"full:",
                         @"keyword:", @"dotless:", nil];
    NSArray *types = [NSArray arrayWithObjects:@"geosite", @"geoip", @"domain-suffix", @"domain",
                      @"domain-keyword", @"", nil];
    for (NSUInteger i = 0; i < [prefixes count]; ++i) {
        NSString *p = [prefixes objectAtIndex:i];
        if ([lower hasPrefix:p]) {
            type = [types objectAtIndex:i];
            value = [lower substringFromIndex:[p length]];
            break;
        }
    }
    if ([lower hasPrefix:@"regexp:"] || [lower hasPrefix:@"ext:"] || [lower hasPrefix:@"ext-ip:"])
        return nil;
    if (!type) {
        NSString *ip = e;
        NSRange slash = [ip rangeOfString:@"/"];
        NSString *host = slash.location != NSNotFound ? [ip substringToIndex:slash.location] : ip;
        if (LRIsIPv4Text(host)) {
            type = @"ip-cidr";
            value = slash.location != NSNotFound ? ip : [ip stringByAppendingString:@"/32"];
        } else if ([host rangeOfString:@":"].location != NSNotFound) {
            return nil; /* ipv6: the routing layers are ipv4 */
        } else {
            /* a bare name means the site and everything under it */
            type = @"domain-suffix";
            value = lower;
            if ([value hasPrefix:@"*."]) value = [value substringFromIndex:2];
            if ([value hasPrefix:@"."]) value = [value substringFromIndex:1];
        }
    }
    if (![type length] || ![value length]) return nil;
    if ([value rangeOfString:@" "].location != NSNotFound) return nil;
    return [NSArray arrayWithObjects:action, type, value, nil];
}

static id LRValueCI(NSDictionary *d, NSString *key) {
    for (NSString *k in d)
        if ([k isKindOfClass:[NSString class]] && [k caseInsensitiveCompare:key] == NSOrderedSame)
            return [d objectForKey:k];
    return nil;
}

static BOOL LRTruthy(id v) {
    if ([v isKindOfClass:[NSNumber class]]) return [v boolValue];
    if ([v isKindOfClass:[NSString class]]) {
        NSString *s = [v lowercaseString];
        return [s isEqualToString:@"true"] || [s isEqualToString:@"1"] || [s isEqualToString:@"yes"];
    }
    return NO;
}

static NSArray *LRListValue(id v) {
    if ([v isKindOfClass:[NSArray class]]) return v;
    if ([v isKindOfClass:[NSString class]])
        return [v componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",\n"]];
    return [NSArray array];
}

+ (LRRoutingProfile *)profileFromHappJSON:(id)json error:(NSString **)error {
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) *error = L(@"Not a routing profile");
        return nil;
    }
    NSDictionary *d = json;
    NSArray *keys = [NSArray arrayWithObjects:@"DirectSites", @"DirectIp", @"ProxySites", @"ProxyIp",
                     @"BlockSites", @"BlockIp", nil];
    NSArray *actions = [NSArray arrayWithObjects:@"direct", @"direct", @"proxy", @"proxy",
                        @"block", @"block", nil];
    BOOL any = NO;
    NSMutableArray *rules = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSUInteger skipped = 0;
    for (NSUInteger i = 0; i < [keys count]; ++i) {
        id v = LRValueCI(d, [keys objectAtIndex:i]);
        if (!v) continue;
        any = YES;
        for (id entry in LRListValue(v)) {
            if (![entry isKindOfClass:[NSString class]] || ![LRTrim(entry) length]) continue;
            NSArray *spec = [self ruleSpecForEntry:entry action:[actions objectAtIndex:i]];
            if (!spec) { ++skipped; continue; }
            NSString *k = [[spec subarrayWithRange:NSMakeRange(1, 2)] componentsJoinedByString:@" "];
            if ([seen containsObject:k]) continue;
            [seen addObject:k];
            [rules addObject:spec];
        }
    }
    id global = LRValueCI(d, @"GlobalProxy");
    if (!any && !global) {
        if (error) *error = L(@"Not a routing profile");
        return nil;
    }
    LRRoutingProfile *p = [[[LRRoutingProfile alloc] init] autorelease];
    NSString *name = LRValueCI(d, @"Name");
    p.name = [name isKindOfClass:[NSString class]] && [LRTrim(name) length] ? LRTrim(name) : L(@"Imported routing");
    /* GlobalProxy true: everything through the tunnel except the direct lists */
    p.defaultAction = (!global || LRTruthy(global)) ? @"proxy" : @"direct";
    p.rules = rules;
    p.skipped = skipped;
    for (NSString *k in [NSArray arrayWithObjects:@"RemoteDNSIP", @"RemoteDns", nil]) {
        id dns = LRValueCI(d, k);
        if ([dns isKindOfClass:[NSString class]] && LRIsIPv4Text(LRTrim(dns))) { p.remoteDNS = LRTrim(dns); break; }
    }
    return p;
}

+ (BOOL)isHappRoutingLink:(NSString *)text {
    NSString *l = [LRTrim(text) lowercaseString];
    return [l hasPrefix:@"happ://routing/"];
}

+ (LRRoutingProfile *)profileFromHappLink:(NSString *)link activate:(BOOL *)activate
                                   error:(NSString **)error {
    NSString *s = LRTrim(link);
    NSString *lower = [s lowercaseString];
    NSString *payload = nil;
    BOOL on = NO;
    if ([lower hasPrefix:@"happ://routing/onadd/"]) { payload = [s substringFromIndex:21]; on = YES; }
    else if ([lower hasPrefix:@"happ://routing/add/"]) payload = [s substringFromIndex:19];
    if (activate) *activate = on;
    if (![payload length]) {
        if (error) *error = L(@"Not a routing profile");
        return nil;
    }
    payload = [payload stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ?: payload;
    /* url-safe or not, padded or not */
    NSMutableString *b = [NSMutableString stringWithString:payload];
    [b replaceOccurrencesOfString:@"-" withString:@"+" options:0 range:NSMakeRange(0, [b length])];
    [b replaceOccurrencesOfString:@"_" withString:@"/" options:0 range:NSMakeRange(0, [b length])];
    while ([b length] % 4) [b appendString:@"="];
    NSData *in = [b dataUsingEncoding:NSASCIIStringEncoding];
    size_t cap = b64_decoded_maxlen([in length]) + 1;
    unsigned char *out = malloc(cap);
    size_t n = 0;
    id json = nil;
    if (out && b64_decode([in bytes], [in length], out, cap, &n) == 0) {
        json = LRJSONParse([NSData dataWithBytes:out length:n]);
    }
    free(out);
    if (!json) {
        if (error) *error = L(@"The routing link could not be decoded");
        return nil;
    }
    return [self profileFromHappJSON:json error:error];
}

#pragma mark applying

+ (void)addSpecs:(NSArray *)specs at:(NSUInteger)i failed:(NSUInteger)failed
            done:(void (^)(NSUInteger failed))done {
    if (i >= [specs count]) { done(failed); return; }
    NSArray *spec = [specs objectAtIndex:i];
    [[LRDaemonClient shared] addRuleAction:[spec objectAtIndex:0] type:[spec objectAtIndex:1]
                                     value:[spec objectAtIndex:2] reply:^(NSString *reply) {
        [self addSpecs:specs at:i + 1 failed:failed + (LRReplyIsOK(reply) ? 0 : 1) done:done];
    }];
}

+ (void)apply:(LRRoutingProfile *)profile progress:(void (^)(NSString *))progress
         done:(void (^)(BOOL, NSString *))done {
    void (^say)(NSString *) = [[progress copy] autorelease];
    void (^finish)(BOOL, NSString *) = [[done copy] autorelease];
    LRRoutingProfile *p = [[profile retain] autorelease];
    LRTunnel *t = [LRTunnel shared];
    BOOL reconnect = [t isOn] && t.activeBackend == LRBackendServer;
    LRDaemonClient *client = [LRDaemonClient shared];

    void (^afterGeo)(NSString *) = ^(NSString *geoNote) {
        [[NSUserDefaults standardUserDefaults] setObject:p.name forKey:LR_ROUTING_ACTIVE];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[NSNotificationCenter defaultCenter] postNotificationName:LRRoutingProfilesDidChangeNotification object:nil];
        [[LRDaemonSettings shared] refresh];
        LRLog(@"routing", @"profile applied (%lu rules)", (unsigned long)[p.rules count]);
        if (reconnect) {
            if (say) say(L(@"Reconnecting..."));
            [t connect];
        }
        finish(YES, geoNote);
    };

    void (^rules)(void) = ^{
        if (say) say(L(@"Writing rules..."));
        [client flushTarget:@"rules" reply:^(NSString *reply) {
            [LRRoutingProfiles addSpecs:p.rules at:0 failed:0 done:^(NSUInteger failed) {
                [client setSetting:@"rules_enabled" value:@"1" reply:nil];
                [client setSetting:@"rules_default" value:p.defaultAction reply:nil];
                if (p.remoteDNS) [client setSetting:@"dns_upstream" value:p.remoteDNS reply:nil];
                NSString *note = failed ? [NSString stringWithFormat:L(@"%lu rules were not accepted"),
                                           (unsigned long)failed] : nil;
                if (![p usesGeo]) { afterGeo(note); return; }
                if (say) say(L(@"Downloading geo data..."));
                [client geoUpdate:^(NSArray *lines, NSString *summary, BOOL ok) {
                    afterGeo(ok ? note : (summary ? summary : L(@"Geo data could not be downloaded")));
                }];
            }];
        }];
    };

    if (reconnect) {
        if (say) say(L(@"Disconnecting..."));
        [client disconnect:^(NSString *reply) {
            [t pollNow];
            rules();
        }];
    } else {
        rules();
    }
}

+ (void)offerProviderRoutingFrom:(NSArray *)subscriptions {
    static BOOL asking = NO;
    if (asking) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *seen = [NSMutableDictionary dictionaryWithDictionary:
                                 [ud dictionaryForKey:@"LRSeenRouting"] ?: [NSDictionary dictionary]];
    for (LRSubscription *sub in subscriptions) {
        NSString *link = sub.routingLink;
        if (![link length] || !sub.url) continue;
        NSString *mark = [NSString stringWithFormat:@"%lu", (unsigned long)[link hash]];
        if ([[seen objectForKey:sub.url] isEqualToString:mark]) continue;
        [seen setObject:mark forKey:sub.url];
        [ud setObject:seen forKey:@"LRSeenRouting"];
        [ud synchronize];
        NSString *error = nil;
        BOOL activate = NO;
        LRRoutingProfile *p = [self profileFromHappLink:link activate:&activate error:&error];
        if (!p) {
            /* some panels send the bare base64 */
            p = [self profileFromHappLink:[@"happ://routing/add/" stringByAppendingString:link]
                                 activate:&activate error:&error];
        }
        if (!p) continue;
        [self save:p];
        asking = YES;
        NSString *who = [sub.name length] ? sub.name : L(@"Subscription");
        [LRAlert confirmTitle:[NSString stringWithFormat:L(@"“%@” offers routing"), who]
                      message:[NSString stringWithFormat:@"%@\n%@", p.name, [p summary]]
                       button:L(@"Apply") destructive:NO action:^{
            asking = NO;
            [LRRoutingProfiles apply:p progress:nil done:^(BOOL ok, NSString *message) {
                if (message) [LRToast showError:message];
                else [LRToast showSuccess:L(@"Routing profile applied")];
            }];
        } cancel:^{ asking = NO; }];
        return; /* one question at a time */
    }
}

+ (void)changeRules:(void (^)(void (^finish)(void)))work {
    void (^job)(void (^)(void)) = [[work copy] autorelease];
    LRTunnel *t = [LRTunnel shared];
    BOOL reconnect = [t isOn] && t.activeBackend == LRBackendServer;
    void (^finish)(void) = [[^{
        if (reconnect) [[LRTunnel shared] connect];
    } copy] autorelease];
    if (!reconnect) { job(finish); return; }
    [[LRDaemonClient shared] disconnect:^(NSString *reply) {
        [[LRTunnel shared] pollNow];
        job(finish);
    }];
}

#pragma mark amnezia lists

+ (NSArray *)sitesFromText:(NSString *)text {
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    id json = data ? LRJSONParse(data) : nil;
    NSMutableArray *raw = [NSMutableArray array];
    if ([json isKindOfClass:[NSArray class]]) {
        /* amnezia exports [{"hostname": "...", "ip": "..."}] */
        for (id item in json) {
            if ([item isKindOfClass:[NSString class]]) [raw addObject:item];
            else if ([item isKindOfClass:[NSDictionary class]]) {
                id host = LRValueCI(item, @"hostname");
                id ip = LRValueCI(item, @"ip");
                if ([host isKindOfClass:[NSString class]] && [host length]) [raw addObject:host];
                else if ([ip isKindOfClass:[NSString class]] && [ip length]) [raw addObject:ip];
            }
        }
    } else {
        [raw addObjectsFromArray:[text componentsSeparatedByCharactersInSet:
                                  [NSCharacterSet characterSetWithCharactersInString:@"\n\r,;"]]];
    }
    for (NSString *r in raw) {
        NSString *s = [LRTrim(r) lowercaseString];
        if (![s length] || [s hasPrefix:@"#"]) continue;
        /* a pasted url keeps only its host */
        NSRange scheme = [s rangeOfString:@"://"];
        if (scheme.location != NSNotFound) s = [s substringFromIndex:scheme.location + 3];
        NSRange path = [s rangeOfString:@"/"];
        if (path.location != NSNotFound && !LRIsIPv4Text([s substringToIndex:path.location]))
            s = [s substringToIndex:path.location];
        if (![s length] || [seen containsObject:s]) continue;
        [seen addObject:s];
        [out addObject:s];
    }
    return out;
}

+ (NSString *)amneziaExportForSites:(NSArray *)sites {
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *s in sites) {
        NSString *host = [s hasSuffix:@"/32"] ? [s substringToIndex:[s length] - 3] : s;
        BOOL ip = LRIsIPv4Text([[host componentsSeparatedByString:@"/"] objectAtIndex:0]);
        [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:ip ? @"" : host, @"hostname",
                          ip ? host : @"", @"ip", nil]];
    }
    return LRJSONString(items);
}
@end
