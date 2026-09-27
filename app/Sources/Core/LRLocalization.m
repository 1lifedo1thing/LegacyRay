#import "LRLocalization.h"

NSString * const LRLanguageDidChangeNotification = @"LRLanguageDidChangeNotification";
static NSString * const kLanguageKey = @"LRLanguage";

LRLanguage LRLanguageSetting(void) {
    NSInteger v = [[NSUserDefaults standardUserDefaults] integerForKey:kLanguageKey];
    if (v < LRLanguageAuto || v > LRLanguageChinese) v = LRLanguageAuto;
    return (LRLanguage)v;
}

void LRSetLanguageSetting(LRLanguage language) {
    [[NSUserDefaults standardUserDefaults] setInteger:language forKey:kLanguageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:LRLanguageDidChangeNotification
                                                        object:nil];
}

LRLanguage LRCurrentLanguage(void) {
    LRLanguage setting = LRLanguageSetting();
    if (setting != LRLanguageAuto) return setting;
    NSArray *preferred = [NSLocale preferredLanguages];
    NSString *first = [preferred count] ? [[preferred objectAtIndex:0] lowercaseString] : @"en";
    if ([first hasPrefix:@"ru"] || [first hasPrefix:@"uk"] || [first hasPrefix:@"be"] ||
        [first hasPrefix:@"kk"])
        return LRLanguageRussian;
    if ([first hasPrefix:@"zh"]) return LRLanguageChinese;
    return LRLanguageEnglish;
}

NSString *LRLanguageName(LRLanguage language) {
    switch (language) {
        case LRLanguageEnglish: return @"English";
        case LRLanguageRussian: return @"Русский";
        case LRLanguageChinese: return @"中文";
        case LRLanguageAuto: break;
    }
    return LRLocalized(@"System");
}

NSString *LRLocalized(NSString *english) {
    if (![english length]) return english;
    LRLanguage language = LRCurrentLanguage();
    if (language == LRLanguageEnglish) return english;
    NSString *hit = LRStringsLookup(english, language);
    return hit ? hit : english;
}

NSString *LRPlural(NSInteger n, NSString *one, NSString *few, NSString *many) {
    NSInteger a = n < 0 ? -n : n;
    if (LRCurrentLanguage() != LRLanguageRussian) return a == 1 ? one : many;
    NSInteger mod10 = a % 10, mod100 = a % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
}
