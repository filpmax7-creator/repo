#import "FSOCRText.h"
#import <CoreImage/CoreImage.h>
#import "FSIcons.h"
#import "FSArabicOCR.h"
#import "FSOverlayController.h"
#import "FSCapture.h"
#import "FSPreferences.h"
#import "FSDiagnostics.h"
#import "FSSelectionView.h"
#import "FSCardView.h"
#import "FSLocale.h"
#import "FSEditorController.h"
#import "FSWordSelectionController.h"
#import "FSTranslationController.h"
#import "FSMergeController.h"
#import <QuartzCore/QuartzCore.h>
#import <notify.h>
#import <math.h>
#import <Vision/Vision.h>
#import <Photos/Photos.h>

@interface FSOverlayWindow : UIWindow
@property(nonatomic) BOOL modalTouch;
@property(nonatomic, weak) FSSelectionView *captureTouchView;
@property(nonatomic) BOOL lockPresentation;
@end

@implementation FSOverlayWindow
- (BOOL)_canShowWhileLocked { return self.lockPresentation && FSPrefBool(@"LockScreenEnabled",YES); }
- (BOOL)canBecomeKeyWindow { return self.modalTouch; }
- (void)makeKeyWindow {
    if (self.modalTouch) [super makeKeyWindow];
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    FSSelectionView *selector=self.captureTouchView;
    if (!self.modalTouch && selector && !selector.hidden && selector.window==self && !self.hidden) {
        CGPoint local=[self convertPoint:point toView:selector];
        if ([selector pointInside:local withEvent:event]) return [selector hitTest:local withEvent:event] ?: selector;
    }
    UIView *hit = [super hitTest:point withEvent:event];
    if (!self.modalTouch && (hit == self || hit == self.rootViewController.view)) return nil;
    return hit;
}
@end

@interface FSOverlayController () <UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate>
@property(nonatomic, strong) FSOverlayWindow *overlay;
@property(nonatomic, strong) NSMutableArray<FSCardView *> *cards;
@property(nonatomic, strong) FSSelectionView *selectorView;
@property(nonatomic, strong) UILabel *toast;
@property(nonatomic, strong) FSCardView *recentlyClosed;
@property(nonatomic, strong) UIButton *undoButton;
@property(nonatomic) NSUInteger undoGeneration;
@property(nonatomic) BOOL undoLocked;
@property(nonatomic, weak) UIWindow *previousKeyWindow;
@property(nonatomic) BOOL capturing;
@property(nonatomic) BOOL fullShotBusy;
@property(nonatomic) NSInteger nextEditorTool;
@property(nonatomic) BOOL lastLocked;
@property(nonatomic) BOOL selectionLocked;
@property(nonatomic) int preferencesToken;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) CGSize lastSize;
@property(nonatomic) CGSize captureCanvas;
@property(nonatomic) int lockToken;
@property(nonatomic) BOOL analysisBusy;
@property(nonatomic) BOOL photoSaveBusy;
@property(nonatomic, strong) NSURL *exportURL;
@end

