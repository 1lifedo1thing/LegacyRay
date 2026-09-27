/* a qr code as a crisp UIImage: whole device pixels per module and a four
   module quiet zone, so any scanner reads it off the screen */
#import <UIKit/UIKit.h>

/* nil when the text does not fit a qr code at all */
UIImage *LRQRImage(NSString *text, CGFloat side);
/* the version (1..40) the text needs, 0 when it does not fit */
int LRQRVersionForText(NSString *text);
