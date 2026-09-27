#import "LRImporter.h"
#import "LRDaemonClient.h"
#import "LRCatalog.h"
#import "LRPrefs.h"
#import "LRTunnel.h"
#import "LRActivityLog.h"
#import "LRKaring.h"
#import "LRZip.h"
#import "LRMenu.h"
#import "LRAlert.h"
#import "LRToast.h"
#import "LRQRScanScreen.h"
#import "LRFilesScreen.h"
#import "LRManualInputScreen.h"
#import "LRUpdateInstallScreen.h"
#import "LRScreen.h"
#import "LRAWGProfiles.h"
#import "LRRoutingProfiles.h"
#import "LRServersScreen.h"
#import "LRJSON.h"
#include "amnezia_bundle.h"

@implementation LRImporter

+ (NSString *)documentsPath {
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [dirs count] ? [dirs objectAtIndex:0] : NSTemporaryDirectory();
}

+ (UIViewController *)host {
    return LRTopViewController();
}

+ (void)present:(UIViewController *)screen {
    UIViewController *vc = [screen isKindOfClass:[UINavigationController class]] ? screen
                                                                                : LRNavigationWithRoot(screen);
    if (LRIsPad()) vc.modalPresentationStyle = UIModalPresentationFormSheet;
    LRPresentModal([self host], vc, YES);
}

#pragma mark menu

+ (void)showMenuFrom:(UIView *)anchor host:(UIViewController *)host {
    LRMenu *menu = [LRMenu menuWithTitle:L(@"Add stations")];
    [menu addItem:L(@"Paste from Clipboard") action:^{ [LRImporter pasteFromClipboard]; }];
    [menu addItem:L(@"Scan QR Code") action:^{
        LRQRScanScreen *scan = [[[LRQRScanScreen alloc] init] autorelease];
        scan.completion = ^(NSString *text) { if (text) [LRImporter importText:text]; };
        [LRImporter present:scan];
    }];
    [menu addItem:L(@"Subscription URL") action:^{ [LRImporter promptSubscription]; }];
    [menu addItem:L(@"Manual Input") action:^{
        [LRImporter present:[[[LRManualInputScreen alloc] init] autorelease]];
    }];
    [menu addItem:L(@"Import from File") action:^{
        [LRImporter present:[[[LRFilesScreen alloc] init] autorelease]];
    }];
    [menu addItem:L(@"Set up my own server") action:^{
        [LRImporter present:[[[LRServerSetupScreen alloc] init] autorelease]];
    }];
    [menu showFromView:anchor];
}

+ (void)pasteFromClipboard {
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    NSString *text = LRTrim(pb.string);
    if (!text) {
        [LRToast showError:L(@"The clipboard is empty")];
        return;
    }
    LRLog(@"import", @"clipboard import");
    [self importText:text];
}

+ (void)promptSubscription {
    [LRAlert promptTitle:L(@"Add Subscription") message:L(@"Paste the subscription link from your provider.")
             placeholder:@"https://" text:nil button:L(@"Add") done:^(NSString *value) {
        NSString *url = LRTrim(value);
        if (!url) return;
        if (![[url lowercaseString] hasPrefix:@"http://"] && ![[url lowercaseString] hasPrefix:@"https://"])
            url = [@"https://" stringByAppendingString:url];
        [LRImporter importText:url];
    }];
}

#pragma mark classification