@implementation FSOverlayController
+ (instancetype)sharedController {
    static FSOverlayController *controller;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controller = [self new]; });
    return controller;
}
- (UIWindowScene *)displayScene {
    UIWindowScene *choice = nil;
    NSInteger bestScore = -1;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if (![candidate isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *scene = (UIWindowScene *)candidate;
        if (scene.screen != UIScreen.mainScreen) continue;
        if (scene.activationState != UISceneActivationStateForegroundActive &&
            scene.activationState != UISceneActivationStateForegroundInactive) continue;
        NSInteger score = scene.activationState == UISceneActivationStateForegroundActive ? 2 : 0;
        for (UIWindow *window in scene.windows) {
            if (window != self.overlay && window.isKeyWindow && !window.hidden) { score += 1; break; }
        }
        if (score > bestScore) { choice = scene; bestScore = score; }
    }
    return choice;
}
- (BOOL)attachDisplayScene {
    UIWindowScene *scene = [self displayScene];
    if (!scene) {
        FSLog([NSString stringWithFormat:@"No foreground main-display scene; connected scenes=%lu", (unsigned long)UIApplication.sharedApplication.connectedScenes.count]);
        for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
            FSLog([NSString stringWithFormat:@"Scene candidate class=%@ state=%ld", NSStringFromClass(candidate.class), (long)candidate.activationState]);
        }
        self.overlay.hidden = YES;
        return NO;
    }
    if (self.overlay.windowScene != scene) {
        self.overlay.hidden = YES;
        self.overlay.windowScene = scene;
    }
    self.overlay.frame = scene.coordinateSpace.bounds;
    // Order relative to actual visible windows, rather than assuming 2100 is enough.
    CGFloat level = UIWindowLevelAlert + 100;
    for (UIWindow *window in scene.windows) {
        if (window == self.overlay || window.hidden || window.alpha < 0.01) continue;
        level = MAX(level, window.windowLevel + 1);
    }
    self.overlay.windowLevel = level;
    [self.overlay setNeedsLayout];
    [self.overlay layoutIfNeeded];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    FSLog([NSString stringWithFormat:@"Display attached: scene=%@ state=%ld windows=%lu level=%.0f", NSStringFromClass(scene.class), (long)scene.activationState, (unsigned long)scene.windows.count, (double)level]);
    return YES;
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    FSLog(@"Overlay viewDidAppear callback");
}
- (void)start {
    if (self.overlay) return;
    self.cards = [NSMutableArray array];
    self.nextEditorTool=-1;
    UIWindowScene *scene = [self displayScene];
    self.overlay = scene ? [[FSOverlayWindow alloc] initWithWindowScene:scene] :
        [[FSOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.overlay.frame = scene ? scene.coordinateSpace.bounds : UIScreen.mainScreen.bounds;
    self.overlay.backgroundColor = UIColor.clearColor;
    self.overlay.windowLevel = UIWindowLevelAlert + 100;
    self.overlay.rootViewController = self;
    self.overlay.hidden = YES;
    self.lockToken = -1;
    __weak typeof(self) weakSelf = self;
    int token = -1;
    uint32_t status = notify_register_dispatch("com.apple.springboard.lockstate", &token,
        dispatch_get_main_queue(), ^(int callbackToken) {
            (void)callbackToken;
            [weakSelf refreshLockState];
        });
    if (status != NOTIFY_STATUS_OK) {
        FSLog(@"Lock-state notification registration failed; overlay disabled");
        return;
    }
    self.lockToken = token;
    self.lastLocked=FSDeviceIsLocked();
    notify_register_dispatch("local.floatsnap.preferences.changed", &_preferencesToken, dispatch_get_main_queue(), ^(int value) {
        (void)value; [weakSelf cancelCapture]; [weakSelf clearCards]; [weakSelf refreshLockState];
    });
    FSLog(@"Overlay created; lock observer registered");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(memoryWarning:)
        name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [self refreshLockState];
}
- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = UIColor.clearColor;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize size = self.view.bounds.size;
    if (!CGSizeEqualToSize(self.lastSize, CGSizeZero) && !CGSizeEqualToSize(self.lastSize, size)) {
        // An in-flight capture belongs to the previous coordinate system.
        [self cancelCapture];
    }
    self.lastSize = size;
    CGRect safe = [self safeArea];
    for (FSCardView *card in self.cards) [card fitInside:safe];
    self.selectorView.frame = self.view.bounds;
    self.undoButton.frame=CGRectMake(CGRectGetMidX(safe)-26,CGRectGetMaxY(safe)-58,52,50);
    self.toast.frame = CGRectMake(20, CGRectGetMaxY(safe) - 80, size.width - 40, 60);
}
- (CGRect)safeArea {
    CGRect safe = self.view.safeAreaLayoutGuide.layoutFrame;
    return CGRectIsEmpty(safe) ? CGRectInset(self.view.bounds, 8, 32) : CGRectInset(safe, 8, 8);
}
- (void)refreshLockState {
    BOOL locked=FSDeviceIsLocked();
    self.overlay.lockPresentation=NO;
    if (locked!=self.lastLocked || !FSCanCaptureVisibleScreen()) {
        BOOL unlockingWithClips=self.lastLocked && !locked && FSCanCaptureVisibleScreen();
        [self cancelCapture];
        // Clips made on the lock screen remain available after authentication.
        // Entering the lock screen still removes content from the prior session.
        if (!unlockingWithClips) [self clearCards];
        [self dismissViewControllerAnimated:NO completion:^{ [self cleanupExport]; }];
        [self restoreWindow]; [self.toast removeFromSuperview]; self.toast=nil;
    }
    self.lastLocked=locked;
    self.overlay.lockPresentation=locked && FSCanCaptureVisibleScreen();
    self.overlay.hidden=YES;
    BOOL visibleWork=self.selectorView || self.cards.count || self.undoButton || self.presentedViewController;
    if (!self.fullShotBusy && visibleWork && FSCanCaptureVisibleScreen() && [self attachDisplayScene]) self.overlay.hidden=NO;
}
- (BOOL)hasActiveSelection {
    return self.selectorView && !self.selectorView.hidden && self.overlay && !self.overlay.hidden &&
        FSCanCaptureVisibleScreen() && self.selectionLocked==FSDeviceIsLocked() &&
        [self.selectorView selectedRect].size.width>=24 && [self.selectorView selectedRect].size.height>=24;
}
- (BOOL)hasSelector { return self.selectorView!=nil; }
- (void)performFullScreenshot:(dispatch_block_t)original {
    if (self.fullShotBusy) return;
    self.fullShotBusy=YES;
    [self cancelCapture];
    self.overlay.hidden=YES;
    [CATransaction flush];
    // Allow the compositor to remove our controls before the system captures pixels.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50*NSEC_PER_MSEC),dispatch_get_main_queue(), ^{
        @try { original(); }
        @finally {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 600*NSEC_PER_MSEC),dispatch_get_main_queue(), ^{
                self.fullShotBusy=NO; [self refreshLockState];
            });
        }
    });
}
- (NSUInteger)prepareForSystemScreenshot {
    if (!self.overlay || self.lockToken < 0) { FSLog(@"Capture skipped: overlay not ready"); return 0; }
    if (self.fullShotBusy || self.capturing || self.presentedViewController) { FSLog(@"Capture skipped: UI busy or nested screenshot call"); return 0; }
    if (!FSCanCaptureVisibleScreen()) return 0;
    if (self.selectorView) {
        FSLog(@"Replacing previous selector on new screenshot");
        [self cancelCapture];
    }
    if (![self attachDisplayScene]) return 0;
    if (self.cards.count >= 5) { FSLog(@"Capture skipped: five-card limit"); return 0; }
    self.selectionLocked=FSDeviceIsLocked();
    self.capturing = YES;
    NSUInteger ticket = ++self.generation;
    self.captureCanvas = self.view.bounds.size;
    FSLog(@"Live selection requested; no image captured yet");
    return ticket;
}
- (BOOL)finishSystemScreenshot:(NSUInteger)ticket {
        if (ticket != self.generation || !self.capturing) { FSLog(@"Pending selector cancelled before presentation"); return NO; }
        if (!FSCanCaptureVisibleScreen() || self.selectionLocked!=FSDeviceIsLocked() || !CGSizeEqualToSize(self.captureCanvas, self.view.bounds.size)) {
            FSLog(@"Selector cancelled: lock or canvas changed");
            [self cancelCapture];
            return NO;
        }
        if (![self attachDisplayScene]) { [self cancelCapture]; return NO; }
        if (ticket != self.generation || !CGSizeEqualToSize(self.captureCanvas, self.view.bounds.size)) {
            FSLog(@"Display changed before presentation; retry screenshot");
            [self cancelCapture];
            return NO;
        }
        // Only the mosaic tool needs a reference frame; normal selection is live.
        self.capturing = NO;
        self.selectorView = [[FSSelectionView alloc] initWithFrame:self.view.bounds];
        // A screenshot starts a new selection, never a rectangle from a different screen.
        self.selectorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        __weak typeof(self) weakSelf = self;
        self.selectorView.cancelled = ^{ [weakSelf cancelCapture]; };
        self.selectorView.completion = ^(CGRect rect, CGSize size) { [weakSelf pinSelection:rect canvas:size]; };
        self.selectorView.actionRequested = ^(NSString *action, CGRect rect, CGSize size) { [weakSelf selectionAction:action rect:rect canvas:size]; };
        self.selectorView.sourceImageRequested = ^UIImage * {
            FSOverlayController *controller=weakSelf;
            if (!controller || !FSCanCaptureVisibleScreen() || controller.selectionLocked!=FSDeviceIsLocked()) return nil;
            BOOL wasHidden=controller.overlay.hidden;
            controller.overlay.hidden=YES; [CATransaction flush];
            UIImage *reference=nil;
            @try { reference=FSCaptureScreen(NULL); }
            @finally { controller.overlay.hidden=wasHidden || !FSCanCaptureVisibleScreen(); }
            CGFloat ratio=reference.size.width/MAX(1,reference.size.height);
            CGFloat canvasRatio=controller.view.bounds.size.width/MAX(1,controller.view.bounds.size.height);
            return reference && fabs(ratio-canvasRatio)<0.03?reference:nil;
        };
        [self.view addSubview:self.selectorView];
        self.overlay.captureTouchView=self.selectorView;
        self.undoButton.hidden=YES;
        self.overlay.hidden = NO;
        FSLog([NSString stringWithFormat:@"Crop focus: key=%@ canBecomeKey=%@",self.overlay.isKeyWindow ? @"yes" : @"no",self.overlay.canBecomeKeyWindow ? @"yes" : @"no"]);
        FSLog([NSString stringWithFormat:@"Selector submitted: window=%@ bounds=%@ level=%.0f scene=%@", NSStringFromCGRect(self.overlay.frame), NSStringFromCGRect(self.view.bounds), (double)self.overlay.windowLevel, self.overlay.windowScene ? @"yes" : @"no"]);
    return YES;
}
- (void)cancelCapture {
    ++self.generation;
    self.capturing = NO;
    self.analysisBusy = NO;
    self.overlay.captureTouchView=nil;
    [self.selectorView removeFromSuperview];
    self.selectorView = nil;
    self.undoButton.hidden=NO;
    self.overlay.hidden = self.fullShotBusy || !FSCanCaptureVisibleScreen() || !self.overlay.windowScene || (!self.cards.count && !self.undoButton);
}
- (UIImage *)captureCurrentSelection:(CGRect)selection canvas:(CGSize)canvas {
    if (!FSCanCaptureVisibleScreen() || self.selectionLocked!=FSDeviceIsLocked() || !self.selectorView || self.presentedViewController) return nil;
    if (!CGSizeEqualToSize(canvas,self.view.bounds.size)) {
        [self showMessage:FSL(@"تغيّر اتجاه الشاشة؛ أعد التحديد",@"Orientation changed; select again")]; return nil;
    }
    // Capture only on an explicit action. The live selector never owns a frozen image.
    BOOL wasHidden=self.overlay.hidden;
    self.overlay.hidden=YES;
    [CATransaction flush];
    NSError *error=nil;
    UIImage *image=nil;
    @try { image=FSCaptureScreen(&error); }
    @finally { self.overlay.hidden=wasHidden || !FSCanCaptureVisibleScreen() || !self.overlay.windowScene; }
    if (!FSCanCaptureVisibleScreen() || self.selectionLocked!=FSDeviceIsLocked()) return nil;
    if (!image) {
        FSLog(@"Capture at action failed");
        [self showMessage:error.localizedDescription ?: FSL(@"تعذّر التقاط المنطقة الآن",@"Could not capture the area now")];
        return nil;
    }
    CGFloat imageRatio=image.size.width/MAX(1,image.size.height);
    CGFloat canvasRatio=canvas.width/MAX(1,canvas.height);
    if (fabs(imageRatio-canvasRatio)>0.03) {
        [self showMessage:FSL(@"اتجاه الشاشة غير متطابق؛ جرّب الوضع العمودي",@"Screen orientation changed; try portrait")]; return nil;
    }
    UIImage *crop=FSCropImage(image,selection,canvas);
    if (crop) crop=[self.selectorView imageByApplyingMarksToCrop:crop selection:selection];
    FSLog(crop ? @"Current video frame captured at selection action" : @"Current-frame crop failed");
    if (!crop) [self showMessage:FSL(@"تعذّر قص المنطقة المحددة",@"Could not crop selected area")];
    return crop;
}
- (void)pinSelection:(CGRect)selection canvas:(CGSize)canvas {
    if (!FSCanCaptureVisibleScreen()) { [self cancelCapture]; return; }
    UIImage *crop = [self captureCurrentSelection:selection canvas:canvas];
    if (!crop) return;
    BOOL locked=[self.selectorView selectionIsLocked];
    [self cancelCapture];
    FSCardView *card = [[FSCardView alloc] initWithImage:crop];
    card.frame = CGRectOffset(card.frame, self.cards.count * 16, self.cards.count * 20);
    __weak typeof(self) weakSelf = self;
    card.closeRequested = ^(FSCardView *item) {
        [weakSelf closeCardWithUndo:item];
    };
    card.shareRequested = ^(FSCardView *item) { [weakSelf shareCard:item]; };
    card.mergeRequested = ^(FSCardView *item) { (void)item; [weakSelf mergeCards]; };
    card.editRequested = ^(FSCardView *item) { [weakSelf editCard:item]; };
    card.saveRequested = ^(FSCardView *item) { [weakSelf saveToPhotos:item.image]; };
    [self.cards addObject:card];
    [self.view addSubview:card];
    [card fitInside:[self safeArea]];
    self.overlay.hidden=NO;
    if (locked) [card setPositionPinned:YES];
}
- (FSCardView *)addCardFromImage:(UIImage *)crop {
    FSCardView *card = [[FSCardView alloc] initWithImage:crop];
    card.frame = CGRectOffset(card.frame, self.cards.count * 16, self.cards.count * 20);
    __weak typeof(self) weakSelf = self;
    card.closeRequested = ^(FSCardView *item) {
        [weakSelf closeCardWithUndo:item];
    };
    card.shareRequested = ^(FSCardView *item) { [weakSelf shareCard:item]; };
    card.mergeRequested = ^(FSCardView *item) { (void)item; [weakSelf mergeCards]; };
    card.editRequested = ^(FSCardView *item) { [weakSelf editCard:item]; };
    card.saveRequested = ^(FSCardView *item) { [weakSelf saveToPhotos:item.image]; };
    [self.cards addObject:card];
    [self.view addSubview:card];
    [card fitInside:[self safeArea]];
    self.overlay.hidden=NO;
    return card;
}
- (void)saveCompositeImage:(UIImage *)image {
    if (FSDeviceIsLocked() || !image) return;
    [self dismissViewControllerAnimated:YES completion:^{
        [self restoreWindow];
        if (!FSDeviceIsLocked()) [self saveToPhotos:image];
    }];
}
- (void)mergeCards {
    if (FSDeviceIsLocked()) { [self showMessage:FSL(@"افتح القفل لدمج القصاصات",@"Unlock to merge clips")]; return; }
    if (self.presentedViewController) return;
    if (self.cards.count<2) { [self showMessage:FSL(@"ثبّت قصاصتين على الأقل ثم اضغط الدمج",@"Pin two clips before merging")]; return; }
    NSMutableArray *images=[NSMutableArray array]; for (FSCardView *card in self.cards) [images addObject:card.image];
    FSMergeController *merge=[[FSMergeController alloc] initWithImages:images];
    UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:merge];
    navigation.modalPresentationStyle=UIModalPresentationFullScreen;
    __weak typeof(self) weakSelf=self;
    __weak UINavigationController *weakNavigation=navigation;
    merge.finished=^(UIImage *image) {
        FSOverlayController *controller=weakSelf;
        if (!controller || controller.presentedViewController!=weakNavigation) return;
        if (image) [controller saveCompositeImage:image];
        else [controller dismissViewControllerAnimated:YES completion:^{ [controller restoreWindow]; }];
    };
    [self prepareModal]; [self presentViewController:navigation animated:YES completion:nil];
}
- (void)editCard:(FSCardView *)card {
    if (FSDeviceIsLocked()) { [self showMessage:FSL(@"افتح القفل لتعديل القصاصة",@"Unlock to edit the clip")]; return; }
    if (self.presentedViewController || ![self.cards containsObject:card]) return;
    [self prepareModal];
    FSEditorController *editor=[[FSEditorController alloc] initWithImage:card.image];
    if (self.nextEditorTool>=0) [editor selectTool:self.nextEditorTool];
    self.nextEditorTool=-1;
    UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:editor];
    navigation.modalPresentationStyle=UIModalPresentationFullScreen;
    __weak typeof(self) weakSelf=self;
    __weak FSCardView *weakCard=card;
    __weak UINavigationController *weakNavigation=navigation;
    editor.finished=^(UIImage *image) {
        FSOverlayController *controller=weakSelf;
        FSCardView *item=weakCard;
        if (!controller || controller.presentedViewController!=weakNavigation) return;
        if (image && item && !FSDeviceIsLocked() && [controller.cards containsObject:item]) [item replaceImage:image];
        [controller dismissViewControllerAnimated:YES completion:^{ [controller restoreWindow]; }];
    };
    [self presentViewController:navigation animated:YES completion:nil];
}
- (void)discardUndo {
    ++self.undoGeneration;
    self.recentlyClosed=nil; [self.undoButton removeFromSuperview]; self.undoButton=nil;
    if (!self.cards.count && !self.selectorView && !self.presentedViewController) self.overlay.hidden=YES;
}
- (void)closeCardWithUndo:(FSCardView *)card {
    [self discardUndo];
    [self.cards removeObject:card]; [card removeFromSuperview];
    self.recentlyClosed=card; self.undoLocked=FSDeviceIsLocked();
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    button.accessibilityLabel=FSL(@"تراجع عن إغلاق القصاصة",@"Undo closing clip");
    [button setImage:FSIcon(@"arrow.uturn.backward") forState:UIControlStateNormal]; button.tintColor=UIColor.whiteColor;
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.backgroundColor=[UIColor colorWithWhite:0.12 alpha:1]; button.layer.cornerRadius=14;
    [button addTarget:self action:@selector(undoClose) forControlEvents:UIControlEventTouchUpInside];
    self.undoButton=button; [self.view addSubview:button]; [self.view setNeedsLayout];
    NSUInteger ticket=self.undoGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,8*NSEC_PER_SEC),dispatch_get_main_queue(), ^{
        if (ticket==self.undoGeneration) [self discardUndo];
    });
}
- (void)undoClose {
    if (!self.recentlyClosed || !FSCanCaptureVisibleScreen() || self.undoLocked!=FSDeviceIsLocked()) { [self discardUndo]; return; }
    if (self.cards.count>=5) { [self showMessage:FSL(@"أغلق قصاصة أولاً؛ الحد خمس قصاصات",@"Close a clip first; five maximum")]; return; }
    FSCardView *card=self.recentlyClosed;
    [self discardUndo]; [self.cards addObject:card]; [self.view addSubview:card]; [card fitInside:[self safeArea]];
    self.overlay.hidden=NO;
    if (self.selectorView) [self.view bringSubviewToFront:self.selectorView];
}
- (void)clearCards {
    [self discardUndo];
    for (FSCardView *card in self.cards) [card removeFromSuperview];
    [self.cards removeAllObjects];
    if (!self.selectorView && !self.presentedViewController) self.overlay.hidden=YES;
}
- (void)prepareModal {
    self.previousKeyWindow = nil;
    UIWindowScene *scene = self.overlay.windowScene;
    // A SpringBoard-created overlay may not have a scene of its own.
    if (!scene) {
        for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
            if (![candidate isKindOfClass:UIWindowScene.class] ||
                candidate.activationState != UISceneActivationStateForegroundActive) continue;
            UIWindowScene *windowScene = (UIWindowScene *)candidate;
            if (windowScene.screen != self.overlay.screen) continue;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow && window != self.overlay) {
                    scene = windowScene;
                    break;
                }
            }
            if (scene) break;
        }
    }
    for (UIWindow *window in scene.windows) {
        if (window.isKeyWindow && window != self.overlay) self.previousKeyWindow = window;
    }
    self.overlay.modalTouch = YES;
    [self.overlay makeKeyWindow];
}
- (void)restoreWindow {
    self.overlay.modalTouch = NO;
    if (self.overlay.isKeyWindow) [self.overlay resignKeyWindow];
    if (self.previousKeyWindow && !self.previousKeyWindow.hidden) [self.previousKeyWindow makeKeyWindow];
    else [self.overlay resignKeyWindow];
    self.previousKeyWindow = nil;
}
- (void)shareCard:(FSCardView *)card {
    if (FSDeviceIsLocked()) { [self showMessage:FSL(@"افتح القفل للمشاركة",@"Unlock to share")]; return; }
    if (self.presentedViewController) return;
    [self prepareModal];
    UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[card.image] applicationActivities:nil];
    // SpringBoard has no tweak-owned Photos usage description. Export via Files/share extensions.
    sheet.excludedActivityTypes = @[UIActivityTypeSaveToCameraRoll, UIActivityTypeAssignToContact];
    sheet.popoverPresentationController.sourceView = card.superview ? card : self.view;
    sheet.popoverPresentationController.sourceRect = card.superview ? card.bounds : CGRectMake(CGRectGetMidX(self.view.bounds),CGRectGetMidY(self.view.bounds),1,1);
    __weak typeof(self) weakSelf = self;
    sheet.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *error) {
        (void)type; (void)completed; (void)items;
        [weakSelf restoreWindow];
        if (error) [weakSelf showMessage:FSL(@"تعذّرت المشاركة؛ حاول مرة أخرى",@"Could not share; try again")];
    };
    [self presentViewController:sheet animated:YES completion:nil];
    sheet.presentationController.delegate = self;
}
- (void)selectionAction:(NSString *)action rect:(CGRect)rect canvas:(CGSize)canvas {
    if (FSDeviceIsLocked()) { [self showMessage:FSL(@"افتح القفل للحفظ والمشاركة؛ يمكنك تثبيت القص بضغطتين داخله",@"Unlock to save or share; double tap inside to pin")]; return; }
    if (self.presentedViewController || !self.selectorView) return;
    UIImage *crop=[self captureCurrentSelection:rect canvas:canvas];
    if (!crop) return;
    NSInteger tool=-1;
    if ([action isEqualToString:@"rectangle"]) tool=2;
    else if ([action isEqualToString:@"line"]) tool=7;
    else if ([action isEqualToString:@"arrow"]) tool=1;
    else if ([action isEqualToString:@"pen"]) tool=0;
    else if ([action isEqualToString:@"blur"]) tool=8;
    if (tool>=0) {
        [self cancelCapture];
        FSCardView *card=[self addCardFromImage:crop];
        self.nextEditorTool=tool;
        [self editCard:card];
        return;
    }
    if ([action isEqualToString:@"copy"]) {
        UIPasteboard.generalPasteboard.image=crop;
        [self showMessage:FSL(@"تم نسخ الصورة المحددة",@"Selection copied")];
    } else if ([action isEqualToString:@"share"]) {
        [self shareCard:[[FSCardView alloc] initWithImage:crop]];
    } else if ([action isEqualToString:@"photos"]) {
        [self saveToPhotos:crop];
    } else if ([action isEqualToString:@"save"]) {
        [self exportImage:crop];
    } else if ([action isEqualToString:@"text"] || [action isEqualToString:@"qr"] || [action isEqualToString:@"translate"] || [action isEqualToString:@"textcopy"]) {
        [self recognizeImage:crop barcode:[action isEqualToString:@"qr"] translate:[action isEqualToString:@"translate"] copyDirectly:[action isEqualToString:@"textcopy"]];
    }
}
- (void)saveToPhotos:(UIImage *)image {
    FSLog(@"Photos action received");
    if (FSDeviceIsLocked()) { [self showMessage:FSL(@"افتح القفل للحفظ في الصور",@"Unlock to save to Photos")]; return; }
    if (!image) return;
    if (self.photoSaveBusy) { [self showMessage:FSL(@"جاري الحفظ في الصور…",@"Saving to Photos…")]; return; }
    PHAuthorizationStatus status=[PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
    PHAuthorizationStatus existingReadWrite=[PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
    // Existing read/write (including limited) access also permits adding assets.
    // Inspect it without requesting new read access or changing any system permissions.
    if (status!=PHAuthorizationStatusAuthorized &&
        (existingReadWrite==PHAuthorizationStatusAuthorized || existingReadWrite==PHAuthorizationStatusLimited)) {
        status=PHAuthorizationStatusAuthorized;
    }
    FSLog([NSString stringWithFormat:@"Photos access: add=%ld existingReadWrite=%ld effective=%ld",(long)[PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly],(long)existingReadWrite,(long)status]);
    if (status==PHAuthorizationStatusDenied || status==PHAuthorizationStatusRestricted) {
        [self showMessage:FSL(@"صلاحية إضافة الصور غير متاحة لواجهة النظام",@"Photo add permission unavailable")];
        return;
    }
    if (status==PHAuthorizationStatusNotDetermined) {
        // A tweak cannot supply the host's Info.plist privacy key. Never prompt without it.
        id usage=[NSBundle.mainBundle objectForInfoDictionaryKey:@"NSPhotoLibraryAddUsageDescription"];
        if (![usage isKindOfClass:NSString.class] || ![(NSString *)usage length]) {
            FSLog(@"Photos save unavailable: host has no add-only usage description");
            [self showMessage:FSL(@"صلاحية الصور غير مهيأة هنا؛ استخدم الحفظ بالملفات حالياً",@"Photos permission unavailable here; use Files")];
            return;
        }
        self.photoSaveBusy=YES;
        NSUInteger ticket=self.generation;
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.photoSaveBusy=NO;
                if (ticket!=self.generation || FSDeviceIsLocked()) return;
                if (result==PHAuthorizationStatusAuthorized || result==PHAuthorizationStatusLimited) [self saveToPhotos:image];
                else [self showMessage:FSL(@"لم تُمنح صلاحية الحفظ في الصور",@"Photos permission not granted")];
            });
        }];
        return;
    }
    if (status!=PHAuthorizationStatusAuthorized && status!=PHAuthorizationStatusLimited) return;
    self.photoSaveBusy=YES;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
    } completionHandler:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.photoSaveBusy=NO;
            FSLog(success ? @"Photos save completed" : [NSString stringWithFormat:@"Photos save failed: domain=%@ code=%ld",error.domain,(long)error.code]);
            if (!FSDeviceIsLocked()) [self showMessage:success ? FSL(@"تم الحفظ في الصور",@"Saved to Photos") : FSL(@"تعذّر الحفظ في الصور؛ جرّب الحفظ بالملفات",@"Could not save to Photos; try Files")];
        });
    }];
}
- (void)cleanupExport {
    if (self.exportURL) [[NSFileManager defaultManager] removeItemAtURL:self.exportURL error:NULL];
    self.exportURL=nil;
}
- (void)exportImage:(UIImage *)image {
    [self cleanupExport];
    NSString *name=[NSString stringWithFormat:@"FloatSnap-%@.png",NSUUID.UUID.UUIDString];
    NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
    NSError *error=nil;
    NSData *data=UIImagePNGRepresentation(image);
    if (!data || ![data writeToURL:url options:NSDataWritingAtomic error:&error]) {
        [self showMessage:FSL(@"تعذّر تجهيز الصورة للحفظ",@"Could not prepare image for saving")]; return;
    }
    self.exportURL=url;
    UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForExportingURLs:@[url] asCopy:YES];
    picker.delegate=self;
    [self prepareModal];
    [self presentViewController:picker animated:YES completion:nil];
    picker.presentationController.delegate=self;
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    (void)controller;
    [self cleanupExport]; [self restoreWindow];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller;
    [self cleanupExport]; [self restoreWindow];
    if (urls.count) [self showMessage:FSL(@"تم تصدير الصورة",@"Image exported")];
}
- (void)presentationControllerDidDismiss:(UIPresentationController *)controller {
    (void)controller;
    [self cleanupExport]; [self restoreWindow];
}

