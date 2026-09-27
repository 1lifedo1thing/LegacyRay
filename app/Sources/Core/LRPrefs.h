/* settings that belong to this app install rather than to the daemon. the
   daemon keeps the catalog, rules and tunnel settings; these are the ones a
   second device would not want to share */
#import <Foundation/Foundation.h>

typedef enum {
    LRThemeAuto = 0,     /* flat on ios 7+, classic by time of day before */
    LRThemeDay,          /* classic silver */
    LRThemeNight,        /* classic graphite */
    LRThemeFlat,         /* flat, ios 7 style, on any system */
    LRThemeClassicAuto   /* classic, silver by day and graphite at night */
} LRThemeSetting;

typedef enum {
    LRPingTCP = 0,       /* tcp connect to the server */
    LRPingHandshake,     /* tls / reality handshake with the server */
    LRPingProxyGET       /* an http request carried through the server */
} LRPingType;

typedef enum {
    LRSortManual = 0,
    LRSortName,
    LRSortPing
} LRSortMode;

typedef enum {
    LRBackendServer = 0,
    LRBackendAmneziaWG
} LRBackend;

extern NSString * const LRPrefsDidChangeNotification;

@interface LRPrefs : NSObject
+ (LRThemeSetting)theme;
+ (void)setTheme:(LRThemeSetting)theme;
/* the resolved skin right now */
+ (BOOL)flatSkinActive;
/* YES for graphite (only meaningful when the classic skin is active) */
+ (BOOL)nightSkinActive;
/* ios 7 or later: the system the flat skin is the default on */
+ (BOOL)systemIsFlat;

/* hide hosts, links and keys everywhere they would be drawn */
+ (BOOL)stealthMode;
+ (void)setStealthMode:(BOOL)on;

+ (LRPingType)pingType;
+ (void)setPingType:(LRPingType)type;
/* the daemon CHECK mode for the ping type */
+ (NSString *)pingModeName;

+ (LRSortMode)sortMode;
+ (void)setSortMode:(LRSortMode)mode;

+ (BOOL)refreshSubscriptionsOnOpen;
+ (void)setRefreshSubscriptionsOnOpen:(BOOL)on;

+ (BOOL)automaticUpdateChecks;
+ (void)setAutomaticUpdateChecks:(BOOL)on;
+ (NSDate *)lastUpdateCheck;
+ (void)setLastUpdateCheck:(NSDate *)date;

+ (BOOL)preferGitHubLegacy;
+ (void)setPreferGitHubLegacy:(BOOL)on;

+ (BOOL)activityLogging;
+ (void)setActivityLogging:(BOOL)on;

+ (BOOL)soundEffects;
+ (void)setSoundEffects:(BOOL)on;

+ (BOOL)sectionCollapsed:(NSString *)key;
+ (void)setSection:(NSString *)key collapsed:(BOOL)collapsed;

+ (LRBackend)selectedBackend;
+ (void)setSelectedBackend:(LRBackend)backend;
/* where the amneziawg profile lives; the helper reads it from there */
+ (NSString *)awgProfilePath;
+ (BOOL)hasAWGProfile;

/* a yes the first time, for the welcome card */
+ (BOOL)consumeFirstLaunch;
@end

/* mask a host / link for display while stealth mode is on */
NSString *LRStealth(NSString *text);
