/* the routing extras: happ routing profiles, amnezia-style site lists and
   the geosite / geoip data behind geo rules */
#import "LRTableScreen.h"
#import "LRRoutingProfiles.h"

@interface LRRoutingProfilesScreen : LRTableScreen {
    NSString *_status;
}
@end

@interface LRSitesScreen : LRTableScreen {
    NSArray *_rules;   /* LRRule */
    BOOL _busy;
}
@end

/* one site, typed or pasted, and how it is matched: a specific domain or
   the head domain with everything under it */
@interface LRSiteAddScreen : LRTableScreen <UITextFieldDelegate> {
    UITextField *_field;
    UIView *_fieldBox;
    LRSiteMode _mode;
    NSString *_action;
    void (^_done)(NSArray *spec);
}
- (id)initWithAction:(NSString *)action done:(void (^)(NSArray *spec))done;
@end

@interface LRGeoScreen : LRTableScreen {
    NSArray *_lines;
    NSString *_summary;
    BOOL _updating;
}
@end
