#import <UIKit/UIKit.h>
#import <notify.h>
#import "../FSLocale.h"
@interface PSViewController : UIViewController
@end
@interface FSRootListController : PSViewController <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) NSUserDefaults *prefs;
@end
@implementation FSRootListController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"FloatSnap";
    self.prefs=[[NSUserDefaults alloc] initWithSuiteName:@"local.floatsnap.tweak"];
    [self.prefs registerDefaults:@{@"Enabled":@YES,@"LockScreenEnabled":@YES,@"DoublePressFullScreen":@YES,@"DoublePressInterval":@0.4,@"DoubleTapToPin":@YES,@"Dimming":@0.45,@"ArabicOCR":@YES}];
    self.table=[[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.table.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.table.dataSource=self; self.table.delegate=self;
    self.table.rowHeight=UITableViewAutomaticDimension; self.table.estimatedRowHeight=64;
    self.table.semanticContentAttribute=FSArabicUI()?UISemanticContentAttributeForceRightToLeft:UISemanticContentAttributeForceLeftToRight;
    [self.view addSubview:self.table];
    UIView *header=[[UIView alloc] initWithFrame:CGRectMake(0,0,320,210)];
    UIImage *logo=[UIImage imageNamed:@"Icon.png" inBundle:[NSBundle bundleForClass:self.class] compatibleWithTraitCollection:nil];
    UIImageView *image=[[UIImageView alloc] initWithImage:logo];
    image.frame=CGRectMake(110,16,100,100); image.contentMode=UIViewContentModeScaleAspectFit;
    image.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
    [header addSubview:image];
    UILabel *title=[[UILabel alloc] initWithFrame:CGRectMake(0,126,320,40)];
    title.text=@"FloatSnap"; title.font=[UIFont boldSystemFontOfSize:30]; title.textAlignment=NSTextAlignmentCenter;
    title.autoresizingMask=UIViewAutoresizingFlexibleWidth; [header addSubview:title];
    UILabel *subtitle=[[UILabel alloc] initWithFrame:CGRectMake(0,170,320,24)];
    subtitle.text=FSL(@"التقط اللحظة • 0.9.9.9",@"Capture the moment • 0.9.9.9"); subtitle.textColor=UIColor.secondaryLabelColor;
    subtitle.textAlignment=NSTextAlignmentCenter; subtitle.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    [header addSubview:subtitle]; self.table.tableHeaderView=header;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 5; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; return section==0?3:section==1?3:section==4?3:1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView; return @[FSL(@"عام",@"General"),FSL(@"التحكم بالالتقاط",@"Capture Controls"),FSL(@"المظهر",@"Appearance"),FSL(@"إعادة الضبط",@"Reset"),FSL(@"المطور والتواصل",@"Developer & Contact")][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    return @[FSL(@"يمكن قص محتوى شاشة القفل؛ تبقى القصاصة بعد فتح الجهاز للحفظ أو المشاركة.",@"Crop Lock Screen content; clips remain after unlocking for saving or sharing. Arabic OCR is offline; disable it for other Vision-supported languages."),FSL(@"كل لقطة جديدة تبدأ تحديداً جديداً. ضغطتان سريعتان للقطة كاملة إذا كان الخيار مفعلاً. اسحب للتحريك أو تغيير الحجم.",@"Each new screenshot starts a fresh selection. Two quick presses take a full screenshot when enabled. Drag to move or resize."),FSL(@"يُعتّم ما خارج التحديد فقط. يسري التغيير على التحديد القادم.",@"Only the area outside your selection is dimmed. Changes apply to the next selection."),@"",FSL(@"البريد يفتح مسودة ولا يرسل شيئاً تلقائياً.",@"Email opens a draft. No message is sent automatically.")][section];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)index {
    (void)tableView;
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle=UITableViewCellSelectionStyleNone;
    cell.textLabel.numberOfLines=0;
    if (index.section==4) {
        NSArray *titles=@[@"Filp Max",FSL(@"تابع على X",@"Follow on X"),FSL(@"البريد الإلكتروني",@"Email")];
        NSArray *details=@[FSL(@"مطور FloatSnap",@"FloatSnap Developer"),@"@filpmax7",@"filpmax7@gmail.com"];
        cell.textLabel.text=titles[index.row]; cell.detailTextLabel.text=details[index.row];
        cell.detailTextLabel.numberOfLines=0;
        if (index.row>0) {
            NSString *asset=index.row==1?@"ContactX":@"ContactMail";
            cell.imageView.image=[UIImage imageNamed:asset inBundle:[NSBundle bundleForClass:self.class] compatibleWithTraitCollection:nil];
            cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle=UITableViewCellSelectionStyleDefault;
        } else cell.imageView.image=[UIImage systemImageNamed:@"person.crop.circle"];
        return cell;
    }
    if (index.section==3) { cell.textLabel.text=FSL(@"استعادة الإعدادات الأصلية",@"Reset to Defaults"); cell.textLabel.textColor=UIColor.systemRedColor; cell.selectionStyle=UITableViewCellSelectionStyleDefault; return cell; }
    if (index.section==2 || (index.section==1 && index.row==1)) {
        BOOL dim=index.section==2;
        cell.textLabel.text=dim?FSL(@"تعتيم الخلفية",@"Background Dimming"):FSL(@"فاصل الضغطتين",@"Double-Press Interval");
        UISlider *slider=[[UISlider alloc] initWithFrame:CGRectMake(0,0,155,44)];
        slider.minimumValue=dim?0:0.2; slider.maximumValue=dim?0.75:0.8;
        slider.accessibilityIdentifier=dim?@"Dimming":@"DoublePressInterval";
        slider.accessibilityLabel=cell.textLabel.text;
        slider.value=[self.prefs doubleForKey:slider.accessibilityIdentifier];
        cell.detailTextLabel.text=dim?[NSString stringWithFormat:@"%.0f%%",slider.value*100]:[NSString stringWithFormat:@"%.2f seconds",slider.value];
        [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView=slider; return cell;
    }
    NSArray *keys=index.section==0?@[@"Enabled",@"LockScreenEnabled",@"ArabicOCR"]:@[@"DoublePressFullScreen",@"",@"DoubleTapToPin"];
    NSArray *labels=index.section==0?@[FSL(@"تفعيل FloatSnap",@"Enable FloatSnap"),FSL(@"التفعيل على شاشة القفل",@"Enable on Lock Screen"),FSL(@"استخراج العربية والإنجليزية محلياً",@"Offline Arabic and English OCR")]:@[FSL(@"ضغطتان للقطة كاملة",@"Double Press for Full Screenshot"),@"",FSL(@"ضغطتان لتثبيت التحديد",@"Double Tap to Pin Selection")];
    cell.textLabel.text=labels[index.row];
    UISwitch *toggle=[[UISwitch alloc] init]; toggle.accessibilityIdentifier=keys[index.row];
    toggle.accessibilityLabel=cell.textLabel.text; toggle.on=[self.prefs boolForKey:keys[index.row]];
    [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView=toggle; return cell;
}
- (void)publish { [self.prefs synchronize]; notify_post("local.floatsnap.preferences.changed"); }
- (void)toggleChanged:(UISwitch *)sender { [self.prefs setBool:sender.on forKey:sender.accessibilityIdentifier]; [self publish]; }
- (void)sliderChanged:(UISlider *)sender {
    [self.prefs setDouble:sender.value forKey:sender.accessibilityIdentifier]; [self publish];
    UIView *view=sender; while(view && ![view isKindOfClass:UITableViewCell.class]) view=view.superview;
    UITableViewCell *cell=(UITableViewCell *)view;
    cell.detailTextLabel.text=[sender.accessibilityIdentifier isEqualToString:@"Dimming"]?[NSString stringWithFormat:@"%.0f%%",sender.value*100]:[NSString stringWithFormat:@"%.2f seconds",sender.value];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)index {
    [tableView deselectRowAtIndexPath:index animated:YES];
    if (index.section==4 && index.row>0) {
        NSString *address=index.row==1?@"https://x.com/filpmax7?s=11":@"mailto:filpmax7@gmail.com";
        NSString *contact=index.row==1?@"https://x.com/filpmax7?s=11":@"filpmax7@gmail.com";
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:address] options:@{} completionHandler:^(BOOL success) {
            if (success) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Unable to Open App" message:contact preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Copy" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { (void)action; UIPasteboard.generalPasteboard.string=contact; }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            });
        }]; return;
    }
    if(index.section!=3) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Reset to Defaults?" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action;
        for(NSString *key in @[@"Enabled",@"LockScreenEnabled",@"DoublePressFullScreen",@"DoublePressInterval",@"DoubleTapToPin",@"Dimming",@"ArabicOCR"]) [self.prefs removeObjectForKey:key];
        [self publish]; [self.table reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
