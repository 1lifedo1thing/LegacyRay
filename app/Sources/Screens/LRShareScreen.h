/* sharing a station or a profile the way happ and amnezia do: a large qr code
   on a card, the text under it, and copy / file / mail. stealth mode keeps the
   code covered until asked, so a screenshot does not give the server away */
#import "LRScreen.h"
#import <MessageUI/MessageUI.h>

@interface LRShareScreen : LRScreen <UIDocumentInteractionControllerDelegate,
                                     MFMailComposeViewControllerDelegate> {
    NSString *_payload;
    NSString *_subtitle;
    NSString *_fileName;
    UIView *_card;
    UIImageView *_qr;
    UILabel *_nameLabel;
    UILabel *_textLabel;
    UILabel *_note;
    LRButton *_copyButton;
    LRButton *_sendButton;
    LRButton *_revealButton;
    BOOL _revealed;
    UIDocumentInteractionController *_document;
}
- (id)initWithTitle:(NSString *)title payload:(NSString *)payload;
@property (nonatomic, copy) NSString *subtitle;   /* a line under the name */
@property (nonatomic, copy) NSString *fileName;   /* for save / open in / mail */
@end
