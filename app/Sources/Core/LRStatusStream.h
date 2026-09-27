/* one control connection that stays open while the app is in front. it asks
   the daemon to WATCH, and the daemon pushes STATE lines when the tunnel
   changes and a STAT line a second while it is up. the app used to open a
   fresh connection, authenticate and ask STATUS every second, which woke the
   daemon (and, for amneziawg, started a setuid helper) whether or not anything
   had changed. reading is a GCD source, so nothing here runs on a clock */
#import <Foundation/Foundation.h>

@class LRStatusStream;

@protocol LRStatusStreamDelegate <NSObject>
- (void)statusStream:(LRStatusStream *)stream line:(NSString *)line;
/* the daemon went away or never answered */
- (void)statusStreamClosed:(LRStatusStream *)stream;
@end

@interface LRStatusStream : NSObject {
    id<LRStatusStreamDelegate> _delegate;   /* not retained */
    dispatch_queue_t _queue;
    dispatch_source_t _source;
    int _fd;
    NSUInteger _generation;
    BOOL _opening;
    NSMutableData *_pending;                /* touched only on _queue */
    BOOL _eof;                              /* touched only on _queue */
}
- (id)initWithDelegate:(id<LRStatusStreamDelegate>)delegate;
- (void)open;       /* no-op while open or opening */
- (void)renew;      /* the daemon's WATCH is a lease; renew well inside it */
- (void)close;
- (BOOL)isOpen;
@end
