#import "LRTableScreen.h"
#import "LRDraw.h"

@implementation LRSectionSpec
@synthesize header = _header, footer = _footer, rows = _rows;
+ (LRSectionSpec *)header:(NSString *)header rows:(NSArray *)rows footer:(NSString *)footer {
    LRSectionSpec *s = [[[LRSectionSpec alloc] init] autorelease];
    s.header = header;
    s.rows = rows;
    s.footer = footer;
    return s;
}
- (void)dealloc {
    [_header release];
    [_footer release];
    [_rows release];
    [super dealloc];
}
@end

@implementation LRTableScreen
@synthesize tableView = _tableView, sections = _sections;

- (void)dealloc {
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    [_tableView release];
    [_sections release];
    [_tableHeader release];
    [super dealloc];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    [_tableView release];
    _tableView = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _tableView = [[UITableView alloc] initWithFrame:self.contentView.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.backgroundView = nil;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.indicatorStyle = UIScrollViewIndicatorStyleDefault;
    [self.contentView addSubview:_tableView];
    if (_tableHeader) _tableView.tableHeaderView = _tableHeader;
    [self reloadSections];
}

- (BOOL)wantsContentUnderHeader {
    return YES;
}

- (void)layoutContent {
    _tableView.frame = self.contentView.bounds;
    LRApplyHeaderCoverage(_tableView, self.headerCoverage);
}

/* ios 7 resets a cell's background just before showing it */
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = [UIColor clearColor];
}

- (NSArray *)buildSections {
    return [NSArray array];
}

- (void)reloadSections {
    self.sections = [self buildSections];
    [_tableView reloadData];
}

- (void)setTableHeaderView:(UIView *)view {
    [_tableHeader release];
    _tableHeader = [view retain];
    if (_tableView) _tableView.tableHeaderView = view;
}

/* every section is laid out as [header row] + rows + [footer row]: plain
   table views pin section headers while scrolling, and the grouped style's
   own insets differ between ios 4, 6 and the ios 7 compatibility mode, so the
   headers here are ordinary rows that scroll with their plates */
- (LRRow *)rowAt:(NSIndexPath *)ip {
    if (ip.section >= (NSInteger)[_sections count]) return nil;
    NSArray *rows = [[_sections objectAtIndex:ip.section] rows];
    NSInteger i = ip.row - 1;
    return i >= 0 && i < (NSInteger)[rows count] ? [rows objectAtIndex:(NSUInteger)i] : nil;
}

- (BOOL)isHeader:(NSIndexPath *)ip {
    return ip.row == 0;
}

- (BOOL)isFooter:(NSIndexPath *)ip {
    return ip.row == (NSInteger)[[[_sections objectAtIndex:ip.section] rows] count] + 1;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)[_sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[[[_sections objectAtIndex:section] rows] count] + 2;
}

- (CGFloat)margin {
    return LRPlateMargin(_tableView.bounds.size.width);
}

- (UIFont *)captionFont:(BOOL)header {
    if (SKIN->flat) return [LRSkin bodyFont:13];
    return header ? [LRSkin boldFont:17] : [LRSkin bodyFont:15];
}

/* captions line up with the text in the rows */
- (CGFloat)captionInset {
    return [self margin] + (SKIN->flat ? 15 : 10);
}

- (NSString *)captionText:(NSString *)text header:(BOOL)header {
    return SKIN->flat && header ? [text uppercaseString] : text;
}

- (CGFloat)heightForCaption:(NSString *)text header:(BOOL)header last:(BOOL)last {
    CGFloat width = _tableView.bounds.size.width;
    if (![text length]) {
        if (header) return SKIN->flat ? 24 : 14;
        return last ? 26 : 6;
    }
    CGFloat inset = [self captionInset];
    CGSize ts = [[self captionText:text header:header] sizeWithFont:[self captionFont:header]
                                                  constrainedToSize:CGSizeMake(width - inset * 2, 400)];
    CGFloat h = ceilf(ts.height) + (header ? (SKIN->flat ? 32 : 22) : 16);
    return last ? h + 20 : h;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)ip {
    LRSectionSpec *spec = [_sections objectAtIndex:ip.section];
    if ([self isHeader:ip]) return [self heightForCaption:spec.header header:YES last:NO];
    if ([self isFooter:ip])
        return [self heightForCaption:spec.footer header:NO
                                 last:ip.section == (NSInteger)[_sections count] - 1];
    return [LRPlateCell heightForRow:[self rowAt:ip] width:tableView.bounds.size.width margin:[self margin]];
}

- (UITableViewCell *)captionCell:(UITableView *)tableView text:(NSString *)text header:(BOOL)header
                          height:(CGFloat)h {
    NSString *ident = header ? @"caption-h" : @"caption-f";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
    UILabel *l = nil;
    if (!cell) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:ident] autorelease];
        cell.backgroundColor = [UIColor clearColor];
        cell.backgroundView = [[[UIView alloc] init] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        l = [[[UILabel alloc] init] autorelease];
        l.tag = 42;
        l.backgroundColor = [UIColor clearColor];
        l.numberOfLines = 0;
        [cell.contentView addSubview:l];
    }
    l = (UILabel *)[cell.contentView viewWithTag:42];
    LRSkin *s = SKIN;
    l.text = [self captionText:text header:header];
    l.font = [self captionFont:header];
    l.textAlignment = !s->flat && !header ? NSTextAlignmentCenter : NSTextAlignmentLeft;
    l.textColor = s->groupHeader;
    l.shadowColor = s->flat ? nil : s->groupHeaderShadow;
    l.shadowOffset = CGSizeMake(0, 1);
    CGFloat width = tableView.bounds.size.width;
    CGFloat inset = [self captionInset];
    CGSize ts = [l.text sizeWithFont:l.font constrainedToSize:CGSizeMake(width - inset * 2, 400)];
    CGFloat y = header ? h - ceilf(ts.height) - 7 : 7;
    l.frame = CGRectMake(inset, y, width - inset * 2, ceilf(ts.height));
    l.hidden = ![text length];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)ip {
    LRSectionSpec *spec = [_sections objectAtIndex:ip.section];
    if ([self isHeader:ip] || [self isFooter:ip]) {
        BOOL header = [self isHeader:ip];
        return [self captionCell:tableView text:header ? spec.header : spec.footer header:header
                          height:[self tableView:tableView heightForRowAtIndexPath:ip]];
    }
    LRPlateCell *cell = (LRPlateCell *)[tableView dequeueReusableCellWithIdentifier:@"plate"];
    if (!cell) cell = [[[LRPlateCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:@"plate"] autorelease];
    NSInteger n = (NSInteger)[spec.rows count];
    NSInteger i = ip.row - 1;
    LRPlatePosition pos = n == 1 ? LRPlateSingle
        : (i == 0 ? LRPlateTop : (i == n - 1 ? LRPlateBottom : LRPlateMiddle));
    [cell configure:[self rowAt:ip] position:pos margin:[self margin]];
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)ip {
    LRRow *row = [self rowAt:ip];
    return row && row.enabled && row.action ? ip : nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tableView deselectRowAtIndexPath:ip animated:YES];
    LRRow *row = [self rowAt:ip];
    if (!row.enabled || !row.action) return;
    row.action(row, [tableView cellForRowAtIndexPath:ip]);
}
@end
