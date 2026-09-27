/* asks github for the newest release, through the daemon's tls stack (ios
   4-6 cannot talk to github's tls any more), at most once a day on its own */
#import <Foundation/Foundation.h>

@interface LRRelease : NSObject {
    NSString *_version;
    NSString *_pageURL;
    NSString *_debURL;
    NSString *_notes;
}
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *pageURL;
@property (nonatomic, copy) NSString *debURL;
@property (nonatomic, copy) NSString *notes;
- (BOOL)isNewer;
@end

@interface LRUpdateChecker : NSObject
+ (void)checkNow:(void (^)(LRRelease *release, NSString *error))done;
/* the daily check; calls back only when a newer release exists */
+ (void)checkIfDue:(void (^)(LRRelease *release))found;
/* open the release page, in github legacy when preferred and installed */
+ (void)openRelease:(LRRelease *)release;
+ (void)openProjectPage;
@end

/* -1, 0, 1 for dotted version strings, ignoring a leading v */
NSComparisonResult LRCompareVersions(NSString *a, NSString *b);
