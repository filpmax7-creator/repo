#import "FSIcons.h"
#import "FSCardView.h"
#import "FSLocale.h"
#import <QuartzCore/QuartzCore.h>

@interface FSCardView () <UIGestureRecognizerDelegate>
@property(nonatomic, strong, readwrite) UIImage *image;
@property(nonatomic, strong) UIImageView *preview;
@property(nonatomic, strong) UIScrollView *toolbar;
@property(nonatomic, strong) UIButton *closeButton;
@property(nonatomic, strong) UIButton *shareButton;
@property(nonatomic, strong) UIButton *saveButton;
@property(nonatomic, strong) UIButton *lockButton;
@property(nonatomic) BOOL positionLocked;
@property(nonatomic,strong) UIButton *editButton;
@property(nonatomic,strong) UIButton *mergeButton;
@end

@implementation FSCardView
- (instancetype)initWithImage:(UIImage *)image {
    CGFloat width = MIN(300, MAX(180, image.size.width));
    CGFloat imageHeight = MIN(300, MAX(60, width * image.size.height / MAX(1, image.size.width)));
    if ((self = [super initWithFrame:CGRectMake(24, 160, width, imageHeight + 44)])) {
        _image = image;
        self.backgroundColor = [UIColor colorWithWhite:0.09 alpha:1];
        self.layer.cornerRadius = 16;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor.systemTealColor colorWithAlphaComponent:0.6].CGColor;
        self.clipsToBounds = YES;
        _preview = [[UIImageView alloc] initWithImage:image];
        _preview.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_preview];
        _toolbar = [[UIScrollView alloc] init];
        _toolbar.showsHorizontalScrollIndicator=YES;
        self.multipleTouchEnabled=YES;
        _toolbar.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
        [self addSubview:_toolbar];
        _closeButton = [self button:@"xmark" label:FSL(@"إغلاق اللقطة",@"Close clip") action:@selector(close)];
        _shareButton = [self button:@"square.and.arrow.up" label:FSL(@"مشاركة اللقطة",@"Share clip") action:@selector(share)];
        _saveButton = [self button:@"photo" label:FSL(@"حفظ في الصور",@"Save to Photos") action:@selector(save)];
        _lockButton=[self button:@"lock.open" label:FSL(@"قفل مكان القصاصة",@"Lock clip position") action:@selector(togglePositionLock)];
        _editButton=[self button:@"pencil" label:FSL(@"تعديل القصاصة",@"Edit clip") action:@selector(editImage)];
        _mergeButton=[self button:@"rectangle.stack" label:FSL(@"دمج القصاصات",@"Merge clips") action:@selector(mergeImages)];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        pan.maximumNumberOfTouches = 1;
        pan.delegate = self;
        [self addGestureRecognizer:pan];
        UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(resize:)];
        pinch.delegate = self;
        [self addGestureRecognizer:pinch];
    }
    return self;
}
- (UIButton *)button:(NSString *)symbol label:(NSString *)label action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:FSIcon(symbol) forState:UIControlStateNormal];
    button.tintColor = UIColor.whiteColor;
    button.accessibilityLabel = label;
    if ([label isEqualToString:FSL(@"حفظ في الصور",@"Save to Photos")]) {
        UIButtonConfiguration *configuration=[UIButtonConfiguration plainButtonConfiguration];
        configuration.image=FSIcon(@"photo");
        configuration.imagePlacement=NSDirectionalRectEdgeTop;
        configuration.imagePadding=1;
        configuration.preferredSymbolConfigurationForImage=[UIImageSymbolConfiguration configurationWithPointSize:18];

        configuration.baseForegroundColor=UIColor.whiteColor;
        configuration.contentInsets=NSDirectionalEdgeInsetsMake(2,0,2,0);
        button.configuration=configuration;
    }

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.toolbar addSubview:button];
    return button;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width;
    self.toolbar.frame = CGRectMake(0, 0, width, 44);
    NSArray<UIButton *> *buttons=@[self.closeButton,self.saveButton,self.lockButton,self.editButton,self.mergeButton,self.shareButton];
    CGFloat buttonWidth=MAX(44,width/buttons.count);
    self.toolbar.contentSize=CGSizeMake(buttonWidth*buttons.count,44);
    for (NSUInteger i=0;i<buttons.count;i++) buttons[i].frame=CGRectMake(i*buttonWidth,0,buttonWidth,44);
    self.preview.frame = CGRectMake(0, 44, width, self.bounds.size.height - 44);
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    (void)gesture;
    for (UIView *view = touch.view; view && view != self; view = view.superview) {
        if ([view isKindOfClass:UIControl.class] || view==self.toolbar) return NO;
    }
    return YES;
}
- (void)drag:(UIPanGestureRecognizer *)gesture {
    if (self.positionLocked) return;
    [self.superview bringSubviewToFront:self];
    CGPoint delta = [gesture translationInView:self.superview];
    self.center = CGPointMake(self.center.x + delta.x, self.center.y + delta.y);
    [gesture setTranslation:CGPointZero inView:self.superview];
    [self fitInside:self.superview.safeAreaLayoutGuide.layoutFrame];
}
- (void)resize:(UIPinchGestureRecognizer *)gesture {
    if (self.positionLocked) return;
    [self.superview bringSubviewToFront:self];
    CGRect area = self.superview.safeAreaLayoutGuide.layoutFrame;
    if (CGRectIsEmpty(area)) area=self.superview.bounds;
    CGFloat width = MAX(MIN(100, area.size.width), MIN(area.size.width, self.bounds.size.width * gesture.scale));
    CGFloat ratio = self.image.size.height / MAX(1,self.image.size.width);
    CGFloat height = MIN(area.size.height, MAX(80,width * ratio + 44));
    self.bounds = CGRectMake(0, 0, width, height);
    gesture.scale = 1;
    [self fitInside:area];
}
- (void)fitInside:(CGRect)area {
    if (CGRectIsEmpty(area)) return;
    CGRect frame = self.frame;
    frame.size.width = MIN(frame.size.width, area.size.width);
    frame.size.height = MIN(frame.size.height, area.size.height);
    frame.origin.x = MAX(CGRectGetMinX(area), MIN(frame.origin.x, CGRectGetMaxX(area) - frame.size.width));
    frame.origin.y = MAX(CGRectGetMinY(area), MIN(frame.origin.y, CGRectGetMaxY(area) - frame.size.height));
    self.frame = frame;
}
- (void)setPositionPinned:(BOOL)pinned { if (self.positionLocked!=pinned) [self togglePositionLock]; }
- (void)togglePositionLock {
    self.positionLocked=!self.positionLocked;
    [self.lockButton setImage:FSIcon(self.positionLocked?@"lock.fill":@"lock.open") forState:UIControlStateNormal];
    self.lockButton.tintColor=self.positionLocked?UIColor.systemYellowColor:UIColor.whiteColor;
    self.lockButton.accessibilityLabel=self.positionLocked?FSL(@"فتح قفل مكان القصاصة",@"Unlock clip position"):FSL(@"قفل مكان القصاصة",@"Lock clip position");
}
- (void)replaceImage:(UIImage *)image {
    if (!image.CGImage) return;
    self.image=image; self.preview.image=image;
}
- (void)editImage { if (self.editRequested) self.editRequested(self); }
- (void)mergeImages { if (self.mergeRequested) self.mergeRequested(self); }
- (void)save { if (self.saveRequested) self.saveRequested(self); }
- (void)close { if (self.closeRequested) self.closeRequested(self); }
- (void)share { if (self.shareRequested) self.shareRequested(self); }
@end
