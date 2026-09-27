/* text input sunk into the plate: a dark or paper well with padding */
#import <UIKit/UIKit.h>

@interface LRTextField : UITextField
@end

/* multi-line input in the same well */
@interface LRTextWell : UIView {
    UITextView *_textView;
}
@property (nonatomic, readonly) UITextView *textView;
@end
