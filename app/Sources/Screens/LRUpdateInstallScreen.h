/* installs a LegacyRay .deb over the running package through the setuid
   helper, with the helper's progress lines on a little paper tape */
#import "LRScreen.h"
#import "LRIndicators.h"

@interface LRUpdateInstallScreen : LRScreen {
    NSString *_path;
    UILabel *_status;
    UITextView *_log;
    LRTubeGauge *_gauge;
    LRButton *_done;
    NSUInteger _lines;
    BOOL _finished;
}
- (id)initWithPackagePath:(NSString *)path;
@end
