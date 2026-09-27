/* translations. generated keys come from the L(@"...") calls in the sources;
   scripts/check_strings.py lists the ones that have no russian yet */
#import "LRLocalization.h"

typedef struct {
    const char *en;
    const char *ru;
    const char *zh;
} LRStringEntry;

static const LRStringEntry kStrings[] = {
#include "LRStrings.inc"
    { NULL, NULL, NULL }
};

NSString *LRStringsLookup(NSString *english, LRLanguage language) {
    static NSDictionary *ru = nil, *zh = nil;
    if (!ru) {
        NSMutableDictionary *r = [NSMutableDictionary dictionary];
        NSMutableDictionary *z = [NSMutableDictionary dictionary];
        for (const LRStringEntry *e = kStrings; e->en; ++e) {
            NSString *key = [NSString stringWithUTF8String:e->en];
            if (!key) continue;
            if (e->ru && e->ru[0]) {
                NSString *v = [NSString stringWithUTF8String:e->ru];
                if (v) [r setObject:v forKey:key];
            }
            if (e->zh && e->zh[0]) {
                NSString *v = [NSString stringWithUTF8String:e->zh];
                if (v) [z setObject:v forKey:key];
            }
        }
        ru = [r copy];
        zh = [z copy];
    }
    if (language == LRLanguageRussian) return [ru objectForKey:english];
    if (language == LRLanguageChinese) return [zh objectForKey:english];
    return nil;
}
