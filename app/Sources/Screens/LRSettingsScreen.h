/* setup: connection, routing, subscriptions, appearance, privacy, backup,
   amneziawg, advanced daemon options, updates, diagnostics and about */
#import "LRTableScreen.h"

@interface LRSettingsScreen : LRTableScreen {
    NSUInteger _ruleCount;
    NSString *_hwid;
}
@end

@interface LRRoutingScreen : LRTableScreen {
    NSArray *_rules;
}
@end

@interface LRRuleEditorScreen : LRTableScreen {
    NSString *_action;
    NSString *_type;
    NSString *_value;
}
@end

@interface LRAdvancedScreen : LRTableScreen
@end
