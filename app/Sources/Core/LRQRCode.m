#import "LRQRCode.h"
#include "lr_qr.h"

static lr_qr_t *LRQREncode(NSString *text) {
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (![data length] || [data length] > LR_QR_MAX_BYTES) return NULL;
    lr_qr_t *q = (lr_qr_t *)malloc(sizeof *q);
    if (!q) return NULL;
    /* level M reads through a scratched screen protector; long payloads drop
       to L so the modules stay large enough to scan */
    lr_qr_ecc_t ecc = [data length] > 600 ? LR_QR_ECC_L : LR_QR_ECC_M;
    if (lr_qr_encode([data bytes], [data length], ecc, q) != 0) {
        free(q);
        return NULL;
    }
    return q;
}

int LRQRVersionForText(NSString *text) {
    lr_qr_t *q = LRQREncode(text);
    int v = q ? q->version : 0;
    free(q);
    return v;
}

UIImage *LRQRImage(NSString *text, CGFloat side) {
    lr_qr_t *q = LRQREncode(text);
    if (!q) return nil;
    CGFloat scale = [[UIScreen mainScreen] respondsToSelector:@selector(scale)]
        ? [UIScreen mainScreen].scale : 1;
    int quiet = 4;
    int total = q->size + quiet * 2;
    int px = (int)floorf(side * scale / total);
    if (px < 1) px = 1;
    int w = total * px;
    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    CGContextRef ctx = CGBitmapContextCreate(NULL, (size_t)w, (size_t)w, 8, (size_t)w, gray,
                                             (CGBitmapInfo)kCGImageAlphaNone);
    CGColorSpaceRelease(gray);
    if (!ctx) { free(q); return nil; }
    CGContextSetGrayFillColor(ctx, 1, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, w, w));
    CGContextSetGrayFillColor(ctx, 0, 1);
    for (int y = 0; y < q->size; ++y)
        for (int x = 0; x < q->size; ++x)
            if (lr_qr_dark(q, x, y))
                /* bitmap contexts count rows from the bottom */
                CGContextFillRect(ctx, CGRectMake((x + quiet) * px, w - (y + quiet + 1) * px, px, px));
    free(q);
    CGImageRef cg = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    if (!cg) return nil;
    UIImage *img = [UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)]
        ? [UIImage imageWithCGImage:cg scale:scale orientation:UIImageOrientationUp]
        : [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    return img;
}
