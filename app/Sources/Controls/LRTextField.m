#import "LRTextField.h"
#import "LRDraw.h"

static UIImage *LRWellImage(void) {
    LRSkin *s = SKIN;
    UIColor *top = s->night ? [UIColor colorWithWhite:0.10f alpha:1] : [UIColor colorWithWhite:0.93f alpha:1];
    UIColor *bottom = s->night ? [UIColor colorWithWhite:0.17f alpha:1] : [UIColor whiteColor];
    UIImage *img = LRImageWithSize(CGSizeMake(21, 36), NO, ^(CGContextRef ctx, CGRect rect) {
        LRDrawInsetWell(ctx, CGRectMake(1, 1, 19, 33), 6, top, bottom, 0.7f);
    });
    return LRStretchable(img, 10, 17);
}

@implementation LRTextField

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        LRSkin *s = SKIN;
        self.background = LRWellImage();
        self.borderStyle = UITextBorderStyleNone;
        self.font = [LRSkin bodyFont:15];
        self.textColor = s->night ? [UIColor colorWithWhite:0.92f alpha:1] : [UIColor colorWithWhite:0.12f alpha:1];
        self.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        self.autocorrectionType = UITextAutocorrectionTypeNo;
        self.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.clearButtonMode = UITextFieldViewModeWhileEditing;
        self.keyboardAppearance = s->night ? UIKeyboardAppearanceAlert : UIKeyboardAppearanceDefault;
    }
    return self;
}

- (CGRect)textRectForBounds:(CGRect)bounds {
    return CGRectInset(bounds, 10, 2);
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
    CGRect r = CGRectInset(bounds, 10, 2);
    r.size.width -= 18;
    return r;
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds {
    return CGRectInset(bounds, 10, 2);
}

- (void)drawPlaceholderInRect:(CGRect)rect {
    [LRColorAlpha(self.textColor, 0.35f) set];
    CGSize s = [self.placeholder sizeWithFont:self.font];
    CGRect r = CGRectMake(rect.origin.x, rect.origin.y + (rect.size.height - s.height) / 2,
                          rect.size.width, s.height);
    [self.placeholder drawInRect:r withFont:self.font lineBreakMode:NSLineBreakByTruncatingTail
                       alignment:NSTextAlignmentLeft];
}
@end

@implementation LRTextWell
@synthesize textView = _textView;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        LRSkin *s = SKIN;
        UIImageView *bg = [[[UIImageView alloc] initWithFrame:self.bounds] autorelease];
        bg.image = LRWellImage();
        bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:bg];
        _textView = [[UITextView alloc] initWithFrame:CGRectInset(self.bounds, 4, 4)];
        _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _textView.backgroundColor = [UIColor clearColor];
        _textView.font = [LRSkin monoFont:13];
        _textView.textColor = s->night ? [UIColor colorWithWhite:0.9f alpha:1] : [UIColor colorWithWhite:0.12f alpha:1];
        _textView.autocorrectionType = UITextAutocorrectionTypeNo;
        _textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _textView.keyboardAppearance = s->night ? UIKeyboardAppearanceAlert : UIKeyboardAppearanceDefault;
        [self addSubview:_textView];
    }
    return self;
}

- (void)dealloc {
    [_textView release];
    [super dealloc];
}
@end