static NSArray<NSString *> *FSDetectQR(UIImage *image) {
    if (!image.CGImage) return @[];
    NSMutableOrderedSet<NSString *> *payloads = [NSMutableOrderedSet orderedSet];
    CGFloat width = CGImageGetWidth(image.CGImage);
    CGFloat height = CGImageGetHeight(image.CGImage);
    CGFloat longest = MAX(width, height);
    if (longest < 1) return @[];

    for (NSUInteger pass = 0; pass < 3 && payloads.count == 0; pass++) {
        UIImage *candidate = image;
        if (pass > 0) {
            CGFloat scale = MIN(3.0, 1600.0 / longest);
            CGSize size = CGSizeMake(MAX(1, round(width * scale)), MAX(1, round(height * scale)));
            CGFloat margin = MAX(24, round(MIN(size.width, size.height) * 0.16));
            UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
            format.scale = 1;
            format.opaque = YES;
            UIImage *source = image;
            if (pass == 2) {
                CIImage *input = [CIImage imageWithCGImage:image.CGImage];
                CIImage *negative = [input imageByApplyingFilter:@"CIColorInvert"];
                CIContext *context = [CIContext contextWithOptions:nil];
                CGImageRef inverted = [context createCGImage:negative fromRect:input.extent];
                if (!inverted) continue;
                source = [UIImage imageWithCGImage:inverted];
                CGImageRelease(inverted);
            }
            CGSize padded = CGSizeMake(size.width + margin * 2, size.height + margin * 2);
            UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:padded format:format];
            candidate = [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
                [UIColor.whiteColor setFill];
                UIRectFill((CGRect){CGPointZero, padded});
                CGContextSetInterpolationQuality(rendererContext.CGContext, kCGInterpolationNone);
                [source drawInRect:(CGRect){CGPointMake(margin, margin), size}];
            }];
        }
        VNDetectBarcodesRequest *request = [VNDetectBarcodesRequest new];
        request.symbologies = @[VNBarcodeSymbologyQR];
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:candidate.CGImage options:@{}];
        if ([handler performRequests:@[request] error:NULL]) {
            for (VNBarcodeObservation *result in request.results) {
                if (result.payloadStringValue.length) [payloads addObject:result.payloadStringValue];
            }
        }
        if (payloads.count == 0 && pass > 0) {
            CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil
                options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
            for (CIQRCodeFeature *feature in [detector featuresInImage:[CIImage imageWithCGImage:candidate.CGImage]]) {
                if (feature.messageString.length) [payloads addObject:feature.messageString];
            }
        }
    }
    return payloads.array;
}

