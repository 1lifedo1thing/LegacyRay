/* the daemon's settings as the app last read them. the daemon owns them (they
   live in its config file next to the catalog), so every change goes through
   SET and the cache is refreshed from the answer */
#import <Foundation/Foundation.h>

extern NSString * const LRDaemonSettingsDidChangeNotification;

@interface LRDaemonSettings : NSObject {
    NSMutableDictionary *_values;
    BOOL _loaded;
}
@property (nonatomic, readonly) BOOL loaded;
+ (LRDaemonSettings *)shared;
- (void)refresh;
- (void)refresh:(void (^)(BOOL ok))done;
- (NSString *)stringForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback;
- (NSInteger)integerForKey:(NSString *)key fallback:(NSInteger)fallback;
/* optimistic: the cache changes at once and rolls back when the daemon says no */
- (void)setValue:(NSString *)value forKey:(NSString *)key done:(void (^)(BOOL ok, NSString *error))done;
- (void)setBool:(BOOL)on forKey:(NSString *)key;
@end
