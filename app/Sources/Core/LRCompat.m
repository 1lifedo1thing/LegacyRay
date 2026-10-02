#import "LRSkin.h"
#import "LRCompat.h"

#import <dlfcn.h>

BOOL LRIsIOS7Native(void) {
    static int cached = -1;
    if (cached < 0) {
        cached = 0;
        if (LR_SYSTEM_AT_LEAST(@"7.0")) {
            /* the sdk the binary says it was made with; looked up at run time
               because ios 4 has no such function to link against */
            uint32_t (*sdk)(void) = (uint32_t (*)(void))dlsym(RTLD_DEFAULT, "dyld_get_program_sdk_version");
            cached = sdk && sdk() >= 0x00070000 ? 1 : 0;
        }
    }
    return cached == 1;
}

CGFloat LRStatusBarOverlap(UIView *view) {
    if (!LRIsIOS7Native() || !view.window) return 0;
    UIApplication *app = [UIApplication sharedApplication];
    if (app.statusBarHidden) return 0;
    CGRect bar = [view convertRect:app.statusBarFrame fromView:nil];
    CGRect hit = CGRectIntersection(bar, view.bounds);
    if (CGRectIsNull(hit) || hit.size.height <= 0 || hit.origin.y > 1) return 0;
    return MIN(CGRectGetMaxY(hit), 40.0f);
}

void LRApplyStatusBarStyle(void) {
    UIApplication *app = [UIApplication sharedApplication];
    LRSkin *s = [LRSkin current];
    UIStatusBarStyle style;
    if (LRIsIOS7Native())
        /* 0 dark text, 1 light text (UIStatusBarStyleLightContent on ios 7):
           light over the denim bars */
        style = s->flat ? UIStatusBarStyleDefault : (UIStatusBarStyle)1;
    else
        /* the black bar ios 6 puts over dark navigation bars */
        style = s->flat ? UIStatusBarStyleDefault : UIStatusBarStyleBlackOpaque;
    [app setStatusBarStyle:style animated:NO];
}

void LRAnimateIn(NSTimeInterval duration, void (^animations)(void)) {
    if ([LRSkin current]->flat &&
        [UIView respondsToSelector:@selector(animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:)]) {
        [UIView animateWithDuration:duration * 1.6 delay:0 usingSpringWithDamping:0.78f initialSpringVelocity:0
                            options:UIViewAnimationOptionAllowUserInteraction animations:animations completion:nil];
        return;
    }
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut
                     animations:animations completion:nil];
}

void LRPresentModal(UIViewController *host, UIViewController *vc, BOOL animated) {
    if (!host || !vc) return;
    if ([host respondsToSelector:@selector(presentViewController:animated:completion:)])
        [host presentViewController:vc animated:animated completion:nil];
    else
        [host presentModalViewController:vc animated:animated];
}

void LRDismissModal(UIViewController *vc, BOOL animated) {
    if (!vc) return;
    if ([vc respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
        [vc dismissViewControllerAnimated:animated completion:nil];
    else
        [vc dismissModalViewControllerAnimated:animated];
}

UIViewController *LRTopViewController(void) {
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    if (!window) {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        if ([windows count]) window = [windows objectAtIndex:0];
    }
    UIViewController *top = [window rootViewController];
    for (;;) {
        UIViewController *next = [top respondsToSelector:@selector(presentedViewController)]
            ? [top presentedViewController] : [top modalViewController];
        if (!next) break;
        top = next;
    }
    return top;
}

UIImage *LRImageWithSize(CGSize size, BOOL opaque, void (^draw)(CGContextRef ctx, CGRect rect)) {
    if (size.width <= 0 || size.height <= 0) return nil;
    UIGraphicsBeginImageContextWithOptions(size, opaque, LRScreenScale());
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (draw) draw(ctx, CGRectMake(0, 0, size.width, size.height));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

UIImage *LRStretchable(UIImage *image, CGFloat left, CGFloat top) {
    return [image stretchableImageWithLeftCapWidth:(NSInteger)left topCapHeight:(NSInteger)top];
}

NSString *LRTrim(NSString *s) {
    if (![s isKindOfClass:[NSString class]]) return nil;
    NSString *t = [s stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [t length] ? t : nil;
}

NSString *LRBytes(unsigned long long bytes) {
    if (bytes < 1024ULL) return [NSString stringWithFormat:@"%llu %@", bytes, L(@"B")];
    double v = (double)bytes / 1024.0;
    NSArray *units = [NSArray arrayWithObjects:L(@"KB"), L(@"MB"), L(@"GB"), L(@"TB"), nil];
    NSUInteger u = 0;
    while (v >= 1024.0 && u + 1 < [units count]) {
        v /= 1024.0;
        ++u;
    }
    NSString *fmt = v >= 100.0 ? @"%.0f %@" : (v >= 10.0 ? @"%.1f %@" : @"%.2f %@");
    NSString *text = [NSString stringWithFormat:fmt, v, [units objectAtIndex:u]];
    /* "12,4 ГБ": a russian reader expects the decimal comma */
    if (LRCurrentLanguage() == LRLanguageRussian)
        text = [text stringByReplacingOccurrencesOfString:@"." withString:@","];
    return text;
}

NSString *LRSpeed(double bps) {
    if (bps < 0) bps = 0;
    if (bps < 1024.0) return [NSString stringWithFormat:@"%.0f %@", bps, L(@"B/s")];
    if (bps < 1024.0 * 1024.0) return [NSString stringWithFormat:@"%.0f %@", bps / 1024.0, L(@"KB/s")];
    NSString *text = [NSString stringWithFormat:@"%.1f %@", bps / (1024.0 * 1024.0), L(@"MB/s")];
    if (LRCurrentLanguage() == LRLanguageRussian)
        text = [text stringByReplacingOccurrencesOfString:@"." withString:@","];
    return text;
}

NSString *LRDuration(long seconds) {
    if (seconds < 0) seconds = 0;
    long d = seconds / 86400;
    long h = (seconds / 3600) % 24;
    long m = (seconds / 60) % 60;
    long s = seconds % 60;
    if (d > 0) return [NSString stringWithFormat:@"%ldd %02ld:%02ld", d, h, m];
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", h, m, s];
}
