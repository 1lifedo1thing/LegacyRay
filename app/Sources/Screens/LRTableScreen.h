/* a screen made of grouped rows. subclasses describe their content in
   -buildSections and call -reloadSections whenever the content changes */
#import "LRScreen.h"
#import "LRPlateCell.h"

@interface LRSectionSpec : NSObject {
    NSString *_header;
    NSString *_footer;
    NSArray *_rows;
}
@property (nonatomic, copy) NSString *header;
@property (nonatomic, copy) NSString *footer;
@property (nonatomic, retain) NSArray *rows;
+ (LRSectionSpec *)header:(NSString *)header rows:(NSArray *)rows footer:(NSString *)footer;
@end

@interface LRTableScreen : LRScreen <UITableViewDataSource, UITableViewDelegate> {
    UITableView *_tableView;
    NSArray *_sections;
    UIView *_tableHeader;
}
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, retain) NSArray *sections;
/* subclasses return LRSectionSpec objects */
- (NSArray *)buildSections;
- (void)reloadSections;
/* an optional view above the first section (instrument, summary card) */
- (void)setTableHeaderView:(UIView *)view;
@end
