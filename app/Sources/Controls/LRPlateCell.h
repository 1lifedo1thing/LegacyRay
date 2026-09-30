/* grouped table rows. classic: the ios 6 grouped row (white, grey rim,
   blue when pressed); flat: white rows with ios 7 hairlines. the row content
   is described by LRRow so screens stay declarative */
#import <UIKit/UIKit.h>
#import "LRToggleSwitch.h"
#import "LRDraw.h"

typedef enum {
    LRRowValue = 0,     /* title + detail, chevron when it has an action */
    LRRowSwitch,        /* title + toggle */
    LRRowButton,        /* centred title */
    LRRowText,          /* a paragraph */
    LRRowCheck          /* title with a check mark when on */
} LRRowKind;

typedef enum {
    LRRowStyleNormal = 0,
    LRRowStyleAccent,
    LRRowStyleDestructive,
    LRRowStyleMuted
} LRRowStyle;

@interface LRRow : NSObject {
    LRRowKind _kind;
    LRRowStyle _style;
    NSString *_title;
    NSString *_detail;
    NSString *_subtitle;
    NSString *_flagCode;
    UIImage *_icon;
    UIColor *_detailColor;
    BOOL _on;
    BOOL _enabled;
    BOOL _chevron;
    BOOL _monospace;
    void (^_action)(LRRow *row, UIView *cell);
    void (^_changed)(BOOL on);
    id _userInfo;
}
@property (nonatomic, assign) LRRowKind kind;
@property (nonatomic, assign) LRRowStyle style;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *flagCode;
@property (nonatomic, retain) UIImage *icon;
@property (nonatomic, retain) UIColor *detailColor;
@property (nonatomic, assign) BOOL on;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL chevron;
@property (nonatomic, assign) BOOL monospace;
@property (nonatomic, copy) void (^action)(LRRow *row, UIView *cell);
@property (nonatomic, copy) void (^changed)(BOOL on);
@property (nonatomic, retain) id userInfo;

+ (LRRow *)value:(NSString *)title detail:(NSString *)detail
          action:(void (^)(LRRow *row, UIView *cell))action;
+ (LRRow *)toggle:(NSString *)title on:(BOOL)on changed:(void (^)(BOOL on))changed;
+ (LRRow *)button:(NSString *)title style:(LRRowStyle)style
           action:(void (^)(LRRow *row, UIView *cell))action;
+ (LRRow *)text:(NSString *)text;
+ (LRRow *)check:(NSString *)title on:(BOOL)on action:(void (^)(LRRow *row, UIView *cell))action;
@end

@interface LRPlateCell : UITableViewCell {
    LRRow *_row;
    LRPlatePosition _position;
    CGFloat _margin;
    UILabel *_title;
    UILabel *_detail;
    UILabel *_subtitle;
    LRToggleSwitch *_toggle;
    UIView *_plate;
    UIView *_pressedPlate;
    UIView *_decor;
}
@property (nonatomic, readonly) LRRow *row;
@property (nonatomic, readonly) LRToggleSwitch *toggle;
- (void)configure:(LRRow *)row position:(LRPlatePosition)position margin:(CGFloat)margin;
+ (CGFloat)heightForRow:(LRRow *)row width:(CGFloat)width margin:(CGFloat)margin;
@end

/* the side margin of grouped plates for a table width */
CGFloat LRPlateMargin(CGFloat tableWidth);