- (void)recognizeImage:(UIImage *)image barcode:(BOOL)barcode translate:(BOOL)translate copyDirectly:(BOOL)copyDirectly {
    if (self.analysisBusy) { [self showMessage:FSL(@"جاري قراءة التحديد…",@"Reading selection…")]; return; }
    self.analysisBusy=YES;
    NSUInteger ticket=self.generation;
    [self showMessage:barcode ? FSL(@"جاري قراءة QR…",@"Reading QR…") : FSL(@"جاري استخراج النص…",@"Extracting text…")];
    static dispatch_queue_t ocrQueue;static dispatch_once_t once;dispatch_once(&once,^{ocrQueue=dispatch_queue_create("local.floatsnap.ocr",DISPATCH_QUEUE_SERIAL);});
    dispatch_async(ocrQueue, ^{
        __block BOOL current=NO;dispatch_sync(dispatch_get_main_queue(),^{current=ticket==self.generation && self.selectorView && !FSDeviceIsLocked();});if(!current)return;
        @autoreleasepool {
            NSError *error=nil;
            NSMutableArray<NSString *> *values=[NSMutableArray array];
            if (barcode) {
                [values addObjectsFromArray:FSDetectQR(image)];
            } else if (FSPrefBool(@"ArabicOCR",YES)) {
                // iOS 16 Vision does not list Arabic. Use the bundled offline ara+eng engine.
                NSString *recognized=FSReadArabicImage(image,&error);
                recognized = FSNormalizeOCRText(recognized);
                if (recognized.length) [values addObject:recognized];
            } else {
                VNRecognizeTextRequest *request=[[VNRecognizeTextRequest alloc] init];
                request.recognitionLevel=VNRequestTextRecognitionLevelAccurate;
                request.automaticallyDetectsLanguage=YES;
                request.usesLanguageCorrection=YES;
                VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image.CGImage options:@{}];
                if ([handler performRequests:@[request] error:&error]) {
                    for (VNRecognizedTextObservation *result in request.results) {
                        NSString *text=[result topCandidates:1].firstObject.string;
                        if (text.length) [values addObject:text];
                    }
                }
            }
            NSString *text=[values componentsJoinedByString:@"\n"];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (ticket!=self.generation) return;
                self.analysisBusy=NO;
                if (FSDeviceIsLocked() || !self.selectorView || self.presentedViewController) return;
                if (error || !text.length) {
                    [self showMessage:barcode ? FSL(@"لم يُعثر على QR قابل للقراءة",@"No readable QR found") : FSL(@"تعذّر استخراج نص واضح؛ جرّب تحديداً أصغر أو أوضح",@"No clear text could be extracted; try a smaller or clearer selection")];
                    return;
                }
                if (copyDirectly) {
                    UIPasteboard.generalPasteboard.string=text;
                    [self showMessage:FSL(@"تم نسخ النص من التحديد",@"Text copied from selection")];
                } else if (translate) [self presentDirectTranslation:text image:image];
                else [self presentRecognizedText:text barcode:barcode image:image];
            });
        }
    });
}
- (void)presentDirectTranslation:(NSString *)text image:(UIImage *)image {
    if (FSDeviceIsLocked() || self.presentedViewController) return;
    FSTranslationController *translation=[[FSTranslationController alloc] initWithText:text];
    translation.startsAutomatically=YES; translation.sourceImage=image;
    __weak typeof(self) weakSelf=self;
    translation.imageSaveRequested=^(UIImage *result) { [weakSelf saveCompositeImage:result]; };
    translation.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:FSL(@"إغلاق",@"Close") style:UIBarButtonItemStyleDone target:self action:@selector(closeDirectTranslation)];
    UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:translation];
    navigation.modalPresentationStyle=UIModalPresentationFullScreen;
    [self prepareModal]; [self presentViewController:navigation animated:YES completion:nil];
}
- (void)closeDirectTranslation {
    [self dismissViewControllerAnimated:YES completion:^{ [self restoreWindow]; }];
}
- (void)presentRecognizedText:(NSString *)text barcode:(BOOL)barcode image:(UIImage *)image {
    if (!barcode) {
        if (FSDeviceIsLocked() || self.presentedViewController) return;
        FSWordSelectionController *words=[[FSWordSelectionController alloc] initWithText:text];
        UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:words];
        navigation.modalPresentationStyle=UIModalPresentationFullScreen;
        __weak typeof(self) weakSelf=self;
        __weak UINavigationController *weakNavigation=navigation;
        words.sourceImage=image;
        words.imageSaveRequested=^(UIImage *result) { [weakSelf saveCompositeImage:result]; };
        words.textCopyRequested=^(NSString *selected) {
            FSOverlayController *controller=weakSelf;
            if (!controller || FSDeviceIsLocked() || controller.presentedViewController!=weakNavigation) return;
            UIPasteboard.generalPasteboard.string=selected;
            [controller dismissViewControllerAnimated:YES completion:^{ [controller restoreWindow]; [controller showMessage:FSL(@"تم نسخ الكلمات المحددة",@"Selected words copied")]; }];
        };
        words.closeRequested=^{
            FSOverlayController *controller=weakSelf;
            if (controller.presentedViewController==weakNavigation) [controller dismissViewControllerAnimated:YES completion:^{ [controller restoreWindow]; }];
        };
        [self prepareModal]; [self presentViewController:navigation animated:YES completion:nil];
        return;
    }
    NSString *preview=text.length>1200 ? [[text substringToIndex:1200] stringByAppendingString:@"…"] : text;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:barcode ? FSL(@"محتوى QR",@"QR content") : FSL(@"النص المستخرج",@"Extracted text") message:preview preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:FSL(@"نسخ الكل",@"Copy all") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        if (!FSDeviceIsLocked()) UIPasteboard.generalPasteboard.string=text;
        [weakSelf restoreWindow];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:FSL(@"إغلاق",@"Close") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        (void)action; [weakSelf restoreWindow];
    }]];
    [self prepareModal];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)showMessage:(NSString *)message {
    if (!FSCanCaptureVisibleScreen()) return;
    [self.toast removeFromSuperview];
    UILabel *label = [[UILabel alloc] init];
    label.text = message;
    label.textColor = UIColor.whiteColor;
    label.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.95];
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    label.numberOfLines = 2;
    label.textAlignment = NSTextAlignmentCenter;
    label.layer.cornerRadius = 14;
    label.clipsToBounds = YES;
    self.toast = label;
    [self.view addSubview:label];
    [self.view setNeedsLayout];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [label removeFromSuperview];
        if (self.toast == label) self.toast = nil;
    });
}
- (void)memoryWarning:(NSNotification *)notification {
    (void)notification;
    // System-wide warnings can arrive while FloatSnap is idle. Nothing to close
    // means no user-facing warning and no change to the active app's focus.
    BOOL hadVisibleWork=self.cards.count>0 || self.selectorView!=nil || self.capturing || self.presentedViewController!=nil;
    [self discardUndo];
    if (!hadVisibleWork) return;
    [self cancelCapture];
    [self clearCards];
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:NO completion:^{ [self cleanupExport]; [self restoreWindow]; }];
    } else { [self cleanupExport]; }
    FSLog(@"Memory warning: released active FloatSnap content");
    // Release resources silently: the user requested no memory warning banners.
}

@end
