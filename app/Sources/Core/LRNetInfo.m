#import "LRNetInfo.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <netinet/in.h>

@implementation LRNetInfo

+ (SCNetworkReachabilityFlags)flags {
    struct sockaddr_in zero;
    memset(&zero, 0, sizeof zero);
    zero.sin_len = sizeof zero;
    zero.sin_family = AF_INET;
    SCNetworkReachabilityRef r = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zero);
    SCNetworkReachabilityFlags flags = 0;
    if (r) {
        SCNetworkReachabilityGetFlags(r, &flags);
        CFRelease(r);
    }
    return flags;
}

+ (BOOL)online {
    SCNetworkReachabilityFlags f = [self flags];
    return (f & kSCNetworkReachabilityFlagsReachable) &&
           !(f & kSCNetworkReachabilityFlagsConnectionRequired);
}

+ (NSString *)interfaceKind {
    SCNetworkReachabilityFlags f = [self flags];
    if (!(f & kSCNetworkReachabilityFlagsReachable)) return L(@"Offline");
    if (f & kSCNetworkReachabilityFlagsIsWWAN) return L(@"Cellular");
    return @"Wi-Fi";
}

+ (NSString *)localIPv4 {
    struct ifaddrs *list = NULL;
    if (getifaddrs(&list) != 0) return nil;
    NSString *wifi = nil, *cell = nil;
    for (struct ifaddrs *a = list; a; a = a->ifa_next) {
        if (!a->ifa_addr || a->ifa_addr->sa_family != AF_INET || !(a->ifa_flags & IFF_UP)) continue;
        char buf[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &((struct sockaddr_in *)a->ifa_addr)->sin_addr, buf, sizeof buf);
        if (strcmp(a->ifa_name, "en0") == 0) wifi = [NSString stringWithUTF8String:buf];
        else if (strncmp(a->ifa_name, "pdp_ip", 6) == 0 && !cell) cell = [NSString stringWithUTF8String:buf];
    }
    freeifaddrs(list);
    return wifi ? wifi : cell;
}

+ (NSString *)wifiName {
    if (CNCopySupportedInterfaces == NULL || CNCopyCurrentNetworkInfo == NULL) return nil;
    NSArray *ifs = [(NSArray *)CNCopySupportedInterfaces() autorelease];
    for (NSString *name in ifs) {
        NSDictionary *info = [(NSDictionary *)CNCopyCurrentNetworkInfo((CFStringRef)name) autorelease];
        NSString *ssid = [info objectForKey:@"SSID"];
        if ([ssid length]) return ssid;
    }
    return nil;
}
@end