static BOOL LRIsAWGText(NSString *s) {
    return [s rangeOfString:@"[Interface]" options:NSCaseInsensitiveSearch].location != NSNotFound &&
           [s rangeOfString:@"[Peer]" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static BOOL LRIsSingleServerLink(NSString *s) {
    if ([s rangeOfString:@"\n"].location != NSNotFound) return NO;
    NSString *l = [s lowercaseString];
    NSArray *schemes = [NSArray arrayWithObjects:@"vless://", @"trojan://", @"ss://", @"socks5://",
                        @"socks://", @"hysteria2://", @"hy2://", nil];
    for (NSString *scheme in schemes) if ([l hasPrefix:scheme]) return YES;
    if (![l hasPrefix:@"http://"] && ![l hasPrefix:@"https://"]) return NO;
    /* an http(s) proxy link carries credentials or a bare host:port */
    NSURL *u = [NSURL URLWithString:s];
    if (!u) return NO;
    if ([u user] || [u password]) return YES;
    if ([u fragment]) return YES;
    return [u port] != nil && ([[u path] length] == 0 || [[u path] isEqualToString:@"/"]);
}

static BOOL LRIsSubscriptionURL(NSString *s) {
    NSString *l = [s lowercaseString];
    return [s rangeOfString:@"\n"].location == NSNotFound &&
           ([l hasPrefix:@"http://"] || [l hasPrefix:@"https://"]);
}

+ (void)failed:(NSString *)reason {
    LRLogFail(@"import", @"%@", reason);
    [LRToast showError:reason];
}

+ (void)withDaemon:(void (^)(void))work {
    void (^block)(void) = [[work copy] autorelease];
    [[LRDaemonClient shared] ensureDaemon:^(BOOL up, NSString *detail) {
        if (!up) {
            [LRImporter failed:detail ? detail : L(@"The daemon is not running")];
            return;
        }
        block();
    }];
}

+ (void)importText:(NSString *)raw {
    NSString *s = LRTrim(raw);
    if ([s hasPrefix:@"﻿"]) s = [s substringFromIndex:1];
    if (!s) {
        [self failed:L(@"Nothing to import")];
        return;
    }
    if (LRKaringIsLANLink(s)) {
        [self importKaringLAN:s];
        return;
    }
    if (LRIsAWGText(s)) {
        [self importAWG:s];
        return;
    }
    if ([LRRoutingProfiles isHappRoutingLink:s]) {
        [self importRoutingLink:s];
        return;
    }
    if ([s hasPrefix:@"{"] && [self tryRoutingJSON:s]) return;
    NSData *utf8 = [s dataUsingEncoding:NSUTF8StringEncoding];
    if ([self tryAmneziaBundle:utf8]) return;
    if ([[s lowercaseString] hasPrefix:@"legacyray://"]) {
        [self handleOpenURL:[NSURL URLWithString:s]];
        return;
    }
    if (LRIsSingleServerLink(s)) {
        [self addServerLink:s];
        return;
    }
    if (LRIsSubscriptionURL(s)) {
        if ([[s lowercaseString] hasPrefix:@"http://"]) [self confirmPlainHTTP:s];
        else [self addSubscription:s name:nil];
        return;
    }
    /* base64 feeds, happ links, xray json, clash yaml, surge ini: the
       daemon owns those parsers */
    [self importContent:utf8];
}

+ (void)confirmPlainHTTP:(NSString *)url {
    [LRAlert confirmTitle:L(@"Unencrypted Subscription")
                  message:L(@"This link fetches the subscription without encryption. Anyone on the network can read or change it. Import it only if you trust this network and provider.")
                   button:L(@"Import") destructive:NO action:^{
        LRLog(@"import", @"plain http subscription approved");
        [LRImporter addSubscription:url name:nil];
    }];
}

+ (void)addServerLink:(NSString *)link {
    [self withDaemon:^{
        [LRToast show:L(@"Adding station...")];
        [[LRDaemonClient shared] addServerLink:link reply:^(NSString *reply) {
            if (LRReplyIsOK(reply)) {
                LRLog(@"import", @"station added");
                [LRToast showSuccess:L(@"Station added")];
                [[LRCatalog shared] reload];
            } else {
                [LRImporter failed:LRErrorFromReply(reply) ? LRErrorFromReply(reply) : L(@"Invalid configuration link")];
            }
        }];
    }];
}

static int LRTrailingInt(NSString *reply) {
    NSArray *t = [LRTrim(reply) componentsSeparatedByString:@" "];
    NSScanner *sc = [NSScanner scannerWithString:[t lastObject] ? [t lastObject] : @""];
    int v = -1;
    return [sc scanInt:&v] ? v : -1;
}

+ (void)addSubscription:(NSString *)url name:(NSString *)name {
    NSString *title = LRTrim(name);
    if (!title) {
        NSString *host = [[NSURL URLWithString:url] host];
        title = [host length] ? host : L(@"Subscription");
    }
    [self withDaemon:^{
        [LRToast show:L(@"Fetching subscription...")];
        [[LRDaemonClient shared] addSubscriptionURL:url name:title reply:^(NSString *reply) {
            if (!LRReplyIsOK(reply)) {
                NSString *e = LRErrorFromReply(reply);
                if ([e rangeOfString:@"exists"].location != NSNotFound)
                    [LRToast show:L(@"Subscription already exists (skipped)")];
                else [LRImporter failed:e ? e : L(@"Subscription import failed")];
                return;
            }
            NSString *text = LRTrim(reply);
            /* older daemons add first and leave the fetch to a REFRESH */
            if ([text rangeOfString:@"server(s)"].location == NSNotFound &&
                [text rangeOfString:@"subscription added,"].location == NSNotFound) {
                int idx = LRTrailingInt(reply);
                if (idx >= 0) {
                    [[LRDaemonClient shared] refreshSubscriptionIndex:idx reply:^(NSString *r2) {
                        if (LRReplyIsOK(r2)) [LRToast showSuccess:L(@"Subscription added")];
                        else [LRImporter failed:LRErrorFromReply(r2) ? LRErrorFromReply(r2) : L(@"Subscription update failed")];
                        [[LRCatalog shared] reload];
                    }];
                    return;
                }
            }
            LRLog(@"import", @"subscription added");
            [LRToast showSuccess:[text hasPrefix:@"OK "] ? [text substringFromIndex:3] : L(@"Subscription added")];
            [[LRCatalog shared] reload];
        }];
    }];
}

+ (void)importContent:(NSData *)data {
    [self withDaemon:^{
        [LRToast show:L(@"Reading...")];
        [[LRDaemonClient shared] importContent:data reply:^(NSString *reply) {
            NSString *clean = LRTrim(reply);
            if ([clean hasPrefix:@"OK"]) {
                LRLog(@"import", @"content imported");
                [LRToast showSuccess:[clean length] > 3 ? [clean substringFromIndex:3] : L(@"Imported")];
                [[LRCatalog shared] reload];
            } else {
                [LRImporter failed:LRErrorFromReply(reply) ? LRErrorFromReply(reply) : L(@"No importable links found")];
            }
        }];
    }];
}

#pragma mark amneziawg

+ (BOOL)tryAmneziaBundle:(NSData *)body {
    if (![body length] || !amz_bundle_looks_like([body bytes], [body length])) return NO;
    const size_t cap = 64 * 1024;
    char *conf = malloc(cap);
    char reason[192] = "amnezia bundle could not be read";
    size_t len = 0;
    amz_status_t r = amz_bundle_extract_conf([body bytes], [body length], conf, cap, &len,
                                             reason, sizeof reason);
    if (r != AMZ_OK) {
        free(conf);
        if (r == AMZ_ERR_NOT_BUNDLE) return NO;
        [self failed:[NSString stringWithUTF8String:reason]];
        return YES;
    }
    NSString *text = [[[NSString alloc] initWithBytes:conf length:len encoding:NSUTF8StringEncoding] autorelease];
    free(conf);
    if (text) [self importAWG:text];
    else [self failed:L(@"The Amnezia profile carries no readable config")];
    return YES;
}

+ (void)importAWG:(NSString *)text {
    [LRToast show:L(@"Checking the AmneziaWG profile...")];
    [LRAWGProfiles addConfig:text name:nil done:^(LRAWGProfile *profile, NSString *error) {
        if (!profile) {
            [LRImporter failed:error ? error : L(@"Invalid AmneziaWG profile")];
            return;
        }
        [LRAWGProfiles setActive:profile];
        [LRPrefs setSelectedBackend:LRBackendAmneziaWG];
        LRLog(@"import", @"amneziawg profile saved");
        [LRToast showSuccess:[NSString stringWithFormat:L(@"Profile “%@” saved. Press POWER to connect."),
                              profile.name]];
        [[LRCatalog shared] reload];
    }];
}

#pragma mark routing profiles

+ (void)offerRoutingProfile:(LRRoutingProfile *)profile activate:(BOOL)activate {
    [LRRoutingProfiles save:profile];
    LRLog(@"import", @"routing profile saved (%lu rules)", (unsigned long)[profile.rules count]);
    NSString *msg = [profile summary];
    if (profile.skipped)
        msg = [msg stringByAppendingFormat:@"\n%@", [NSString stringWithFormat:
               L(@"%lu entries LegacyRay cannot use were left out (regular expressions, IPv6)."),
               (unsigned long)profile.skipped]];
    [LRAlert confirmTitle:[NSString stringWithFormat:L(@"Routing profile “%@”"), profile.name]
                  message:msg button:activate ? L(@"Apply now") : L(@"Apply")
              destructive:NO action:^{
        [LRToast show:L(@"Applying the routing profile...")];
        [LRRoutingProfiles apply:profile progress:^(NSString *line) {
            [LRToast show:line];
        } done:^(BOOL ok, NSString *message) {
            if (message) [LRToast showError:message];
            else [LRToast showSuccess:L(@"Routing profile applied")];
        }];
    }];
}

+ (void)importRoutingLink:(NSString *)link {
    NSString *error = nil;
    BOOL activate = NO;
    LRRoutingProfile *p = [LRRoutingProfiles profileFromHappLink:link activate:&activate error:&error];
    if (!p) { [self failed:error]; return; }
    [self offerRoutingProfile:p activate:activate];
}

+ (BOOL)tryRoutingJSON:(NSString *)text {
    id json = LRJSONParse([text dataUsingEncoding:NSUTF8StringEncoding]);
    if (![json isKindOfClass:[NSDictionary class]]) return NO;
    BOOL happ = NO;
    for (NSString *k in json)
        if ([k isKindOfClass:[NSString class]] &&
            ([k caseInsensitiveCompare:@"DirectSites"] == NSOrderedSame ||
             [k caseInsensitiveCompare:@"ProxySites"] == NSOrderedSame ||
             [k caseInsensitiveCompare:@"GlobalProxy"] == NSOrderedSame)) happ = YES;
    if (!happ) return NO;
    NSString *error = nil;
    LRRoutingProfile *p = [LRRoutingProfiles profileFromHappJSON:json error:&error];
    if (!p) { [self failed:error]; return YES; }
    [self offerRoutingProfile:p activate:NO];
    return YES;
}

#pragma mark karing

+ (void)importKaringZip:(NSData *)zip {
    NSString *error = nil;
    NSArray *subs = LRKaringSubscriptionsFromBackup(zip, &error);
    if (!subs) {
        [self failed:error ? error : L(@"Unable to read the Karing backup")];
        return;
    }
    LRLog(@"import", @"karing backup: %lu subscriptions", (unsigned long)[subs count]);
    [self addSubscriptionsInOrder:subs index:0 added:0];
}

+ (void)addSubscriptionsInOrder:(NSArray *)subs index:(NSUInteger)i added:(NSUInteger)added {
    if (i >= [subs count]) {
        [LRToast showSuccess:[NSString stringWithFormat:L(@"Karing: %lu of %lu subscriptions added"),
                              (unsigned long)added, (unsigned long)[subs count]]];
        [[LRCatalog shared] reload];
        return;
    }
    NSDictionary *d = [subs objectAtIndex:i];
    NSString *url = [d objectForKey:@"url"];
    NSString *name = [d objectForKey:@"name"];
    if (!name) name = [[NSURL URLWithString:url] host];
    [[LRDaemonClient shared] addSubscriptionURL:url name:name ? name : L(@"Subscription") reply:^(NSString *reply) {
        [LRImporter addSubscriptionsInOrder:subs index:i + 1 added:added + (LRReplyIsOK(reply) ? 1 : 0)];
    }];
}

+ (void)importKaringLAN:(NSString *)link {
    [LRToast show:L(@"Receiving Karing backup...")];
    LRKaringFetchLAN(link, ^(NSData *zip, NSString *error) {
        if (!zip) {
            [LRImporter failed:[NSString stringWithFormat:L(@"Karing sync failed: %@"), error]];
            return;
        }
        [LRImporter withDaemon:^{ [LRImporter importKaringZip:zip]; }];
    });
}

#pragma mark files

+ (void)importFileAtPath:(NSString *)path {
    NSString *ext = [[path pathExtension] lowercaseString];
    if ([ext isEqualToString:@"deb"]) {
        [LRAlert confirmTitle:L(@"Install Update")
                      message:[NSString stringWithFormat:L(@"Install %@ over the current version? Stations, subscriptions and settings stay in place."),
                               [path lastPathComponent]]
                       button:L(@"Install") destructive:NO action:^{
            [LRImporter present:[[[LRUpdateInstallScreen alloc] initWithPackagePath:path] autorelease]];
        }];
        return;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (![data length]) {
        [self failed:L(@"The file is empty or could not be read")];
        return;
    }
    [self importData:data filename:[path lastPathComponent]];
}

+ (void)importData:(NSData *)data filename:(NSString *)filename {
    NSString *ext = [[filename pathExtension] lowercaseString];
    LRLog(@"import", @"file import (.%@)", ext);
    if ([ext isEqualToString:@"lray"] || [ext isEqualToString:@"senko"]) {
        [LRAlert confirmTitle:L(@"Restore Backup")
                      message:L(@"Replace all stations, subscriptions, rules and daemon settings with the ones in this backup?")
                       button:L(@"Restore") destructive:YES action:^{
            [LRImporter withDaemon:^{
                [[LRDaemonClient shared] restoreBackupData:data reply:^(NSString *reply) {
                    if (LRReplyIsOK(reply)) {
                        LRLog(@"backup", @"backup restored");
                        [LRToast showSuccess:L(@"Backup restored")];
                        [[LRCatalog shared] reload];
                    } else {
                        [LRImporter failed:LRErrorFromReply(reply) ? LRErrorFromReply(reply) : L(@"Backup restore failed")];
                    }
                }];
            }];
        }];
        return;
    }
    if (LRZipLooksLikeZip(data)) {
        [self withDaemon:^{ [LRImporter importKaringZip:data]; }];
        return;
    }
    if ([ext isEqualToString:@"vpn"] && [self tryAmneziaBundle:data]) return;
    NSString *text = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    if (text) {
        NSString *t = LRTrim(text);
        if (t && (LRIsAWGText(t) || LRIsSingleServerLink(t) || LRKaringIsLANLink(t) ||
                  (LRIsSubscriptionURL(t)))) {
            [self importText:t];
            return;
        }
        if ([self tryAmneziaBundle:data]) return;
    }
    [self importContent:data];
}

#pragma mark urls

+ (BOOL)handleOpenURL:(NSURL *)url {
    if (!url) return NO;
    if ([url isFileURL]) {
        [self importFileAtPath:[url path]];
        return YES;
    }
    NSString *scheme = [[url scheme] lowercaseString];
    NSString *whole = [url absoluteString];
    if ([scheme isEqualToString:@"legacyray"]) {
        NSString *host = [[url host] lowercaseString];
        NSString *rest = [whole substringFromIndex:MIN([whole length], [@"legacyray://" length] + [host length])];
        if ([rest hasPrefix:@"/"]) rest = [rest substringFromIndex:1];
        if ([host isEqualToString:@"import"] || [host isEqualToString:@"add"]) {
            NSString *payload = rest;
            NSRange q = [rest rangeOfString:@"url="];
            if (q.location != NSNotFound) payload = [rest substringFromIndex:q.location + 4];
            payload = [payload stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            [self importText:payload];
            return YES;
        }
        if ([host isEqualToString:@"connect"]) {
            [[LRTunnel shared] connect];
            return YES;
        }
        if ([host isEqualToString:@"disconnect"]) {
            [[LRTunnel shared] disconnect];
            return YES;
        }
        /* for activator's "open url" and the like: one gesture flips it */
        if ([host isEqualToString:@"toggle"]) {
            [[LRTunnel shared] toggle];
            return YES;
        }
        return NO;
    }
    [self importText:whole];
    return YES;
}
@end
