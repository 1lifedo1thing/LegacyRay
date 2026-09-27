/* small reusable screens: a pick-one list, a read-only text page with copy
   and share, and a text editor */
#import "LRTableScreen.h"
#import "LRTextField.h"

@interface LRChoiceScreen : LRTableScreen {
    NSArray *_options;
    NSArray *_notes;
    NSInteger _selected;
    NSString *_footer;
    void (^_picked)(NSInteger index);
}
- (id)initWithTitle:(NSString *)title options:(NSArray *)options selected:(NSInteger)selected
             picked:(void (^)(NSInteger index))picked;
/* optional subtitle per option */
@property (nonatomic, retain) NSArray *notes;
@property (nonatomic, copy) NSString *footer;
@end

@interface LRTextScreen : LRScreen <UIDocumentInteractionControllerDelegate> {
    NSString *_text;
    UITextView *_textView;
    NSString *_fileName;
    id _documentController;
    void (^_reload)(LRTextScreen *screen);
}
- (id)initWithTitle:(NSString *)title text:(NSString *)text;
/* the file name "Share" writes the text to, in Documents */
@property (nonatomic, copy) NSString *fileName;
/* a Refresh key appears when set */
@property (nonatomic, copy) void (^reload)(LRTextScreen *screen);
- (void)setText:(NSString *)text;
@end

@interface LRTextEditScreen : LRScreen {
    NSString *_initial;
    LRTextWell *_well;
    void (^_save)(NSString *text, LRTextEditScreen *screen);
    CGFloat _keyboard;
}
- (id)initWithTitle:(NSString *)title text:(NSString *)text
               save:(void (^)(NSString *text, LRTextEditScreen *screen))save;
@end
