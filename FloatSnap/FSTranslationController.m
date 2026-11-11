#import "FSTranslationController.h"
#import "FSLocale.h"
#import "FSCapture.h"
#import "FSImageComposition.h"
#import "FSLanguagePicker.h"
@interface FSTranslationController ()
@property(nonatomic,copy) NSString *original;
@property(nonatomic,copy) NSString *sourceLanguage;
@property(nonatomic,copy) NSString *targetLanguage;
@property(nonatomic,strong) UITextView *originalView;
@property(nonatomic,strong) UITextView *resultView;
@property(nonatomic,strong) UILabel *notice;
@property(nonatomic,strong) UIStackView *stack;
@property(nonatomic,strong) UIButton *sourceButton;
@property(nonatomic,strong) UIButton *targetButton;
@property(nonatomic,strong) UIButton *translateButton;
@property(nonatomic,strong) UIButton *resultCopyButton;
@property(nonatomic,strong) UIButton *imageSaveButton;
@property(nonatomic,strong) NSURLSession *session;
@property(nonatomic,strong) NSURLSessionDataTask *task;
@property(nonatomic) NSUInteger generation;
@end
@implementation FSTranslationController
- (instancetype)initWithText:(NSString *)text {
    if ((self=[super init])) {
        self.original=[text copy];
        NSString *detected=[NSLinguisticTagger dominantLanguageForString:text];
        self.sourceLanguage=[NSLocale.ISOLanguageCodes containsObject:detected?:@""]?detected:@"en";
        self.targetLanguage=[self.sourceLanguage isEqualToString:@"ar"]?@"en":@"ar";
    } return self;
}
- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.numberOfLines=2;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside]; return button;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=FSL(@"ترجمة المحدد",@"Translate selected"); self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.notice=[UILabel new]; self.notice.numberOfLines=0; self.notice.font=[UIFont systemFontOfSize:13]; self.notice.textAlignment=NSTextAlignmentCenter;
    self.notice.text=FSL(@"بالضغط على ترجمة ترسل النص إلى MyMemory عبر الإنترنت. الحد 500 بايت؛ اختر مقطعاً أقصر إذا لزم. راجع لغة المصدر قبل الإرسال.",@"Translate sends text to MyMemory online. Limit: 500 bytes. Check source language first.");
    self.sourceButton=[self button:@"" action:@selector(language:)]; self.sourceButton.tag=0;
    self.targetButton=[self button:@"" action:@selector(language:)]; self.targetButton.tag=1;
    UIStackView *languages=[[UIStackView alloc] initWithArrangedSubviews:@[self.sourceButton,self.targetButton]];
    languages.distribution=UIStackViewDistributionFillEqually;
    self.originalView=[UITextView new]; self.originalView.editable=NO; self.originalView.text=self.original; self.originalView.font=[UIFont systemFontOfSize:17]; self.originalView.backgroundColor=UIColor.secondarySystemBackgroundColor;
    self.resultView=[UITextView new]; self.resultView.editable=NO; self.resultView.font=[UIFont systemFontOfSize:17]; self.resultView.backgroundColor=UIColor.secondarySystemBackgroundColor;
    self.originalView.accessibilityLabel=FSL(@"النص الأصلي",@"Original text"); self.resultView.accessibilityLabel=FSL(@"الترجمة",@"Translation");
    self.translateButton=[self button:FSL(@"ترجمة عبر MyMemory",@"Translate with MyMemory") action:@selector(translate)];
    self.resultCopyButton=[self button:FSL(@"نسخ الترجمة",@"Copy translation") action:@selector(performResultCopy)]; self.resultCopyButton.enabled=NO; self.imageSaveButton.enabled=NO;
    UIStackView *copies=[[UIStackView alloc] initWithArrangedSubviews:@[[self button:FSL(@"نسخ الأصل",@"Copy original") action:@selector(performOriginalCopy)],self.resultCopyButton]];
    copies.distribution=UIStackViewDistributionFillEqually;
    self.stack=[[UIStackView alloc] initWithArrangedSubviews:@[self.notice,languages,self.originalView,self.translateButton,self.resultView,copies]];
    self.stack.axis=UILayoutConstraintAxisVertical; self.stack.spacing=8; self.stack.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:self.stack];
    UILayoutGuide *safe=self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[[self.stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],[self.stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],[self.stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],[self.stack.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8],[languages.heightAnchor constraintEqualToConstant:44],[copies.heightAnchor constraintEqualToConstant:44],[self.translateButton.heightAnchor constraintEqualToConstant:44],[self.originalView.heightAnchor constraintEqualToAnchor:self.resultView.heightAnchor]]];
    self.imageSaveButton=[self button:FSL(@"حفظ القصاصة مع الترجمة",@"Save clip with translation") action:@selector(saveIllustratedTranslation)];
    self.imageSaveButton.hidden=self.sourceImage==nil; self.imageSaveButton.enabled=NO;
    [self.stack addArrangedSubview:self.imageSaveButton];
    [self.imageSaveButton.heightAnchor constraintEqualToConstant:44].active=YES;
    [self updateLanguages];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.startsAutomatically) { self.startsAutomatically=NO; [self translate]; }
}
- (void)updateLanguages {
    [self.sourceButton setTitle:[FSL(@"من: ",@"From: ") stringByAppendingString:self.sourceLanguage] forState:UIControlStateNormal];
    [self.targetButton setTitle:[FSL(@"إلى: ",@"To: ") stringByAppendingString:self.targetLanguage] forState:UIControlStateNormal];
}
- (void)language:(UIButton *)sender {
    FSLanguagePicker *picker=[[FSLanguagePicker alloc] initWithStyle:UITableViewStyleInsetGrouped];
    NSInteger side=sender.tag;
    __weak typeof(self) weakSelf=self;
    picker.chosen=^(NSString *code) {
        FSTranslationController *controller=weakSelf;
        [controller cancelRequest];
        if (side==0) controller.sourceLanguage=code; else controller.targetLanguage=code;
        controller.resultView.text=@""; controller.resultCopyButton.enabled=NO; controller.imageSaveButton.enabled=NO;
        [controller updateLanguages];
    };
    [self.navigationController pushViewController:picker animated:YES];
}
- (void)cancelRequest {
    ++self.generation; [self.task cancel]; self.task=nil; [self.session invalidateAndCancel]; self.session=nil;
    self.translateButton.enabled=YES;
}
- (void)translate {
    if (FSDeviceIsLocked()) return;
    if ([self.original lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>500) { self.resultView.text=FSL(@"النص أطول من حد الخدمة. ارجع وحدد كلمات أقل.",@"Text exceeds the service limit. Select fewer words."); self.resultCopyButton.enabled=NO; self.imageSaveButton.enabled=NO; return; }
    if ([self.sourceLanguage isEqualToString:self.targetLanguage]) { self.resultView.text=FSL(@"اختر لغتين مختلفتين.",@"Choose two different languages."); self.resultCopyButton.enabled=NO; self.imageSaveButton.enabled=NO; return; }
    [self cancelRequest]; NSUInteger ticket=self.generation;
    self.resultView.text=FSL(@"جاري الترجمة…",@"Translating…"); self.resultCopyButton.enabled=NO; self.imageSaveButton.enabled=NO; self.translateButton.enabled=NO;
    NSURLComponents *url=[NSURLComponents componentsWithString:@"https://api.mymemory.translated.net/get"];
    url.queryItems=@[[NSURLQueryItem queryItemWithName:@"q" value:self.original],[NSURLQueryItem queryItemWithName:@"langpair" value:[NSString stringWithFormat:@"%@|%@",self.sourceLanguage,self.targetLanguage]]];
    NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration]; config.timeoutIntervalForRequest=20; config.timeoutIntervalForResource=25; config.URLCache=nil; config.HTTPCookieStorage=nil;
    self.session=[NSURLSession sessionWithConfiguration:config];
    __weak typeof(self) weakSelf=self;
    self.task=[self.session dataTaskWithURL:url.URL completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            FSTranslationController *controller=weakSelf;
            if (!controller || ticket!=controller.generation || FSDeviceIsLocked()) return;
            controller.task=nil; [controller.session finishTasksAndInvalidate]; controller.session=nil; controller.translateButton.enabled=YES;
            if (error || ![response isKindOfClass:NSHTTPURLResponse.class] || ((NSHTTPURLResponse *)response).statusCode!=200 || data.length>1024*1024) { controller.resultView.text=FSL(@"تعذّر الاتصال بخدمة الترجمة. حاول مجدداً.",@"Could not connect to translation service. Try again."); return; }
            id json=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
            id status=[json isKindOfClass:NSDictionary.class]?json[@"responseStatus"]:nil;
            id payload=[json isKindOfClass:NSDictionary.class]?json[@"responseData"]:nil;
            id translation=[payload isKindOfClass:NSDictionary.class]?payload[@"translatedText"]:nil;
            if (![status respondsToSelector:@selector(integerValue)] || [status integerValue]!=200 || ![translation isKindOfClass:NSString.class] || ![translation length]) { controller.resultView.text=FSL(@"الخدمة لم تُرجع ترجمة؛ قد يكون الحد اليومي انتهى أو زوج اللغات غير متاح.",@"No translation returned; quota or language pair may be unavailable."); return; }
            controller.resultView.text=translation; controller.resultCopyButton.enabled=YES; controller.imageSaveButton.enabled=controller.sourceImage!=nil;
        });
    }]; [self.task resume];
}
- (void)saveIllustratedTranslation {
    if (FSDeviceIsLocked() || !self.imageSaveButton.enabled) return;
    UIImage *image=FSImageWithTranslation(self.sourceImage,self.resultView.text);
    if (!image) { self.notice.text=FSL(@"تعذّر تجهيز الصورة؛ النص أو الصورة أكبر من حد الحفظ",@"Could not prepare image; content exceeds save limit"); return; }
    if (self.imageSaveRequested) self.imageSaveRequested(image);
}
- (void)performOriginalCopy { if (!FSDeviceIsLocked()) { UIPasteboard.generalPasteboard.string=self.original; self.notice.text=FSL(@"تم نسخ النص الأصلي. الترجمة ترسل النص إلى MyMemory عند الضغط فقط.",@"Original copied. Translation sends text only when tapped."); } }
- (void)performResultCopy { if (!FSDeviceIsLocked() && self.resultCopyButton.enabled) { UIPasteboard.generalPasteboard.string=self.resultView.text; self.notice.text=FSL(@"تم نسخ الترجمة.",@"Translation copied."); } }
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; if (self.isMovingFromParentViewController || self.navigationController.isBeingDismissed || !self.view.window) [self cancelRequest]; }
- (void)dealloc { [_task cancel]; [_session invalidateAndCancel]; }
@end
