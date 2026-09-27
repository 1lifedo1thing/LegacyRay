/* debug and diagnostics: the live state of the daemon and the device, the
   connection check, the activity journal, logs, the firewall ruleset, and a
   privacy-safe report to send when asking for help */
#import "LRTableScreen.h"
#import "LRConnectionCheck.h"

@interface LRDiagnosticsScreen : LRTableScreen {
    NSArray *_facts;
}
@end

@interface LRFactsScreen : LRTableScreen {
    NSArray *_facts;
}
- (id)initWithFacts:(NSArray *)facts;
@end

@interface LRConnectionCheckScreen : LRTableScreen {
    LRConnectionCheck *_check;
}
@end

@interface LRActivityScreen : LRTableScreen
@end

/* builds the report text; answers on the main queue */
void LRBuildDiagnosticReport(void (^done)(NSString *report));
