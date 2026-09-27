#import "LRJSON.h"
#include "cJSON.h"

static id LRFromCJSON(const cJSON *item) {
    if (!item) return nil;
    if (cJSON_IsObject(item)) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (const cJSON *c = item->child; c; c = c->next) {
            id v = LRFromCJSON(c);
            NSString *k = c->string ? [NSString stringWithUTF8String:c->string] : nil;
            if (k && v) [d setObject:v forKey:k];
        }
        return d;
    }
    if (cJSON_IsArray(item)) {
        NSMutableArray *a = [NSMutableArray array];
        for (const cJSON *c = item->child; c; c = c->next) {
            id v = LRFromCJSON(c);
            if (v) [a addObject:v];
        }
        return a;
    }
    if (cJSON_IsString(item))
        return item->valuestring ? [NSString stringWithUTF8String:item->valuestring] : @"";
    if (cJSON_IsBool(item)) return [NSNumber numberWithBool:cJSON_IsTrue(item) ? YES : NO];
    if (cJSON_IsNumber(item)) return [NSNumber numberWithDouble:item->valuedouble];
    if (cJSON_IsNull(item)) return [NSNull null];
    return nil;
}

id LRJSONParse(NSData *data) {
    if (![data length]) return nil;
    NSMutableData *z = [NSMutableData dataWithData:data];
    [z appendBytes:"" length:1];
    cJSON *root = cJSON_Parse((const char *)[z bytes]);
    if (!root) return nil;
    id out = LRFromCJSON(root);
    cJSON_Delete(root);
    return out;
}

static cJSON *LRToCJSON(id object) {
    if ([object isKindOfClass:[NSDictionary class]]) {
        cJSON *o = cJSON_CreateObject();
        for (id key in object) {
            if (![key isKindOfClass:[NSString class]]) continue;
            cJSON *v = LRToCJSON([object objectForKey:key]);
            if (v) cJSON_AddItemToObject(o, [key UTF8String], v);
        }
        return o;
    }
    if ([object isKindOfClass:[NSArray class]]) {
        cJSON *a = cJSON_CreateArray();
        for (id v in object) {
            cJSON *c = LRToCJSON(v);
            if (c) cJSON_AddItemToArray(a, c);
        }
        return a;
    }
    if ([object isKindOfClass:[NSString class]]) return cJSON_CreateString([object UTF8String]);
    if ([object isKindOfClass:[NSNumber class]]) {
        const char *t = [object objCType];
        if (t && strcmp(t, @encode(BOOL)) == 0) return cJSON_CreateBool([object boolValue]);
        return cJSON_CreateNumber([object doubleValue]);
    }
    if ([object isKindOfClass:[NSNull class]]) return cJSON_CreateNull();
    return NULL;
}

NSString *LRJSONString(id object) {
    cJSON *root = LRToCJSON(object);
    if (!root) return nil;
    char *text = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    if (!text) return nil;
    NSString *s = [NSString stringWithUTF8String:text];
    free(text);
    return s;
}
