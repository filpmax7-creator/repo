#import "FSLanguagePicker.h"
#import "FSLocale.h"
@interface FSLanguagePicker () <UISearchResultsUpdating>
@property(nonatomic,strong) NSArray<NSString *> *codes;
@property(nonatomic,strong) NSArray<NSString *> *visibleCodes;
@property(nonatomic,strong) UISearchController *search;
@end
@implementation FSLanguagePicker
- (NSString *)label:(NSString *)code { return [NSLocale.currentLocale localizedStringForLanguageCode:code] ?: code; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=FSL(@"اختر اللغة",@"Choose language");
    self.codes=[NSLocale.ISOLanguageCodes sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b) { return [[self label:a] localizedCaseInsensitiveCompare:[self label:b]]; }];
    self.visibleCodes=self.codes;
    self.search=[[UISearchController alloc] initWithSearchResultsController:nil]; self.search.searchResultsUpdater=self; self.search.obscuresBackgroundDuringPresentation=NO;
    self.search.searchBar.placeholder=FSL(@"اسم اللغة أو رمزها",@"Language name or code"); self.navigationItem.searchController=self.search; self.definesPresentationContext=YES;
    self.navigationItem.hidesSearchBarWhenScrolling=NO;
    UILabel *footer=[[UILabel alloc] initWithFrame:CGRectMake(0,0,320,64)]; footer.numberOfLines=0; footer.textAlignment=NSTextAlignmentCenter;
    footer.font=[UIFont systemFontOfSize:13]; footer.text=FSL(@"توفّر الترجمة يحدده مزوّد الخدمة؛ ظهور اللغة هنا لا يضمن دعم كل أزواج اللغات.",@"Availability depends on the provider; listed languages may not support every pair."); self.tableView.tableFooterView=footer;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; (void)section; return self.visibleCodes.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)index {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"language"];
    if (!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"language"];
    NSString *code=self.visibleCodes[index.row]; cell.textLabel.text=[self label:code]; cell.detailTextLabel.text=code; return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)index {
    [tableView deselectRowAtIndexPath:index animated:YES]; NSString *code=self.visibleCodes[index.row];
    if (self.chosen) self.chosen(code); [self.navigationController popViewControllerAnimated:YES];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query=[searchController.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!query.length) self.visibleCodes=self.codes;
    else self.visibleCodes=[self.codes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *code,NSDictionary *bindings) {
        (void)bindings; return [code localizedCaseInsensitiveContainsString:query] || [[self label:code] localizedCaseInsensitiveContainsString:query];
    }]];
    [self.tableView reloadData];
}
@end
