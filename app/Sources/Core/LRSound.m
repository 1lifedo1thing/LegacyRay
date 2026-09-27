#import "LRSound.h"
#import "LRPrefs.h"
#import <AudioToolbox/AudioToolbox.h>

static SystemSoundID LRLoadSound(NSString *name) {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"wav"];
    if (!path) return 0;
    SystemSoundID sid = 0;
    if (AudioServicesCreateSystemSoundID((CFURLRef)[NSURL fileURLWithPath:path], &sid) != noErr)
        return 0;
    return sid;
}

static void LRPlay(NSString *name, SystemSoundID *slot) {
    if (![LRPrefs soundEffects]) return;
    if (!*slot) *slot = LRLoadSound(name);
    if (*slot) AudioServicesPlaySystemSound(*slot);
}

@implementation LRSound
+ (void)click {
    static SystemSoundID sid = 0;
    LRPlay(@"click", &sid);
}
+ (void)clunk {
    static SystemSoundID sid = 0;
    LRPlay(@"clunk", &sid);
}
+ (void)tick {
    static SystemSoundID sid = 0;
    LRPlay(@"tick", &sid);
}
@end
