#import "LRActivityLog.h"
#import "LRPrefs.h"

NSString * const LRActivityDidChangeNotification = @"LRActivityDidChangeNotification";
static const NSUInteger kMaxEntries = 400;

@implementation LRActivityEntry
@synthesize date = _date, category = _category, message = _message, failure = _failure;
- (void)dealloc {
    [_date release];
    [_category release];
    [_message release];
    [super dealloc];
}
@end

@implementation LRActivityLog

+ (LRActivityLog *)shared {
    static LRActivityLog *log = nil;
    if (!log) log = [[LRActivityLog alloc] init];
    return log;
}

+ (NSString *)storePath {
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docs = [dirs count] ? [dirs objectAtIndex:0] : NSTemporaryDirectory();
    return [docs stringByAppendingPathComponent:@".legacyray-activity.plist"];
}

- (id)init {
    if ((self = [super init])) {
        _entries = [[NSMutableArray alloc] init];
        NSArray *stored = [NSArray arrayWithContentsOfFile:[[self class] storePath]];
        for (NSDictionary *d in stored) {
            if (![d isKindOfClass:[NSDictionary class]]) continue;
            LRActivityEntry *e = [[[LRActivityEntry alloc] init] autorelease];
            e.date = [d objectForKey:@"d"];
            e.category = [d objectForKey:@"c"];
            e.message = [d objectForKey:@"m"];
            e.failure = [[d objectForKey:@"f"] boolValue];
            if (e.date && e.message) [_entries addObject:e];
        }
    }
    return self;
}

- (void)dealloc {
    [_entries release];
    [super dealloc];
}

- (NSArray *)entries {
    return [[_entries copy] autorelease];
}

- (void)save {
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:[_entries count]];
    for (LRActivityEntry *e in _entries)
        [out addObject:[NSDictionary dictionaryWithObjectsAndKeys:e.date, @"d",
                        e.category ? e.category : @"", @"c", e.message, @"m",
                        [NSNumber numberWithBool:e.failure], @"f", nil]];
    [out writeToFile:[[self class] storePath] atomically:YES];
}

- (void)scheduleSave {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(save) object:nil];
    [self performSelector:@selector(save) withObject:nil afterDelay:1.0];
}

- (void)record:(NSString *)category message:(NSString *)message failure:(BOOL)failure {
    if (![LRPrefs activityLogging] || ![message length]) return;
    LRActivityEntry *e = [[[LRActivityEntry alloc] init] autorelease];
    e.date = [NSDate date];
    e.category = category;
    e.message = LRRedact(message);
    e.failure = failure;
    [_entries insertObject:e atIndex:0];
    while ([_entries count] > kMaxEntries) [_entries removeLastObject];
    [self scheduleSave];
    [[NSNotificationCenter defaultCenter] postNotificationName:LRActivityDidChangeNotification
                                                        object:self];
}

- (void)clear {
    [_entries removeAllObjects];
    [self save];
    [[NSNotificationCenter defaultCenter] postNotificationName:LRActivityDidChangeNotification
                                                        object:self];
}

- (NSString *)textDump {
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
    [f setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSMutableString *s = [NSMutableString string];
    for (LRActivityEntry *e in [_entries reverseObjectEnumerator])
        [s appendFormat:@"%@ [%@]%@ %@\n", [f stringFromDate:e.date], e.category,
         e.failure ? @" FAIL" : @"", e.message];
    return s;
}
@end

static void LRLogv(NSString *category, BOOL failure, NSString *format, va_list ap) {
    NSString *msg = [[[NSString alloc] initWithFormat:format arguments:ap] autorelease];
    [[LRActivityLog shared] record:category message:msg failure:failure];
}

void LRLog(NSString *category, NSString *format, ...) {
    va_list ap;
    va_start(ap, format);
    LRLogv(category, NO, format, ap);
    va_end(ap);
}

void LRLogFail(NSString *category, NSString *format, ...) {
    va_list ap;
    va_start(ap, format);
    LRLogv(category, YES, format, ap);
    va_end(ap);
}

NSString *LRRedact(NSString *text) {
    if (![text length]) return text;
    NSMutableString *s = [NSMutableString stringWithString:text];
    NSArray *patterns = [NSArray arrayWithObjects:
        @"[a-zA-Z][a-zA-Z0-9+.-]*://[^\\s]+",                                     /* links */
        @"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", /* uuids */
        @"\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b",                                  /* ipv4 */
        nil];
    NSArray *labels = [NSArray arrayWithObjects:@"<link>", @"<id>", @"<ip>", nil];
    for (NSUInteger i = 0; i < [patterns count]; ++i) {
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:
                                   [patterns objectAtIndex:i] options:0 error:NULL];
        [re replaceMatchesInString:s options:0 range:NSMakeRange(0, [s length])
                      withTemplate:[labels objectAtIndex:i]];
    }
    return s;
}
