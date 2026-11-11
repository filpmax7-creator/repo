#import "FSOCRText.h"
#import "FSWordSelectionController.h"
#import "FSLocale.h"
#import <math.h>
#import "FSTranslationController.h"
#import "FSCapture.h"

@interface FSWordCell : UICollectionViewCell
@property(nonatomic,strong) UILabel *wordLabel;
@end
@implementation FSWordCell
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.wordLabel=[UILabel new]; self.wordLabel.textAlignment=NSTextAlignmentCenter;
        self.wordLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        self.wordLabel.adjustsFontForContentSizeCategory=YES; self.wordLabel.numberOfLines=0;
        [self.contentView addSubview:self.wordLabel]; self.contentView.layer.cornerRadius=10;
        self.isAccessibilityElement=YES;
    } return self;
}
- (void)layoutSubviews { [super layoutSubviews]; self.wordLabel.frame=CGRectInset(self.contentView.bounds,10,8); }
@end
@interface FSWordFlowLayout : UICollectionViewFlowLayout
@end
@implementation FSWordFlowLayout
- (BOOL)flipsHorizontallyInOppositeLayoutDirection { return YES; }
@end
@interface FSWordSelectionController () <UICollectionViewDataSource,UICollectionViewDelegateFlowLayout>
@property(nonatomic,copy) NSString *sourceText;
@property(nonatomic,strong) NSArray<NSTextCheckingResult *> *tokens;
@property(nonatomic,strong) NSMutableIndexSet *chosen;
@property(nonatomic,strong) UICollectionView *collection;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UIStackView *actions;
@property(nonatomic,strong) UIButton *selectionCopyButton;
@property(nonatomic,strong) UIButton *translateButton;
@end
@implementation FSWordSelectionController
- (instancetype)initWithText:(NSString *)text {
    if ((self=[super init])) {
        self.sourceText=[text copy]; self.chosen=[NSMutableIndexSet indexSet];
        NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"\\S+" options:0 error:NULL];
        self.tokens=[regex matchesInString:text options:0 range:NSMakeRange(0,text.length)];
    } return self;
}
- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    button.titleLabel.adjustsFontForContentSizeCategory=YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=FSL(@"اختيار الكلمات",@"Select words"); self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:FSL(@"إغلاق",@"Close") style:UIBarButtonItemStyleDone target:self action:@selector(close)];
    self.status=[UILabel new]; self.status.textAlignment=NSTextAlignmentCenter; self.status.numberOfLines=0;
    self.status.font=[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.status.adjustsFontForContentSizeCategory=YES; [self.view addSubview:self.status];
    FSWordFlowLayout *layout=[FSWordFlowLayout new]; layout.minimumInteritemSpacing=8; layout.minimumLineSpacing=8;
    layout.sectionInset=UIEdgeInsetsMake(12,12,12,12);
    self.collection=[[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collection.backgroundColor=UIColor.systemBackgroundColor;
    NSString *language=[NSLinguisticTagger dominantLanguageForString:self.sourceText];
    BOOL rtl=FSArabicReadingDirection(self.sourceText) || [@[@"ar",@"he",@"fa",@"ur"] containsObject:language ?: @""];
    self.collection.semanticContentAttribute=rtl?UISemanticContentAttributeForceRightToLeft:UISemanticContentAttributeForceLeftToRight;
    [self.collection registerClass:FSWordCell.class forCellWithReuseIdentifier:@"word"];
    self.collection.dataSource=self; self.collection.delegate=self; [self.view addSubview:self.collection];
    self.selectionCopyButton=[self button:FSL(@"نسخ المحدد",@"Copy selected") action:@selector(performCopyWords)];
    self.translateButton=[self button:FSL(@"ترجمة المحدد",@"Translate selected") action:@selector(translateSelected)];
    self.actions=[[UIStackView alloc] initWithArrangedSubviews:@[[self button:FSL(@"تحديد الكل",@"Select all") action:@selector(selectAll)], [self button:FSL(@"إلغاء التحديد",@"Clear selection") action:@selector(clearSelection)],self.selectionCopyButton,self.translateButton]];
    self.actions.axis=UILayoutConstraintAxisVertical; self.actions.distribution=UIStackViewDistributionFillEqually;
    [self.view addSubview:self.actions]; [self updateStatus];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}
- (void)textSizeChanged:(NSNotification *)notification {
    (void)notification; [self.collection.collectionViewLayout invalidateLayout]; [self.view setNeedsLayout];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; CGRect safe=self.view.safeAreaLayoutGuide.layoutFrame;
    CGFloat actionsHeight=176,statusHeight=60;
    self.status.frame=CGRectMake(safe.origin.x+12,safe.origin.y,MAX(0,safe.size.width-24),statusHeight);
    self.actions.frame=CGRectMake(safe.origin.x+12,CGRectGetMaxY(safe)-actionsHeight,MAX(0,safe.size.width-24),actionsHeight);
    self.collection.frame=CGRectMake(safe.origin.x,CGRectGetMaxY(self.status.frame),safe.size.width,MAX(1,safe.size.height-actionsHeight-statusHeight));
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section { (void)collectionView; (void)section; return self.tokens.count; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    FSWordCell *cell=[collectionView dequeueReusableCellWithReuseIdentifier:@"word" forIndexPath:indexPath];
    NSString *word=[self.sourceText substringWithRange:self.tokens[indexPath.item].range];
    BOOL selected=[self.chosen containsIndex:indexPath.item];
    cell.wordLabel.text=word; cell.wordLabel.textColor=selected?UIColor.whiteColor:UIColor.labelColor;
    cell.contentView.backgroundColor=selected?UIColor.systemBlueColor:UIColor.secondarySystemBackgroundColor;
    cell.accessibilityLabel=word; cell.accessibilityTraits=UIAccessibilityTraitButton|(selected?UIAccessibilityTraitSelected:0);
    return cell;
}
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    (void)collectionViewLayout;
    NSString *word=[self.sourceText substringWithRange:self.tokens[indexPath.item].range];
    CGFloat maxWidth=MAX(44,collectionView.bounds.size.width-24);
    CGRect bounds=[word boundingRectWithSize:CGSizeMake(MAX(1,maxWidth-20),CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]} context:nil];
    return CGSizeMake(MIN(maxWidth,MAX(44,ceil(bounds.size.width)+20)),MAX(44,ceil(bounds.size.height)+16));
}
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger index=indexPath.item;
    if ([self.chosen containsIndex:index]) [self.chosen removeIndex:index]; else [self.chosen addIndex:index];
    [collectionView deselectItemAtIndexPath:indexPath animated:NO];
    [collectionView reloadItemsAtIndexPaths:@[indexPath]]; [self updateStatus];
}
- (void)updateStatus {
    self.status.text=self.chosen.count?[NSString stringWithFormat:FSL(@"المحدد: %lu من %lu — النسخ بترتيب النص",@"Selected: %lu of %lu — copied in text order"),(unsigned long)self.chosen.count,(unsigned long)self.tokens.count]:FSL(@"اضغط الكلمات لاختيارها؛ علامات الترقيم تبقى مع الكلمة",@"Tap words to select; punctuation stays with words");
    self.selectionCopyButton.enabled=self.chosen.count>0;
    self.translateButton.enabled=self.chosen.count>0;
}
- (void)selectAll { [self.chosen addIndexesInRange:NSMakeRange(0,self.tokens.count)]; [self.collection reloadData]; [self updateStatus]; }
- (void)clearSelection { [self.chosen removeAllIndexes]; [self.collection reloadData]; [self updateStatus]; }
- (NSString *)selectedText {
    if (!self.chosen.count) return @"";
    if (self.chosen.count==self.tokens.count) return self.sourceText;
    NSMutableString *result=[NSMutableString string];
    NSUInteger previous=NSNotFound;
    for (NSUInteger index=self.chosen.firstIndex;index!=NSNotFound;index=[self.chosen indexGreaterThanIndex:index]) {
        NSRange range=self.tokens[index].range;
        if (previous!=NSNotFound) {
            NSRange prior=self.tokens[previous].range;
            NSString *gap=[self.sourceText substringWithRange:NSMakeRange(NSMaxRange(prior),range.location-NSMaxRange(prior))];
            if (index==previous+1) [result appendString:gap];
            else [result appendString:[gap rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location!=NSNotFound?@"\n":@" "];
        }
        [result appendString:[self.sourceText substringWithRange:range]]; previous=index;
    }
    return result;
}
- (void)performCopyWords {
    NSString *text=[self selectedText];
    if (text.length && self.textCopyRequested) self.textCopyRequested(text);
}
- (void)translateSelected {
    if (FSDeviceIsLocked()) return;
    NSString *text=[self selectedText]; if (!text.length) return;
    FSTranslationController *translation=[[FSTranslationController alloc] initWithText:text];
    translation.sourceImage=self.sourceImage; translation.imageSaveRequested=self.imageSaveRequested;
    [self.navigationController pushViewController:translation animated:YES];
}
- (void)close { if (self.closeRequested) self.closeRequested(); }
@end
