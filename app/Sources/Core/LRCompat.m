#import "LRCompat.h"

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
    if (bytes < 1024ULL) return [NSString stringWithFormat:@"%llu B", bytes];
    double v = (double)bytes / 1024.0;
    NSArray *units = [NSArray arrayWithObjects:@"KB", @"MB", @"GB", @"TB", nil];
    NSUInteger u = 0;
    while (v >= 1024.0 && u + 1 < [units count]) {
        v /= 1024.0;
        ++u;
    }
    NSString *fmt = v >= 100.0 ? @"%.0f %@" : (v >= 10.0 ? @"%.1f %@" : @"%.2f %@");
    return [NSString stringWithFormat:fmt, v, [units objectAtIndex:u]];
}

NSString *LRSpeed(double bps) {
    if (bps < 0) bps = 0;
    if (bps < 1024.0) return [NSString stringWithFormat:@"%.0f B/s", bps];
    if (bps < 1024.0 * 1024.0) return [NSString stringWithFormat:@"%.0f KB/s", bps / 1024.0];
    return [NSString stringWithFormat:@"%.1f MB/s", bps / (1024.0 * 1024.0)];
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
