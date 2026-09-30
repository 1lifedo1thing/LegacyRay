#import "LRTextField.h"
#import "LRDraw.h"

/* the ios 6 rounded rect field: white, a grey rim, a little shade inside
   the top edge; flat: a white box with a hairline */
static UIImage *LRWellImage(void) {
    BOOL flat = SKIN->flat;
    UIImage *img = LRImageWithSize(CGSizeMake(21, 36), NO, ^(CGContextRef ctx, CGRect rect) {
        CGRect body = CGRectMake(0.5f, 0.5f, 20, 34);
        if (flat) {
            LRAddRoundRect(ctx, body, 5);
            [[UIColor whiteColor] setFill];
            CGContextFillPath(ctx);
            LRAddRoundRect(ctx, body, 5);
            [SKIN->separator setStroke];
            CGContextSetLineWidth(ctx, LRHairline());
            CGContextStrokePath(ctx);
            return;
        }
        LRAddRoundRect(ctx, CGRectOffset(body, 0, 1), 7);
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.6f);
        CGContextFillPath(ctx);
        CGContextSaveGState(ctx);
        LRAddRoundRect(ctx, body, 7);
        CGContextClip(ctx);
        [[UIColor whiteColor] setFill];
        CGContextFillRect(ctx, body);
        LRFillVertical(ctx, CGRectMake(0, 0, 21, 4), [UIColor colorWithWhite:0 alpha:0.16f],
                       [UIColor colorWithWhite:0 alpha:0]);
        CGContextRestoreGState(ctx);
        LRAddRoundRect(ctx, body, 7);
        CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.38f);
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokePath(ctx);
    });
    return LRStretchable(img, 10, 17);
}

@implementation LRTextField

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        LRSkin *s = SKIN;
        self.background = LRWellImage();
        self.borderStyle = UITextBorderStyleNone;
        self.font = [LRSkin bodyFont:s->flat ? 15 : 17];
        self.textColor = s->groupInk;
        self.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        self.autocorrectionType = UITextAutocorrectionTypeNo;
        self.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.clearButtonMode = UITextFieldViewModeWhileEditing;
        self.keyboardAppearance = UIKeyboardAppearanceDefault;
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
        _textView.textColor = s->groupInk;
        _textView.autocorrectionType = UITextAutocorrectionTypeNo;
        _textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _textView.keyboardAppearance = UIKeyboardAppearanceDefault;
        [self addSubview:_textView];
    }
    return self;
}

- (void)dealloc {
    [_textView release];
    [super dealloc];
}
@end
