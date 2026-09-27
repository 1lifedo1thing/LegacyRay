#import "LRReminders.h"
#import "LRModels.h"
#import <UIKit/UIKit.h>

#define LR_REMINDER_KEY @"lr-subscription"

@implementation LRReminders

+ (BOOL)enabled {
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:@"LRSubReminders"];
    return v ? [v boolValue] : YES;
}

+ (void)setEnabled:(BOOL)on {
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:@"LRSubReminders"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (!on) [self cancelAll];
}

+ (void)cancelAll {
    UIApplication *app = [UIApplication sharedApplication];
    for (UILocalNotification *n in [app scheduledLocalNotifications])
        if ([n.userInfo objectForKey:LR_REMINDER_KEY]) [app cancelLocalNotification:n];
}

/* noon on the day, days before the expiry */
+ (NSDate *)noonDaysBefore:(NSInteger)days expiry:(NSDate *)expiry {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *c = [cal components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
                                 fromDate:[expiry dateByAddingTimeInterval:-days * 86400.0]];
    c.hour = 12;
    return [cal dateFromComponents:c];
}

+ (void)scheduleForSubscriptions:(NSArray *)subscriptions {
    Class cls = NSClassFromString(@"UILocalNotification");
    if (!cls) return;
    [self cancelAll];
    if (![self enabled]) return;
    UIApplication *app = [UIApplication sharedApplication];
    NSDate *now = [NSDate date];
    for (LRSubscription *sub in subscriptions) {
        if (!sub.expire) continue;
        NSDate *expiry = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)sub.expire];
        if ([expiry timeIntervalSinceDate:now] <= 0) continue;
        NSString *name = [sub.name length] ? sub.name : L(@"Subscription");
        for (NSNumber *d in [NSArray arrayWithObjects:[NSNumber numberWithInt:3], [NSNumber numberWithInt:1], nil]) {
            NSDate *fire = [self noonDaysBefore:[d integerValue] expiry:expiry];
            if ([fire timeIntervalSinceDate:now] <= 60) continue;
            UILocalNotification *n = [[[cls alloc] init] autorelease];
            n.fireDate = fire;
            n.timeZone = [NSTimeZone defaultTimeZone];
            n.alertBody = [d intValue] == 1
                ? [NSString stringWithFormat:L(@"The subscription “%@” ends tomorrow."), name]
                : [NSString stringWithFormat:L(@"The subscription “%@” ends in %d days."), name, [d intValue]];
            n.alertAction = L(@"Open");
            n.soundName = UILocalNotificationDefaultSoundName;
            n.userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:sub.index] forKey:LR_REMINDER_KEY];
            [app scheduleLocalNotification:n];
        }
    }
}
@end
