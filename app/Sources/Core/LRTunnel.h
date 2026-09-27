/* the connection as the console shows it: state, the server it is on, how
   long it has been up and how much went through. polls the daemon once a
   second while the app is in front, derives speeds from the counters, and
   drives connect / disconnect / seek for both backends (the vless daemon and
   the amneziawg helper) */
#import <Foundation/Foundation.h>
#import "LRPrefs.h"

typedef enum {
    LRTunnelOffline = 0,  /* the daemon is not answering */
    LRTunnelIdle,
    LRTunnelConnecting,
    LRTunnelConnected,
    LRTunnelError
} LRTunnelState;

extern NSString * const LRTunnelDidChangeNotification;   /* state / server */
extern NSString * const LRTunnelTickNotification;        /* every poll */

@interface LRTunnel : NSObject {
    LRTunnelState _state;
    LRBackend _activeBackend;
    long _uptime;
    uint64_t _bytesUp;
    uint64_t _bytesDown;
    double _speedUp;
    double _speedDown;
    double _peakDown;
    NSString *_lastError;
    NSTimer *_timer;
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

- (void)start;          /* begin polling; call when the app comes forward */
- (void)stop;           /* stop polling in the background */
- (void)pollNow;

- (BOOL)isOn;           /* connected or connecting */
- (void)toggle;
- (void)connect;        /* the selected server, or the amneziawg profile */
- (void)connectServerIndex:(int)index;
- (void)disconnect;
- (void)seek:(NSInteger)step;
- (void)startAWG;

/* seconds since the tunnel came up, ticking locally between polls */
- (long)liveUptime;
- (NSString *)stateTitle;   /* "CONNECTED" etc for the display */
@end
