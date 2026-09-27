/* the in-app event journal: what the user did and what the app answered,
   with the time. privacy safe by construction: callers pass categories and
   short outcomes, and anything that looks like a host or a link is masked
   before it is written */
#import <Foundation/Foundation.h>

extern NSString * const LRActivityDidChangeNotification;

@interface LRActivityEntry : NSObject {
    NSDate *_date;
    NSString *_category;
    NSString *_message;
    BOOL _failure;
}
@property (nonatomic, retain) NSDate *date;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) BOOL failure;
@end

@interface LRActivityLog : NSObject {
    NSMutableArray *_entries;
}
+ (LRActivityLog *)shared;
- (NSArray *)entries; /* newest first */
- (void)record:(NSString *)category message:(NSString *)message failure:(BOOL)failure;
- (void)clear;
/* plain text, one event per line, for the diagnostic report */
- (NSString *)textDump;
@end

/* LRLog(@"import", @"subscription added"), LRLogFail(@"tunnel", @"%@", why) */
void LRLog(NSString *category, NSString *format, ...) NS_FORMAT_FUNCTION(2, 3);
void LRLogFail(NSString *category, NSString *format, ...) NS_FORMAT_FUNCTION(2, 3);
/* replace urls, uuids and host names in free text */
NSString *LRRedact(NSString *text);
