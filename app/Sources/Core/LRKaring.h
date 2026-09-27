/* karing interoperability: a karing backup is a zip with
   karing_subscribe.json inside; "LAN send" shows a karing://sync-download/
   QR code with the sender's addresses, and the backup is fetched from
   http://<ip>:<port>/sync-download */
#import <Foundation/Foundation.h>

/* NSDictionary items: "url", optional "name" */
NSArray *LRKaringSubscriptionsFromBackup(NSData *zip, NSString **error);

BOOL LRKaringIsLANLink(NSString *text);
/* download the backup from the first address that answers; on a background
   queue, answers on the main queue */
void LRKaringFetchLAN(NSString *link, void (^done)(NSData *zip, NSString *error));
