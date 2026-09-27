/* amneziawg / wireguard: every saved profile, which one POWER starts, and
   the way in for new ones. LRAWGProfileScreen is one profile: its fields, the
   obfuscation parameters (editable one by one, as in the amnezia client), a
   handshake check, sharing, renaming and removal */
#import "LRTableScreen.h"

@class LRAWGProfile;

@interface LRAWGScreen : LRTableScreen
@end

@interface LRAWGProfileScreen : LRTableScreen {
    LRAWGProfile *_profile;
    NSString *_check;       /* the last handshake result, for the status row */
    BOOL _checking;
}
- (id)initWithProfile:(LRAWGProfile *)profile;
@end

/* replace (or add, in [Interface]) one key of a wireguard config */
NSString *LRAWGSetField(NSString *config, NSString *key, NSString *value);
