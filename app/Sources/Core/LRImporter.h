/* everything that brings servers in: the import menu, pasted or scanned text,
   files opened from other apps or iTunes file sharing, legacyray:// links and
   karing backups. classifies the input, confirms what needs confirming and
   hands the rest to the daemon's parsers */
#import <UIKit/UIKit.h>

@interface LRImporter : NSObject
/* the menu behind every "+" button */
+ (void)showMenuFrom:(UIView *)anchor host:(UIViewController *)host;
+ (void)importText:(NSString *)text;
+ (void)importFileAtPath:(NSString *)path;
+ (void)importData:(NSData *)data filename:(NSString *)filename;
/* url schemes: legacyray://import?url=..., legacyray://add/<link>, vless://... */
+ (BOOL)handleOpenURL:(NSURL *)url;
+ (void)pasteFromClipboard;
+ (void)promptSubscription;
/* the documents folder the file browser lists (itunes file sharing) */
+ (NSString *)documentsPath;
@end
