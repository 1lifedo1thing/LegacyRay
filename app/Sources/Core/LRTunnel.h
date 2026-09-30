/* the connection as the console shows it: state, the server it is on, how
   long it has been up and how much went through. nothing here polls: while
   the app is in front the daemon pushes state changes and a counter line a
   second over one WATCH connection, and amneziawg announces its status with a
   Darwin notification. a one second tick runs only while a tunnel is up and
   the app is on screen, for the clock. it also drives connect / disconnect /
   seek for both backends (the vless daemon and the amneziawg helper) */
#import <Foundation/Foundation.h>
#import "LRPrefs.h"
#import "LRStatusStream.h"

typedef enum {
    LRTunnelOffline = 0,  /* the daemon is not answering */
    LRTunnelIdle,
    LRTunnelConnecting,
    LRTunnelConnected,
    LRTunnelError
} LRTunnelState;

extern NSString * const LRTunnelDidChangeNotification;   /* state / server */
extern NSString * const LRTunnelTickNotification;        /* once a second while up */

@interface LRTunnel : NSObject <LRStatusStreamDelegate> {
    LRTunnelState _state;
    LRBackend _activeBackend;
    long _uptime;
    uint64_t _bytesUp;
    uint64_t _bytesDown;
    double _speedUp;
    double _speedDown;
    double _peakDown;
    NSString *_lastError;
    NSTimer *_timer;          /* the clock tick, only while connected and active */
    NSTimer *_renewTimer;     /* renews the WATCH lease */
    NSTimer *_retryTimer;     /* reopens the stream after the daemon went away */
    LRStatusStream *_stream;
    NSString *_awgInterface;  /* utunN while amneziawg is up, for its counters */
    BOOL _active;             /* the app is in front */
    BOOL _busy;
    BOOL _polling;
    NSTimeInterval _lastSampleTime;
    uint64_t _lastSampleUp;
    uint64_t _lastSampleDown;
    NSTimeInterval _uptimeBase;
}
@property (nonatomic, readonly) LRTunnelState state;
@property (nonatomic, readonly) LRBackend activeBackend;
@property (nonatomic, readonly) long uptime;
@property (nonatomic, readonly) uint64_t bytesUp;
@property (nonatomic, readonly) uint64_t bytesDown;
@property (nonatomic, readonly) double speedUp;
@property (nonatomic, readonly) double speedDown;
@property (nonatomic, readonly) BOOL busy;
@property (nonatomic, copy) NSString *lastError;

+ (LRTunnel *)shared;

- (void)start;          /* open the status stream; call when the app comes forward */
- (void)stop;           /* close it and stop every timer in the background */
- (void)pollNow;        /* one STATUS round trip, for after a command */

- (BOOL)isOn;           /* connected or connecting */
- (void)toggle;
- (void)connect;        /* the selected server, or the amneziawg profile */
- (void)connectServerIndex:(int)index;
- (void)disconnect;
- (void)seek:(NSInteger)step;
- (void)startAWG;

/* seconds since the tunnel came up, ticking locally between polls */
- (long)liveUptime;
- (NSString *)stateTitle;   /* "Connected" etc */
@end
