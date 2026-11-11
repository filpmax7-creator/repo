#import "FSMergeController.h"
#import "FSLocale.h"
#import "FSImageComposition.h"
@interface FSMergeController () <UITableViewDataSource,UITableViewDelegate>
@property(nonatomic,strong) NSArray<UIImage *> *images;
@property(nonatomic,strong) NSMutableArray<NSNumber *> *order;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) UISegmentedControl *direction;
@property(nonatomic,strong) UILabel *hint;
@property(nonatomic,strong) UIImageView *preview;
@property(nonatomic,strong) UIImage *merged;
@end
@implementation FSMergeController
- (instancetype)initWithImages:(NSArray<UIImage *> *)images { if ((self=[super init])) { self.images=[images copy]; self.order=[NSMutableArray array]; } return self; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=FSL(@"دمج القصاصات",@"Merge clips"); self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:FSL(@"إلغاء",@"Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:FSL(@"حفظ في الصور",@"Save to Photos") style:UIBarButtonItemStyleDone target:self action:@selector(save)];
    self.navigationItem.rightBarButtonItem.enabled=NO;
    self.direction=[[UISegmentedControl alloc] initWithItems:@[FSL(@"عمودي",@"Vertical"),FSL(@"أفقي",@"Horizontal")]]; self.direction.selectedSegmentIndex=0;
    [self.direction addTarget:self action:@selector(invalidatePreview) forControlEvents:UIControlEventValueChanged]; [self.view addSubview:self.direction];
    self.hint=[UILabel new]; self.hint.text=FSL(@"اختر قصاصتين أو أكثر بترتيب الدمج، ثم اضغط معاينة",@"Select two or more clips in order, then preview"); self.hint.numberOfLines=2; self.hint.textAlignment=NSTextAlignmentCenter; [self.view addSubview:self.hint];
    self.table=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain]; self.table.dataSource=self; self.table.delegate=self; self.table.rowHeight=64; [self.view addSubview:self.table];
    self.preview=[UIImageView new]; self.preview.contentMode=UIViewContentModeScaleAspectFit; self.preview.backgroundColor=UIColor.secondarySystemBackgroundColor; [self.view addSubview:self.preview];
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem]; button.tag=70; [button setTitle:FSL(@"معاينة الدمج",@"Merge preview") forState:UIControlStateNormal]; [button addTarget:self action:@selector(renderPreview) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:button];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; CGRect safe=self.view.safeAreaLayoutGuide.layoutFrame; CGFloat width=safe.size.width;
    self.direction.frame=CGRectMake(12,safe.origin.y+8,width-24,32); self.hint.frame=CGRectMake(12,safe.origin.y+44,width-24,52);
    CGFloat tableHeight=MIN(240,MAX(64,(safe.size.height-150)*0.5)); self.table.frame=CGRectMake(0,safe.origin.y+100,width,tableHeight);
    [self.view viewWithTag:70].frame=CGRectMake(12,CGRectGetMaxY(self.table.frame),width-24,44);
    self.preview.frame=CGRectMake(12,CGRectGetMaxY(self.table.frame)+48,width-24,MAX(1,CGRectGetMaxY(safe)-CGRectGetMaxY(self.table.frame)-56));
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; (void)section; return self.images.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"image"];
    if (!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"image"];
    cell.imageView.image=self.images[indexPath.row]; cell.textLabel.text=[NSString stringWithFormat:FSL(@"قصاصة %ld",@"Clip %ld"),(long)indexPath.row+1];
    NSUInteger index=[self.order indexOfObject:@(indexPath.row)]; cell.accessoryType=index==NSNotFound?UITableViewCellAccessoryNone:UITableViewCellAccessoryCheckmark;
    cell.detailTextLabel.text=index==NSNotFound?FSL(@"غير محددة",@"Not selected"):[NSString stringWithFormat:FSL(@"الترتيب %lu",@"Order %lu"),(unsigned long)index+1]; return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSNumber *index=@(indexPath.row); if ([self.order containsObject:index]) [self.order removeObject:index]; else [self.order addObject:index];
    [tableView deselectRowAtIndexPath:indexPath animated:YES]; [tableView reloadData]; [self invalidatePreview];
}
- (void)invalidatePreview { self.merged=nil; self.preview.image=nil; self.navigationItem.rightBarButtonItem.enabled=NO; }
- (void)renderPreview {
    if (self.order.count<2) { self.hint.text=FSL(@"اختر قصاصتين على الأقل",@"Select at least two clips"); return; }
    NSMutableArray *images=[NSMutableArray array]; for (NSNumber *index in self.order) [images addObject:self.images[index.unsignedIntegerValue]];
    self.merged=FSMergeImages(images,self.direction.selectedSegmentIndex==1); self.preview.image=self.merged;
    self.navigationItem.rightBarButtonItem.enabled=self.merged!=nil;
    self.hint.text=self.merged?FSL(@"المعاينة جاهزة؛ الحفظ ينشئ صورة واحدة ويحافظ على القصاصات",@"Preview ready; save makes one image and keeps the clips"):FSL(@"تعذّر إنشاء الصورة",@"Could not create image");
}
- (void)save { if (self.merged && self.finished) self.finished(self.merged); }
- (void)cancel { if (self.finished) self.finished(nil); }
@end
