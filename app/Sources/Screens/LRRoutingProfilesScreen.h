/* the routing extras: happ routing profiles, amnezia-style site lists and
   the geosite / geoip data behind geo rules */
#import "LRTableScreen.h"

@interface LRRoutingProfilesScreen : LRTableScreen {
    NSString *_status;
}
@end

@interface LRSitesScreen : LRTableScreen {
    NSArray *_rules;   /* LRRule */
    BOOL _busy;
}
@end

@interface LRGeoScreen : LRTableScreen {
    NSArray *_lines;
    NSString *_summary;
    BOOL _updating;
}
@end
