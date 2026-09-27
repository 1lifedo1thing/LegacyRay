/* json on every ios this runs on: NSJSONSerialization only arrived in ios 5,
   so both directions go through cJSON, which the app already carries */
#import <Foundation/Foundation.h>

/* NSDictionary / NSArray / NSString / NSNumber / NSNull, or nil */
id LRJSONParse(NSData *data);
/* compact json for dictionaries, arrays, strings, numbers and NSNull */
NSString *LRJSONString(id object);
