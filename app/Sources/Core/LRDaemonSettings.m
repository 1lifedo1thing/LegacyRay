#import "LRDaemonSettings.h"
#import "LRDaemonClient.h"
#import "LRActivityLog.h"

NSString * const LRDaemonSettingsDidChangeNotification = @"LRDaemonSettingsDidChangeNotification";

@implementation LRDaemonSettings
@synthesize loaded = _loaded;

+ (LRDaemonSettings *)shared {
    static LRDaemonSettings *s = nil;
    if (!s) s = [[LRDaemonSettings alloc] init];
    return s;
}

- (id)init {
    if ((self = [super init])) _values = [[NSMutableDictionary alloc] init];
    return self;
}

- (void)dealloc {
    [_values release];
    [super dealloc];
}

- (void)notify {
    [[NSNotificationCenter defaultCenter] postNotificationName:LRDaemonSettingsDidChangeNotification
                                                        object:self];
}

- (void)refresh {
    [self refresh:nil];
}

- (void)refresh:(void (^)(BOOL))done {
    void (^callback)(BOOL) = [[done copy] autorelease];
    [[LRDaemonClient shared] daemonSettings:^(NSDictionary *settings) {
        if (settings) {
            [_values setDictionary:settings];
            _loaded = YES;
            [self notify];
        }
        if (callback) callback(settings != nil);
    }];
}

- (NSString *)stringForKey:(NSString *)key {
    return [_values objectForKey:key];
}

- (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback {
    NSString *v = [_values objectForKey:key];
    return v ? [v intValue] != 0 : fallback;
}

- (NSInteger)integerForKey:(NSString *)key fallback:(NSInteger)fallback {
    NSString *v = [_values objectForKey:key];
    return v ? [v integerValue] : fallback;
}

- (void)setValue:(NSString *)value forKey:(NSString *)key done:(void (^)(BOOL, NSString *))done {
    void (^callback)(BOOL, NSString *) = [[done copy] autorelease];
    NSString *old = [[[_values objectForKey:key] retain] autorelease];
    if (value) [_values setObject:value forKey:key];
    [self notify];
    [[LRDaemonClient shared] setSetting:key value:value reply:^(NSString *reply) {
        BOOL ok = LRReplyIsOK(reply);
        NSString *err = ok ? nil : (LRErrorFromReply(reply) ? LRErrorFromReply(reply)
                                                           : @"the daemon did not answer");
        if (!ok) {
            if (old) [_values setObject:old forKey:key];
            else [_values removeObjectForKey:key];
            [self notify];
            LRLogFail(@"settings", @"%@: %@", key, err);
        } else {
            LRLog(@"settings", @"%@ changed", key);
        }
        if (callback) callback(ok, err);
    }];
}

- (void)setBool:(BOOL)on forKey:(NSString *)key {
    [self setValue:on ? @"1" : @"0" forKey:key done:nil];
}
@end
