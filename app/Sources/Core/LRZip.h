/* just enough of the zip format to pull one named file out of an archive:
   stored and deflated entries, no encryption, no zip64 */
#import <Foundation/Foundation.h>

BOOL LRZipLooksLikeZip(NSData *data);
/* the entry whose last path component equals name (case-insensitive) */
NSData *LRZipEntryNamed(NSData *zip, NSString *name, NSString **error);
