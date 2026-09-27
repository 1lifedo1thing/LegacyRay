#import "LRPrefs.h"

NSString * const LRPrefsDidChangeNotification = @"LRPrefsDidChangeNotification";

static NSUserDefaults *D(void) { return [NSUserDefaults standardUserDefaults]; }

static void LRChanged(void) {
    [D() synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:LRPrefsDidChangeNotification
                                                        object:nil];
}

static BOOL LRBool(NSString *key, BOOL fallback) {
    id v = [D() objectForKey:key];
    return v ? [v boolValue] : fallback;
}

@implementation LRPrefs

+ (LRThemeSetting)theme {
    NSInteger v = [D() integerForKey:@"LRTheme"];
    return (v >= LRThemeAuto && v <= LRThemeClassicAuto) ? (LRThemeSetting)v : LRThemeAuto;
}

+ (BOOL)systemIsFlat {
    static int cached = -1;
    if (cached < 0) cached = LR_SYSTEM_AT_LEAST(@"7.0") ? 1 : 0;
    return cached == 1;
}

+ (BOOL)flatSkinActive {
    LRThemeSetting t = [self theme];
    if (t == LRThemeFlat) return YES;
    if (t == LRThemeAuto) return [self systemIsFlat];
    return NO;
}

+ (void)setTheme:(LRThemeSetting)theme {
    [D() setInteger:theme forKey:@"LRTheme"];
    LRChanged();
}

+ (BOOL)nightSkinActive {
    LRThemeSetting t = [self theme];
    if (t == LRThemeDay || t == LRThemeFlat) return NO;
    if (t == LRThemeNight) return YES;
    if (t == LRThemeAuto && [self systemIsFlat]) return NO;
    NSDateComponents *c = [[NSCalendar currentCalendar] components:NSHourCalendarUnit
                                                          fromDate:[NSDate date]];
    return [c hour] < 7 || [c hour] >= 20;
}

+ (BOOL)stealthMode { return LRBool(@"LRStealth", NO); }
+ (void)setStealthMode:(BOOL)on { [D() setBool:on forKey:@"LRStealth"]; LRChanged(); }

+ (LRPingType)pingType {
    NSInteger v = [D() integerForKey:@"LRPingType"];
    return (v >= LRPingTCP && v <= LRPingProxyGET) ? (LRPingType)v : LRPingTCP;
}
+ (void)setPingType:(LRPingType)type { [D() setInteger:type forKey:@"LRPingType"]; LRChanged(); }

+ (NSString *)pingModeName {
    switch ([self pingType]) {
        case LRPingHandshake: return @"handshake";
        case LRPingProxyGET: return @"proxy";
        case LRPingTCP: break;
    }
    return @"tcp";
}

+ (LRSortMode)sortMode {
    NSInteger v = [D() integerForKey:@"LRSort"];
    return (v >= LRSortManual && v <= LRSortPing) ? (LRSortMode)v : LRSortManual;
}
+ (void)setSortMode:(LRSortMode)mode { [D() setInteger:mode forKey:@"LRSort"]; LRChanged(); }

+ (BOOL)refreshSubscriptionsOnOpen { return LRBool(@"LRRefreshOnOpen", NO); }
+ (void)setRefreshSubscriptionsOnOpen:(BOOL)on { [D() setBool:on forKey:@"LRRefreshOnOpen"]; LRChanged(); }

+ (BOOL)automaticUpdateChecks { return LRBool(@"LRUpdateChecks", YES); }
+ (void)setAutomaticUpdateChecks:(BOOL)on { [D() setBool:on forKey:@"LRUpdateChecks"]; LRChanged(); }
+ (NSDate *)lastUpdateCheck { return [D() objectForKey:@"LRLastUpdateCheck"]; }
+ (void)setLastUpdateCheck:(NSDate *)date {
    [D() setObject:date forKey:@"LRLastUpdateCheck"];
    [D() synchronize];
}

+ (BOOL)preferGitHubLegacy { return LRBool(@"LRGitHubLegacy", NO); }
+ (void)setPreferGitHubLegacy:(BOOL)on { [D() setBool:on forKey:@"LRGitHubLegacy"]; LRChanged(); }

+ (BOOL)activityLogging { return LRBool(@"LRActivity", YES); }
+ (void)setActivityLogging:(BOOL)on { [D() setBool:on forKey:@"LRActivity"]; LRChanged(); }

+ (BOOL)soundEffects { return LRBool(@"LRSounds", YES); }
+ (void)setSoundEffects:(BOOL)on { [D() setBool:on forKey:@"LRSounds"]; LRChanged(); }

+ (BOOL)sectionCollapsed:(NSString *)key {
    if (![key length]) return NO;
    return [[D() arrayForKey:@"LRCollapsed"] containsObject:key];
}

+ (void)setSection:(NSString *)key collapsed:(BOOL)collapsed {
    if (![key length]) return;
    NSMutableArray *list = [NSMutableArray arrayWithArray:[D() arrayForKey:@"LRCollapsed"]];
    [list removeObject:key];
    if (collapsed) [list addObject:key];
    [D() setObject:list forKey:@"LRCollapsed"];
    [D() synchronize];
}

+ (LRBackend)selectedBackend {
    return [D() integerForKey:@"LRBackend"] == LRBackendAmneziaWG && [self hasAWGProfile]
        ? LRBackendAmneziaWG : LRBackendServer;
}
+ (void)setSelectedBackend:(LRBackend)backend {
    [D() setInteger:backend forKey:@"LRBackend"];
    [D() synchronize];
}

+ (NSString *)awgProfilePath {
    return @"/var/mobile/Library/Preferences/LegacyRay/amneziawg.conf";
}

+ (BOOL)hasAWGProfile {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self awgProfilePath]];
}

+ (BOOL)consumeFirstLaunch {
    if ([D() boolForKey:@"LRLaunchedBefore"]) return NO;
    [D() setBool:YES forKey:@"LRLaunchedBefore"];
    [D() synchronize];
    return YES;
}
@end

NSString *LRStealth(NSString *text) {
    if (![LRPrefs stealthMode] || ![text length]) return text;
    NSUInteger n = [text length];
    if (n <= 4) return @"••••";
    /* keep the scheme so a link still reads as a link */
    NSRange scheme = [text rangeOfString:@"://"];
    NSString *head = scheme.location != NSNotFound && scheme.location < 12
        ? [text substringToIndex:scheme.location + 3] : [text substringToIndex:2];
    return [head stringByAppendingString:@"••••••"];
}
