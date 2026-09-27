/* paste or type links, a subscription url, a profile, or a whole list */
#import "LRScreen.h"
#import "LRTextField.h"

@interface LRManualInputScreen : LRScreen {
    LRTextWell *_well;
    UILabel *_hint;
    LRButton *_paste;
    LRButton *_import;
    CGFloat _keyboard;
}
@end
