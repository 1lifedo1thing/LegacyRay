/* the mechanical sounds of the receiver: a soft click for keys and switches,
   a heavier clunk for the power knob. short pcm files played as system sounds,
   so they mix with other audio and honour the ring switch */
#import <Foundation/Foundation.h>

@interface LRSound : NSObject
+ (void)click;
+ (void)clunk;
+ (void)tick;     /* tuning dial detent */
@end
