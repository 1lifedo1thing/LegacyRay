#import "LRKaring.h"
#import "LRZip.h"
#include "cJSON.h"
#include <arpa/inet.h>

static NSString *LRJSONString(cJSON *obj, const char *key) {
    cJSON *v = cJSON_GetObjectItemCaseSensitive(obj, key);
    return cJSON_IsString(v) && v->valuestring ? LRTrim([NSString stringWithUTF8String:v->valuestring]) : nil;
}

NSArray *LRKaringSubscriptionsFromBackup(NSData *zip, NSString **error) {
    NSData *json = LRZipEntryNamed(zip, @"karing_subscribe.json", error);
    if (!json) return nil;
    NSMutableData *text = [NSMutableData dataWithData:json];
    [text appendBytes:"\0" length:1];
    cJSON *root = cJSON_Parse([text bytes]);
    if (!root) {
        if (error) *error = @"the karing backup contains invalid json";
        return nil;
    }
    cJSON *items = cJSON_GetObjectItemCaseSensitive(root, "items");
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    cJSON *item = NULL;
    if (cJSON_IsArray(items)) {
        cJSON_ArrayForEach(item, items) {
            if (!cJSON_IsObject(item)) continue;
            NSString *url = LRJSONString(item, "urlOrPath");
            if (!url) url = LRJSONString(item, "url");
            NSString *lower = [url lowercaseString];
            if (!([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"]) || [seen containsObject:url])
                continue;
            [seen addObject:url];
            NSString *name = LRJSONString(item, "remark");
            if (!name) name = LRJSONString(item, "name");
            if (!name) name = LRJSONString(item, "title");
            NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObject:url forKey:@"url"];
            if (name) [d setObject:name forKey:@"name"];
            [out addObject:d];
        }
    }
    cJSON_Delete(root);
    if (![out count] && error) *error = @"the karing backup has no http subscriptions";
    return [out count] ? out : nil;
}

BOOL LRKaringIsLANLink(NSString *text) {
    return [[LRTrim(text) lowercaseString] hasPrefix:@"karing://sync-download"];
}

static BOOL LRPrivateIPv4(NSString *host) {
    struct in_addr a;
    if (inet_pton(AF_INET, [host UTF8String], &a) != 1) return NO;
    uint32_t ip = ntohl(a.s_addr);
    return (ip & 0xff000000U) == 0x0a000000U || (ip & 0xffc00000U) == 0x64400000U ||
           (ip & 0xfff00000U) == 0xac100000U || (ip & 0xffff0000U) == 0xc0a80000U ||
           (ip & 0xffff0000U) == 0xa9fe0000U;
}

void LRKaringFetchLAN(NSString *link, void (^done)(NSData *, NSString *)) {
    void (^callback)(NSData *, NSString *) = [[done copy] autorelease];
    NSString *text = LRTrim(link);
    NSRange q = [text rangeOfString:@"?"];
    NSMutableArray *hosts = [NSMutableArray array];
    NSInteger port = 0;
    if (q.location != NSNotFound) {
        for (NSString *pair in [[text substringFromIndex:q.location + 1] componentsSeparatedByString:@"&"]) {
            NSRange eq = [pair rangeOfString:@"="];
            if (eq.location == NSNotFound) continue;
            NSString *k = [pair substringToIndex:eq.location];
            NSString *v = [[pair substringFromIndex:eq.location + 1]
                           stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            if ([k isEqualToString:@"port"]) port = [v integerValue];
            if ([k isEqualToString:@"ips"])
                for (NSString *h in [v componentsSeparatedByString:@","]) {
                    NSString *t = LRTrim(h);
                    if (t && LRPrivateIPv4(t) && ![hosts containsObject:t]) [hosts addObject:t];
                }
        }
    }
    if (![hosts count] || port < 1 || port > 65535) {
        if (callback) callback(nil, @"the karing QR code has no local address");
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSData *body = nil;
        NSString *lastError = nil;
        for (NSString *host in hosts) {
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%ld/sync-download",
                                               host, (long)port]];
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                           timeoutInterval:20];
            [req setValue:@"close" forHTTPHeaderField:@"Connection"];
            NSHTTPURLResponse *resp = nil;
            NSError *err = nil;
            NSData *d = [NSURLConnection sendSynchronousRequest:req returningResponse:(NSURLResponse **)&resp
                                                          error:&err];
            if (d && [resp statusCode] == 200 && [d length]) {
                body = [d retain];
                break;
            }
            lastError = err ? [err localizedDescription]
                            : [NSString stringWithFormat:@"karing answered http %ld", (long)[resp statusCode]];
        }
        NSString *e = [lastError copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (callback) callback(body, body ? nil : (e ? e : @"karing did not answer"));
            [body release];
            [e release];
        });
        [pool drain];
    });
}
