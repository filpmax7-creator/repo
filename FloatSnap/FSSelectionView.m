#import "FSIcons.h"
#import "FSSelectionView.h"
#import "FSPreferences.h"
#import "FSLocale.h"
#import "FSDiagnostics.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface FSPreMark : NSObject
@property(nonatomic) BOOL blur;
@property(nonatomic,strong) NSMutableArray<NSValue *> *points; // Screen points.
@end
@implementation FSPreMark
@end

@interface FSPreEditView : UIView
@property(nonatomic,strong) NSArray<FSPreMark *> *marks;
@property(nonatomic,strong) FSPreMark *pending;
@property(nonatomic,strong) UIImage *pixelatedScreen;
@property(nonatomic) CGRect selection;
@end
@implementation FSPreEditView
- (void)drawRect:(CGRect)rect {
    (void)rect;
    CGRect selection=self.selection;
    if (CGRectIsEmpty(selection)) return;
    CGContextRef context=UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextClipToRect(context,selection);
    NSMutableArray<FSPreMark *> *all=[self.marks mutableCopy] ?: [NSMutableArray array];
    if (self.pending) [all addObject:self.pending];
    for (FSPreMark *mark in all) {
        if (!mark.points.count) continue;
        if (mark.blur && mark.points.count>=2) {
            CGPoint a=mark.points.firstObject.CGPointValue,b=mark.points.lastObject.CGPointValue;
            CGRect area=CGRectMake(MIN(a.x,b.x),MIN(a.y,b.y),fabs(a.x-b.x),fabs(a.y-b.y));
            if (area.size.width<3 || area.size.height<3) continue;
            CGContextSaveGState(context); CGContextClipToRect(context,area);
            if (self.pixelatedScreen) {
                CGContextSetInterpolationQuality(context,kCGInterpolationNone);
                [self.pixelatedScreen drawInRect:self.bounds];
            } else {
                [[UIColor colorWithWhite:0.5 alpha:0.85] setFill]; UIRectFill(area);
            }
            CGContextRestoreGState(context);
            [[UIColor.whiteColor colorWithAlphaComponent:0.9] setStroke];
            UIBezierPath *edge=[UIBezierPath bezierPathWithRect:area]; edge.lineWidth=1; [edge stroke];
        } else if (!mark.blur) {
            [[UIColor systemYellowColor] setStroke]; [[UIColor systemYellowColor] setFill];
            UIBezierPath *path=[UIBezierPath bezierPath]; path.lineWidth=3; path.lineCapStyle=kCGLineCapRound; path.lineJoinStyle=kCGLineJoinRound;
            [path moveToPoint:mark.points.firstObject.CGPointValue];
            for (NSValue *point in mark.points) [path addLineToPoint:point.CGPointValue];
            if (mark.points.count==1) { CGPoint dot=mark.points.firstObject.CGPointValue; [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(dot.x-2,dot.y-2,4,4)] fill]; }
            else [path stroke];
        }
    }
    CGContextRestoreGState(context);
}
@end

typedef NS_OPTIONS(NSUInteger, FSEdges) { FSLeft=1, FSRight=2, FSTop=4, FSBottom=8 };
@interface FSSelectionView () <UIGestureRecognizerDelegate>
@property(nonatomic, strong) CAShapeLayer *shade;
@property(nonatomic,strong) CAShapeLayer *handles;
@property(nonatomic,strong) UILabel *dimensions;
@property(nonatomic,strong) UIView *menuPanel;
@property(nonatomic) CGFloat menuScrollOffset;
@property(nonatomic) BOOL menuScrolling;
@property(nonatomic,strong) UIView *orderPanel;
@property(nonatomic,strong) UIButton *centerLock;
@property(nonatomic,strong) UIButton *undoDrawing;
@property(nonatomic,strong) NSArray<NSString *> *toolbarOrder;
@property(nonatomic) NSInteger orderDragIndex;
@property(nonatomic,strong) UILabel *orderDragPreview;
@property(nonatomic,strong) UIButton *cancelButton;
@property(nonatomic,strong) FSPreEditView *editView;
@property(nonatomic,strong) NSMutableArray<FSPreMark *> *marks;
@property(nonatomic,strong) FSPreMark *pendingMark;
@property(nonatomic) NSInteger editTool; // 0: move/resize, 1: pen, 2: mosaic.
@property(nonatomic) BOOL selectionLocked;
@property(nonatomic,strong) NSArray<NSString *> *menuActions;
@property(nonatomic,copy) NSString *pendingAction;
@property(nonatomic) BOOL toolTouch;
@property(nonatomic) CGPoint toolStart;
@property(nonatomic, strong) CAShapeLayer *outline;
@property(nonatomic, strong) UIView *toolbar;
@property(nonatomic, strong) UITouch *activeTouch;
@property(nonatomic) BOOL touchMoved;
@property(nonatomic) BOOL touchStartedInside;
@property(nonatomic, strong) NSArray<UIButton *> *actions;
@property(nonatomic, strong) UILabel *hint;
@property(nonatomic) CGRect selection;
@property(nonatomic) CGRect initialRect;
@property(nonatomic) CGPoint origin;
@property(nonatomic) NSInteger mode;
@property(nonatomic) FSEdges edges;
@property(nonatomic) BOOL dragging;
@end

@implementation FSSelectionView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // A minimally painted surface keeps the live crop from becoming a
        // transparent hole in cross-process SpringBoard event routing.
        // Keep view alpha at 1; only the background paint is translucent.
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.02];
        self.alpha=1;
        self.userInteractionEnabled=YES;
        _shade = [CAShapeLayer layer];
        _shade.fillColor = [UIColor colorWithWhite:0 alpha:FSPrefNumber(@"Dimming",0.45,0,0.75)].CGColor;
        _shade.fillRule = kCAFillRuleNonZero;
        [self.layer addSublayer:_shade];
        _outline = [CAShapeLayer layer];
        _outline.fillColor = UIColor.clearColor.CGColor;
        _outline.strokeColor = UIColor.whiteColor.CGColor;
        _outline.lineWidth = 2;
        _outline.lineJoin = kCALineJoinRound;
        [self.layer addSublayer:_outline];
        _handles=[CAShapeLayer layer]; _handles.fillColor=UIColor.whiteColor.CGColor;
        _handles.strokeColor=[UIColor colorWithWhite:0.18 alpha:0.9].CGColor; _handles.lineWidth=1;
        [self.layer addSublayer:_handles];
        _editView=[[FSPreEditView alloc] initWithFrame:self.bounds];
        _editView.backgroundColor=UIColor.clearColor; _editView.opaque=NO;
        _editView.userInteractionEnabled=NO; _marks=[NSMutableArray array];
        [self addSubview:_editView];
        _dimensions=[UILabel new]; _dimensions.textColor=UIColor.whiteColor;
        _dimensions.font=[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
        _dimensions.backgroundColor=[UIColor colorWithWhite:0.16 alpha:0.96];
        _dimensions.layer.cornerRadius=6; _dimensions.clipsToBounds=YES;
        _dimensions.textAlignment=NSTextAlignmentCenter; [self addSubview:_dimensions];
        _hint = [[UILabel alloc] init];
        _hint.text = FSL(@"اسحب للتحديد والتحريك • اضغط مرتين للتثبيت",@"Drag to select or move • double tap to pin");
        _hint.numberOfLines = 2;
        _hint.textColor = UIColor.whiteColor;
        _hint.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
        _hint.layer.cornerRadius = 10;
        _hint.clipsToBounds = YES;
        _hint.textAlignment = NSTextAlignmentCenter;
        _hint.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [self addSubview:_hint];
        _toolbar = [self bar];
        // Same single-row order as the supplied reference: edit tools, then actions.
        NSArray *symbols=@[@"rectangle",@"line.diagonal",@"arrow.up.right",@"pencil",@"square.dashed",@"lock.open",@"pin",@"text.viewfinder",@"doc.on.doc",@"arrow.down.to.line",@"ellipsis"];
        NSArray *labels=@[FSL(@"مستطيل",@"Rectangle"),FSL(@"خط",@"Line"),FSL(@"سهم",@"Arrow"),FSL(@"قلم",@"Pen"),FSL(@"غويش",@"Mosaic"),FSL(@"قفل التحديد",@"Lock selection"),FSL(@"تثبيت",@"Pin"),FSL(@"نسخ النص",@"Copy text"),FSL(@"نسخ الصورة",@"Copy image"),FSL(@"حفظ في الملفات",@"Save to Files"),FSL(@"المزيد",@"More")];
        NSArray *names=@[@"rectangle",@"line",@"arrow",@"pen",@"blur",@"lock",@"pin",@"textcopy",@"copy",@"save",@"more"];
        NSMutableArray *buttons=[NSMutableArray array];
        for (NSUInteger i=0;i<symbols.count;i++) {
            UIButton *button=[self button:symbols[i] label:labels[i] target:@selector(action:) parent:_toolbar];
            button.accessibilityIdentifier=names[i]; [buttons addObject:button];
            button.userInteractionEnabled=NO; // Selection view handles toolbar taps, like drag touches.

        }
        _actions=buttons;
        NSArray *saved=[[NSUserDefaults standardUserDefaults] arrayForKey:@"FSToolbarOrder"];
        NSMutableArray *order=[NSMutableArray array];
        for (id name in saved) if ([name isKindOfClass:NSString.class] && [names containsObject:name] && ![order containsObject:name]) [order addObject:name];
        for (NSString *name in names) if (![order containsObject:name]) [order addObject:name];
        if ([saved isKindOfClass:NSArray.class] && ![saved containsObject:@"textcopy"]) {
            [order removeObject:@"textcopy"];
            NSUInteger insertion=[order indexOfObject:@"copy"];
            [order insertObject:@"textcopy" atIndex:insertion==NSNotFound?order.count:insertion];
        }
        _toolbarOrder=order;
        _orderDragIndex=-1;
        _centerLock=[self button:@"lock.fill" label:FSL(@"فتح التحديد",@"Unlock selection") target:@selector(action:) parent:self];
        _centerLock.accessibilityIdentifier=@"lock"; _centerLock.userInteractionEnabled=NO;
        _centerLock.backgroundColor=[UIColor colorWithWhite:0.12 alpha:0.92]; _centerLock.layer.cornerRadius=23; _centerLock.hidden=YES;
        _undoDrawing=[self button:@"arrow.uturn.backward" label:FSL(@"تراجع عن آخر رسم",@"Undo last mark") target:@selector(action:) parent:self];
        _undoDrawing.accessibilityIdentifier=@"undo"; _undoDrawing.userInteractionEnabled=NO;
        _undoDrawing.backgroundColor=[UIColor colorWithWhite:0.12 alpha:0.96]; _undoDrawing.layer.cornerRadius=22; _undoDrawing.hidden=YES;
        _menuActions=@[@"share",@"photos",@"qr",@"text",@"translate",@"undo",@"full",@"arrange"];
        NSArray *moreLabels=@[FSL(@"مشاركة",@"Share"),FSL(@"حفظ في الصور",@"Save to Photos"),FSL(@"قراءة QR",@"Read QR"),FSL(@"استخراج النص",@"Extract text"),FSL(@"ترجمة النص عبر الإنترنت",@"Translate online"),FSL(@"تراجع عن آخر رسم",@"Undo last mark"),FSL(@"تحديد الشاشة كاملة",@"Select full screen"),FSL(@"ترتيب أزرار الشريط",@"Arrange toolbar buttons")];
        NSArray *moreIcons=@[@"square.and.arrow.up",@"photo",@"qrcode.viewfinder",@"text.viewfinder",@"globe",@"arrow.uturn.backward",@"camera",@"line.3.horizontal.decrease"];
        _menuPanel=[UIView new]; _menuPanel.backgroundColor=UIColor.whiteColor;
        _menuPanel.layer.cornerRadius=16; _menuPanel.clipsToBounds=YES; _menuPanel.hidden=YES;
        [self addSubview:_menuPanel];
        for (NSUInteger i=0;i<_menuActions.count;i++) {
            UIView *row=[[UIView alloc] initWithFrame:CGRectMake(0,i*52,0,52)]; row.tag=1000+i;
            UILabel *label=[UILabel new]; label.tag=2000; label.text=moreLabels[i];
            label.textColor=[UIColor colorWithWhite:0.16 alpha:1]; label.textAlignment=NSTextAlignmentRight;
            label.font=[UIFont systemFontOfSize:16 weight:UIFontWeightRegular]; [row addSubview:label];
            UIImageView *icon=[[UIImageView alloc] initWithImage:FSIcon(moreIcons[i])]; icon.tag=2001;
            icon.contentMode=UIViewContentModeScaleAspectFit; icon.tintColor=[UIColor colorWithWhite:0.25 alpha:1];
            [row addSubview:icon];
            if (i) { UIView *line=[UIView new]; line.tag=2002; line.backgroundColor=[UIColor colorWithWhite:0.86 alpha:1]; [row addSubview:line]; }
            [_menuPanel addSubview:row];
        }
        _orderPanel=[UIView new]; _orderPanel.backgroundColor=UIColor.whiteColor;
        _orderPanel.layer.cornerRadius=16; _orderPanel.clipsToBounds=YES; _orderPanel.hidden=YES;
        [self addSubview:_orderPanel];
        _cancelButton=[self button:@"xmark" label:FSL(@"إلغاء",@"Cancel") target:@selector(action:) parent:self];
        _cancelButton.accessibilityIdentifier=@"cancel";
        _cancelButton.userInteractionEnabled=NO;
        _cancelButton.tintColor=UIColor.whiteColor;
        _cancelButton.backgroundColor=[UIColor colorWithWhite:0.12 alpha:0.96];
        _cancelButton.layer.cornerRadius=22;
        self.multipleTouchEnabled=NO;
    }
    return self;
}
- (UIView *)bar {
    UIView *bar = [[UIView alloc] init];
    bar.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    bar.layer.cornerRadius = 16;
    bar.layer.borderWidth=1; bar.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.22].CGColor;
    bar.clipsToBounds = YES;
    [self addSubview:bar];
    return bar;
}
- (UIButton *)button:(NSString *)symbol label:(NSString *)label target:(SEL)action parent:(UIView *)parent {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:FSIcon(symbol) forState:UIControlStateNormal];
    button.tintColor = UIColor.whiteColor;
    button.accessibilityLabel = label;
    if ([label isEqualToString:@"حفظ في الصور"] || [symbol isEqualToString:@"globe"]) {
        UIButtonConfiguration *configuration=[UIButtonConfiguration plainButtonConfiguration];
        configuration.image=FSIcon(symbol);
        configuration.imagePlacement=NSDirectionalRectEdgeTop;
        configuration.imagePadding=1;
        configuration.preferredSymbolConfigurationForImage=[UIImageSymbolConfiguration configurationWithPointSize:18];

        configuration.baseForegroundColor=UIColor.whiteColor;
        configuration.contentInsets=NSDirectionalEdgeInsetsMake(2,0,2,0);
        button.configuration=configuration;
    }

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [parent addSubview:button];
    return button;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.hint.frame = CGRectMake(20, MAX(20,self.safeAreaInsets.top)+8, self.bounds.size.width-40, 44);
    self.cancelButton.frame=CGRectMake(CGRectGetMidX(self.bounds)-22,self.bounds.size.height-MAX(14,self.safeAreaInsets.bottom)-48,44,44);
    self.editView.frame=self.bounds;
    [self updateSelection];
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || !self.userInteractionEnabled || ![self pointInside:point withEvent:event]) return nil;
    // Route tools through the same selection touch path that already works in
    // SpringBoard's non-key overlay window.
    return self;
}
- (NSString *)toolAtPoint:(CGPoint)point {
    if (!self.orderPanel.hidden && CGRectContainsPoint(self.orderPanel.frame,point)) {
        NSUInteger row=(NSUInteger)((point.y-CGRectGetMinY(self.orderPanel.frame))/38);
        if (row>=self.toolbarOrder.count) return @"orderDone";
        return [NSString stringWithFormat:@"order:%lu",(unsigned long)row];
    }
    if (!self.menuPanel.hidden && CGRectContainsPoint(self.menuPanel.frame,point)) {
        CGFloat rowHeight=52;
        NSUInteger index=(NSUInteger)((point.y-CGRectGetMinY(self.menuPanel.frame)+self.menuScrollOffset)/rowHeight);
        return index<self.menuActions.count?self.menuActions[index]:nil;
    }
    if (CGRectContainsPoint(self.cancelButton.frame,point)) return @"cancel";
    if (!self.centerLock.hidden && CGRectContainsPoint(self.centerLock.frame,point)) return @"lock";
    if (!self.undoDrawing.hidden && CGRectContainsPoint(self.undoDrawing.frame,point)) return @"undo";
    if (!self.toolbar.hidden && CGRectContainsPoint(self.toolbar.frame,point)) {
        NSUInteger index=(NSUInteger)((point.x-CGRectGetMinX(self.toolbar.frame))*self.actions.count/MAX(1,self.toolbar.frame.size.width));
        return index<self.toolbarOrder.count?self.toolbarOrder[index]:nil;
    }
    return nil;
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event; if (self.activeTouch) return;
    self.activeTouch=touches.anyObject; self.touchMoved=NO;
    CGPoint point=[self.activeTouch locationInView:self];
    self.pendingAction=[self toolAtPoint:point];
    self.toolTouch=self.pendingAction!=nil;
    self.toolStart=point;
    if (!self.orderPanel.hidden && [self.pendingAction hasPrefix:@"order:"]) {
        self.orderDragIndex=[[self.pendingAction substringFromIndex:6] integerValue];
        return;
    }
    if (!self.orderPanel.hidden && CGRectContainsPoint(self.toolbar.frame,point) && self.pendingAction) {
        self.orderDragIndex=[self.toolbarOrder indexOfObject:self.pendingAction];
        if (self.orderDragIndex==NSNotFound) self.orderDragIndex=-1;
    }
    if (self.toolTouch) return;
    if (!self.menuPanel.hidden || !self.orderPanel.hidden) { self.menuPanel.hidden=YES; self.orderPanel.hidden=YES; self.activeTouch=nil; return; }
    if (self.editTool && CGRectContainsPoint(self.selection,point)) {
        self.pendingMark=[FSPreMark new]; self.pendingMark.blur=self.editTool==2;
        self.pendingMark.points=[NSMutableArray arrayWithObject:[NSValue valueWithCGPoint:point]];
        self.editView.pending=self.pendingMark; [self.editView setNeedsDisplay]; return;
    }
    if (self.selectionLocked) { self.activeTouch=nil; return; }
    self.touchStartedInside=self.selection.size.width>=24 && self.selection.size.height>=24 && CGRectContainsPoint(self.selection,point);
    [self updateTouch:point delta:CGPointZero state:UIGestureRecognizerStateBegan];
    FSLog(self.mode==1?@"Crop touch: move":self.mode==2?@"Crop touch: resize":@"Crop touch: draw");
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event; if (![touches containsObject:self.activeTouch]) return;
    CGPoint point=[self.activeTouch locationInView:self];
    if (self.toolTouch && !self.menuPanel.hidden && CGRectContainsPoint(self.menuPanel.frame,self.toolStart)) {
        CGFloat delta=point.y-self.toolStart.y;
        if (fabs(delta)>6) self.menuScrolling=YES;
        if (self.menuScrolling) {
            CGFloat maximum=MAX(0,self.menuActions.count*52-self.menuPanel.bounds.size.height);
            self.menuScrollOffset=MIN(maximum,MAX(0,self.menuScrollOffset-delta));
            self.toolStart=point;
            [self layoutMenuRows];
            return;
        }
    }
    if (self.orderDragIndex>=0) {
        if (!self.orderDragPreview && hypot(point.x-self.toolStart.x,point.y-self.toolStart.y)>8) {
            UILabel *preview=[[UILabel alloc] initWithFrame:CGRectMake(point.x-70,point.y-22,140,44)];
            preview.backgroundColor=UIColor.systemBlueColor; preview.textColor=UIColor.whiteColor;
            preview.textAlignment=NSTextAlignmentCenter; preview.layer.cornerRadius=12; preview.clipsToBounds=YES;
            for (UIButton *button in self.actions) if ([button.accessibilityIdentifier isEqualToString:self.toolbarOrder[self.orderDragIndex]]) {
                preview.text=button.accessibilityLabel; break;
            }
            preview.alpha=0.92;
            self.orderDragPreview=preview; [self addSubview:preview];
        }
        self.orderDragPreview.center=point;
        return;
    }
    if (self.toolTouch) return;
    if (self.pendingMark) {
        point.x=MAX(CGRectGetMinX(self.selection),MIN(CGRectGetMaxX(self.selection),point.x));
        point.y=MAX(CGRectGetMinY(self.selection),MIN(CGRectGetMaxY(self.selection),point.y));
        NSValue *value=[NSValue valueWithCGPoint:point];
        if (self.pendingMark.blur) {
            if (self.pendingMark.points.count>1) [self.pendingMark.points removeLastObject];
            [self.pendingMark.points addObject:value];
        } else if (self.pendingMark.points.count<4096) [self.pendingMark.points addObject:value];
        [self.editView setNeedsDisplay]; return;
    }
    CGPoint delta=CGPointMake(point.x-self.origin.x,point.y-self.origin.y);
    if (hypot(delta.x,delta.y)>6) self.touchMoved=YES;
    if (self.touchMoved) [self updateTouch:point delta:delta state:UIGestureRecognizerStateChanged];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event; if (![touches containsObject:self.activeTouch]) return;
    UITouch *touch=self.activeTouch;
    CGPoint point=[touch locationInView:self];
    if (self.menuScrolling) {
        self.menuScrolling=NO; self.toolTouch=NO; self.pendingAction=nil; self.activeTouch=nil;
        return;
    }
    if (self.orderDragIndex>=0) {
        NSInteger from=self.orderDragIndex;
        BOOL moved=self.orderDragPreview!=nil;
        [self.orderDragPreview removeFromSuperview]; self.orderDragPreview=nil;
        self.orderDragIndex=-1; self.toolTouch=NO; self.pendingAction=nil; self.activeTouch=nil;
        NSInteger to=-1;
        if (moved && CGRectContainsPoint(self.orderPanel.frame,point)) {
            to=(NSInteger)floor((point.y-CGRectGetMinY(self.orderPanel.frame))/38);
        } else if (moved && CGRectContainsPoint(self.toolbar.frame,point)) {
            to=(NSInteger)floor((point.x-CGRectGetMinX(self.toolbar.frame))*self.toolbarOrder.count/MAX(1,self.toolbar.frame.size.width));
        }
        if (to>=0 && to<(NSInteger)self.toolbarOrder.count && to!=from) {
            NSMutableArray *order=[self.toolbarOrder mutableCopy];
            id item=order[from]; [order removeObjectAtIndex:from]; [order insertObject:item atIndex:to];
            self.toolbarOrder=order; [[NSUserDefaults standardUserDefaults] setObject:order forKey:@"FSToolbarOrder"];
            [self updateSelection];
        }
        return;
    }
    if (self.toolTouch) {
        NSString *name=self.pendingAction;
        self.toolTouch=NO; self.pendingAction=nil; self.activeTouch=nil;
        if (hypot(point.x-self.toolStart.x,point.y-self.toolStart.y)<22 &&
            [name isEqualToString:[self toolAtPoint:point]]) [self requestAction:name];
        return;
    }
    if (self.pendingMark) {
        [self touchesMoved:touches withEvent:event];
        if (self.marks.count<100) [self.marks addObject:self.pendingMark];
        self.pendingMark=nil; self.editView.pending=nil;
        self.editView.marks=self.marks; [self.editView setNeedsDisplay]; [self updateSelection];
        self.activeTouch=nil; return;
    }
    BOOL commit=!self.touchMoved && self.touchStartedInside && touch.tapCount==2 && FSPrefBool(@"DoubleTapToPin",YES);
    if (self.touchMoved) [self updateTouch:point delta:CGPointMake(point.x-self.origin.x,point.y-self.origin.y) state:UIGestureRecognizerStateEnded];
    else { self.selection=self.initialRect; self.dragging=NO; [self updateSelection]; }
    self.activeTouch=nil;
    if (commit && self.completion) {
        FSLog(@"Crop double tap: committing selection");
        self.completion(self.selection,self.bounds.size);
    }
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)touches; (void)event; self.activeTouch=nil; self.toolTouch=NO; self.pendingAction=nil;
    self.menuScrolling=NO;
    [self.orderDragPreview removeFromSuperview]; self.orderDragPreview=nil; self.orderDragIndex=-1;
    self.pendingMark=nil; self.editView.pending=nil; [self.editView setNeedsDisplay];
    self.selection=self.initialRect; self.dragging=NO; [self updateSelection];
}
- (void)updateTouch:(CGPoint)point delta:(CGPoint)delta state:(UIGestureRecognizerState)state {
    if (state == UIGestureRecognizerStateBegan) {
        self.dragging=YES;
        self.origin = CGPointMake(MAX(0,MIN(self.bounds.size.width,point.x-delta.x)), MAX(0,MIN(self.bounds.size.height,point.y-delta.y)));
        self.initialRect = self.selection;
        self.edges = 0;
        BOOL hasRect = self.selection.size.width>=24 && self.selection.size.height>=24;
        if (hasRect && CGRectContainsPoint(CGRectInset(self.selection,-22,-22),self.origin)) {
            if (fabs(self.origin.x-CGRectGetMinX(self.selection))<=22) self.edges |= FSLeft;
            else if (fabs(self.origin.x-CGRectGetMaxX(self.selection))<=22) self.edges |= FSRight;
            if (fabs(self.origin.y-CGRectGetMinY(self.selection))<=22) self.edges |= FSTop;
            else if (fabs(self.origin.y-CGRectGetMaxY(self.selection))<=22) self.edges |= FSBottom;
        }
        // Keep the interior of small crops usable for dragging.
        if (hasRect && CGRectContainsPoint(CGRectInset(self.selection,MIN(8,self.selection.size.width/5),MIN(8,self.selection.size.height/5)), self.origin)) self.edges=0;
        self.mode = self.edges ? 2 : (hasRect && CGRectContainsPoint(self.selection,self.origin) ? 1 : 0);
    }
    if (state==UIGestureRecognizerStateCancelled || state==UIGestureRecognizerStateFailed) {
        self.dragging=NO;
        self.selection=self.initialRect;
        [self updateSelection];
        return;
    }
    if (state==UIGestureRecognizerStateEnded) self.dragging=NO;
    CGFloat width=self.bounds.size.width, height=self.bounds.size.height;
    if (self.mode==1) {
        CGRect moved=self.initialRect;
        moved.origin.x=MAX(0,MIN(width-moved.size.width,moved.origin.x+delta.x));
        moved.origin.y=MAX(0,MIN(height-moved.size.height,moved.origin.y+delta.y));
        self.selection=moved;
    } else if (self.mode==2) {
        CGFloat left=CGRectGetMinX(self.initialRect), right=CGRectGetMaxX(self.initialRect);
        CGFloat top=CGRectGetMinY(self.initialRect), bottom=CGRectGetMaxY(self.initialRect);
        if (self.edges&FSLeft) left=MAX(0,MIN(right-24,left+delta.x));
        if (self.edges&FSRight) right=MIN(width,MAX(left+24,right+delta.x));
        if (self.edges&FSTop) top=MAX(0,MIN(bottom-24,top+delta.y));
        if (self.edges&FSBottom) bottom=MIN(height,MAX(top+24,bottom+delta.y));
        self.selection=CGRectMake(left,top,right-left,bottom-top);
    } else {
        point.x=MAX(0,MIN(width,point.x)); point.y=MAX(0,MIN(height,point.y));
        self.selection=CGRectMake(MIN(self.origin.x,point.x),MIN(self.origin.y,point.y),fabs(point.x-self.origin.x),fabs(point.y-self.origin.y));
    }
    [self updateSelection];
}
- (void)updateSelection {
    BOOL valid=self.selection.size.width>=24 && self.selection.size.height>=24;
    self.toolbar.hidden=!valid || self.dragging;
    self.hint.hidden=valid;
    if (!valid || self.dragging) { self.menuPanel.hidden=YES; self.orderPanel.hidden=YES; }
    if (!self.dragging) {
    CGFloat toolbarWidth=MIN(384,self.bounds.size.width-16);
    NSUInteger columns=self.actions.count;
    CGFloat toolbarHeight=50;
    CGFloat x=MAX(8,MIN(self.bounds.size.width-toolbarWidth-8,CGRectGetMidX(self.selection)-toolbarWidth/2));
    CGFloat y=CGRectGetMaxY(self.selection)+8;
    CGFloat toolbarBottom=CGRectGetMinY(self.cancelButton.frame)-8;
    if (y+toolbarHeight>toolbarBottom) y=CGRectGetMinY(self.selection)-toolbarHeight-8;
    y=MAX(MAX(8,self.safeAreaInsets.top),MIN(y,toolbarBottom-toolbarHeight));
    self.toolbar.frame=CGRectMake(x,y,toolbarWidth,toolbarHeight);
    for (NSUInteger i=0;i<self.toolbarOrder.count;i++) for (UIButton *button in self.actions)
        if ([button.accessibilityIdentifier isEqualToString:self.toolbarOrder[i]]) button.frame=CGRectMake(i*toolbarWidth/columns,0,toolbarWidth/columns,toolbarHeight);
    // Subtle separator between editing and capture actions.
    UIView *separator=[self.toolbar viewWithTag:8901];
    if (!separator) { separator=[UIView new]; separator.tag=8901; separator.backgroundColor=[UIColor colorWithWhite:1 alpha:0.22]; [self.toolbar addSubview:separator]; }
    separator.hidden=YES;
    CGFloat menuWidth=MIN(340,self.bounds.size.width-24);
    CGFloat top=MAX(8,self.safeAreaInsets.top)+8;
    CGFloat above=MAX(0,y-top-8);
    CGFloat below=MAX(0,CGRectGetMinY(self.cancelButton.frame)-8-(y+toolbarHeight+8));
    BOOL placeAbove=above>=below;
    CGFloat menuHeight=MIN(self.menuActions.count*52,placeAbove?above:below);
    CGFloat menuY=placeAbove?y-menuHeight-8:y+toolbarHeight+8;
    self.menuScrollOffset=MIN(self.menuScrollOffset,MAX(0,self.menuActions.count*52-menuHeight));
    self.menuPanel.frame=CGRectMake(MAX(12,MIN(self.bounds.size.width-menuWidth-12,CGRectGetMaxX(self.toolbar.frame)-menuWidth)),menuY,menuWidth,menuHeight);
    [self layoutMenuRows];
    CGFloat orderHeight=self.toolbarOrder.count*38+44;
    CGFloat orderY=MAX(top,MIN(CGRectGetMinY(self.cancelButton.frame)-8-orderHeight,y-orderHeight-8));
    self.orderPanel.frame=CGRectMake(MAX(12,MIN(self.bounds.size.width-menuWidth-12,CGRectGetMaxX(self.toolbar.frame)-menuWidth)),orderY,menuWidth,orderHeight);
    if (!self.orderPanel.hidden) [self refreshOrderPanel];
    }
    self.centerLock.hidden=!valid || !self.selectionLocked || self.dragging || !self.menuPanel.hidden || !self.orderPanel.hidden;
    self.centerLock.frame=CGRectMake(CGRectGetMidX(self.selection)-23,CGRectGetMidY(self.selection)-23,46,46);
    self.undoDrawing.hidden=!valid || self.marks.count==0 || self.dragging || !self.menuPanel.hidden || !self.orderPanel.hidden;
    self.undoDrawing.frame=CGRectMake(CGRectGetMinX(self.toolbar.frame),MAX(MAX(8,self.safeAreaInsets.top),CGRectGetMinY(self.toolbar.frame)-48),44,44);
    if (!self.dragging) {
        [self bringSubviewToFront:self.menuPanel]; [self bringSubviewToFront:self.orderPanel];
        [self bringSubviewToFront:self.centerLock]; [self bringSubviewToFront:self.undoDrawing];
        [self bringSubviewToFront:self.cancelButton];
    }
    UIBezierPath *border=[UIBezierPath bezierPath];
    UIBezierPath *grips=[UIBezierPath bezierPath];
    if (valid) {
        [border appendPath:[UIBezierPath bezierPathWithRect:CGRectInset(self.selection,1,1)]];
        CGFloat xs[]={CGRectGetMinX(self.selection),CGRectGetMidX(self.selection),CGRectGetMaxX(self.selection)};
        CGFloat ys[]={CGRectGetMinY(self.selection),CGRectGetMidY(self.selection),CGRectGetMaxY(self.selection)};
        for (NSUInteger row=0;row<3;row++) for (NSUInteger col=0;col<3;col++) {
            if (row==1 && col==1) continue;
            [grips appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(xs[col]-4,ys[row]-4,8,8)]];
        }
        self.dimensions.text=[NSString stringWithFormat:@"%.0f × %.0f px",self.selection.size.width*UIScreen.mainScreen.scale,self.selection.size.height*UIScreen.mainScreen.scale];
        CGFloat y=CGRectGetMinY(self.selection)-30;
        if (y<MAX(8,self.safeAreaInsets.top)) y=CGRectGetMaxY(self.selection)+6;
        self.dimensions.frame=CGRectMake(MAX(8,MIN(self.bounds.size.width-126,CGRectGetMaxX(self.selection)-126)),y,126,23);
    }
    self.dimensions.hidden=!valid || self.dragging;
    if (self.marks.count || self.pendingMark) {
        self.editView.selection=valid?self.selection:CGRectZero;
        [self.editView setNeedsDisplay];
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    // Draw only outside the selection. No even-odd transparent hole is
    // composited into the SpringBoard overlay window.
    UIBezierPath *shadePath=[UIBezierPath bezierPath];
    CGRect area=CGRectIntersection(self.bounds,self.selection);
    if (!valid || CGRectIsNull(area) || CGRectIsEmpty(area)) {
        [shadePath appendPath:[UIBezierPath bezierPathWithRect:self.bounds]];
    } else {
        CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
        CGFloat left=CGRectGetMinX(area),right=CGRectGetMaxX(area);
        CGFloat top=CGRectGetMinY(area),bottom=CGRectGetMaxY(area);
        [shadePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(0,0,w,top)]];
        [shadePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(0,bottom,w,h-bottom)]];
        [shadePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(0,top,left,bottom-top)]];
        [shadePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(right,top,w-right,bottom-top)]];
    }
    self.shade.frame = self.bounds;
    self.shade.path = shadePath.CGPath;
    self.outline.path=border.CGPath;
    self.handles.path=grips.CGPath;
    [CATransaction commit];
}
- (void)layoutMenuRows {
    CGFloat width=self.menuPanel.bounds.size.width;
    for (NSUInteger i=0;i<self.menuActions.count;i++) {
        UIView *row=[self.menuPanel viewWithTag:1000+i];
        row.frame=CGRectMake(0,i*52-self.menuScrollOffset,width,52);
        [row viewWithTag:2000].frame=CGRectMake(54,0,width-74,52);
        [row viewWithTag:2001].frame=CGRectMake(17,14,24,24);
        [row viewWithTag:2002].frame=CGRectMake(12,0,width-24,0.5);
    }
}
- (void)preparePixelatedPreview {
    if (self.editView.pixelatedScreen) return;
    if (!self.sourceImage.CGImage && self.sourceImageRequested) _sourceImage=self.sourceImageRequested();
    if (!self.sourceImage.CGImage) return;
    CGSize reduced=CGSizeMake(MAX(1,ceil(self.bounds.size.width/18)),MAX(1,ceil(self.bounds.size.height/18)));
    UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];
    format.scale=1; format.opaque=YES;
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:reduced format:format];
    self.editView.pixelatedScreen=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        (void)context; [self.sourceImage drawInRect:(CGRect){CGPointZero,reduced}];
    }];
    [self.editView setNeedsDisplay];
}
- (void)setSourceImage:(UIImage *)sourceImage {
    _sourceImage=sourceImage;
    if (self.editTool==2) [self preparePixelatedPreview];
}
- (BOOL)selectionIsLocked { return self.selectionLocked; }
- (UIImage *)imageByApplyingMarksToCrop:(UIImage *)crop selection:(CGRect)selection {
    if (!crop.CGImage || !self.marks.count || selection.size.width<1 || selection.size.height<1) return crop;
    CGFloat sx=crop.size.width/selection.size.width,sy=crop.size.height/selection.size.height;
    BOOL hasBlur=NO;
    for (FSPreMark *mark in self.marks) if (mark.blur) { hasBlur=YES; break; }
    UIImage *mosaic=nil;
    if (hasBlur) {
        CGSize reduced=CGSizeMake(MAX(1,ceil(crop.size.width/18)),MAX(1,ceil(crop.size.height/18)));
        UIGraphicsImageRendererFormat *smallFormat=[UIGraphicsImageRendererFormat defaultFormat];
        smallFormat.scale=1; smallFormat.opaque=YES;
        UIGraphicsImageRenderer *small=[[UIGraphicsImageRenderer alloc] initWithSize:reduced format:smallFormat];
        mosaic=[small imageWithActions:^(UIGraphicsImageRendererContext *context) {
            (void)context; [crop drawInRect:(CGRect){CGPointZero,reduced}];
        }];
    }
    UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];
    format.scale=crop.scale; format.opaque=YES;
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:crop.size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *renderContext) {
        [crop drawInRect:(CGRect){CGPointZero,crop.size}];
        CGContextRef context=renderContext.CGContext;
        CGContextSaveGState(context); CGContextClipToRect(context,(CGRect){CGPointZero,crop.size});
        for (FSPreMark *mark in self.marks) {
            if (!mark.points.count) continue;
            CGPoint first=mark.points.firstObject.CGPointValue;
            if (mark.blur && mark.points.count>=2 && mosaic) {
                CGPoint last=mark.points.lastObject.CGPointValue;
                CGRect area=CGRectMake((MIN(first.x,last.x)-selection.origin.x)*sx,
                                       (MIN(first.y,last.y)-selection.origin.y)*sy,
                                       fabs(first.x-last.x)*sx,fabs(first.y-last.y)*sy);
                if (area.size.width<3 || area.size.height<3) continue;
                CGContextSaveGState(context); CGContextClipToRect(context,area);
                CGContextSetInterpolationQuality(context,kCGInterpolationNone);
                [mosaic drawInRect:(CGRect){CGPointZero,crop.size}];
                CGContextRestoreGState(context);
            } else if (!mark.blur) {
                UIBezierPath *path=[UIBezierPath bezierPath]; path.lineWidth=3*MAX(sx,sy);
                path.lineCapStyle=kCGLineCapRound; path.lineJoinStyle=kCGLineJoinRound;
                [path moveToPoint:CGPointMake((first.x-selection.origin.x)*sx,(first.y-selection.origin.y)*sy)];
                for (NSValue *value in mark.points) {
                    CGPoint point=value.CGPointValue;
                    [path addLineToPoint:CGPointMake((point.x-selection.origin.x)*sx,(point.y-selection.origin.y)*sy)];
                }
                [UIColor.systemYellowColor setStroke]; [path stroke];
            }
        }
        CGContextRestoreGState(context);
    }];
}
- (void)updateToolButtons {
    NSArray *names=@[@"pen",@"blur",@"lock"];
    for (NSString *name in names) {
        for (UIButton *button in self.actions) if ([button.accessibilityIdentifier isEqualToString:name]) {
            BOOL selected=[name isEqualToString:@"pen"]?self.editTool==1:
                [name isEqualToString:@"blur"]?self.editTool==2:self.selectionLocked;
            button.tintColor=selected?UIColor.systemCyanColor:UIColor.whiteColor;
            if ([name isEqualToString:@"lock"]) {
                [button setImage:FSIcon(selected?@"lock.fill":@"lock.open") forState:UIControlStateNormal];
                button.accessibilityLabel=selected?FSL(@"فتح التحديد",@"Unlock selection"):FSL(@"قفل التحديد",@"Lock selection");
            }
        }
    }
}
- (void)requestAction:(NSString *)name {
    if (!name) return;
    FSLog([NSString stringWithFormat:@"Crop action: %@",name]);
    if ([name isEqualToString:@"more"]) { self.orderPanel.hidden=YES; self.menuScrollOffset=0; self.menuPanel.hidden=!self.menuPanel.hidden; [self layoutMenuRows]; return; }
    if ([name isEqualToString:@"arrange"]) { self.menuPanel.hidden=YES; self.orderPanel.hidden=NO; [self updateSelection]; return; }
    if ([name isEqualToString:@"orderDone"]) { self.orderPanel.hidden=YES; return; }
    self.menuPanel.hidden=YES;
    if ([name isEqualToString:@"cancel"]) { [self cancel]; return; }
    if ([name isEqualToString:@"full"]) {
        if (!self.selectionLocked && !self.marks.count) [self selectAll]; return;
    }
    if ([name isEqualToString:@"undo"]) {
        if (self.marks.count) { [self.marks removeLastObject]; self.editView.marks=self.marks; [self.editView setNeedsDisplay]; [self updateSelection]; }
        return;
    }
    if (self.selection.size.width<24 || self.selection.size.height<24) return;
    if ([name isEqualToString:@"lock"]) {
        self.selectionLocked=!self.selectionLocked;
        [self updateToolButtons]; [self updateSelection]; return;
    }
    if ([name isEqualToString:@"pen"] || [name isEqualToString:@"blur"]) {
        NSInteger tool=[name isEqualToString:@"pen"]?1:2;
        self.editTool=self.editTool==tool?0:tool;

        self.hint.hidden=self.editTool==0;
        self.hint.text=self.editTool==1?FSL(@"ارسم داخل التحديد بالقلم",@"Draw inside the selection"):
            FSL(@"اسحب لتغويش المنطقة داخل التحديد",@"Drag to mosaic an area inside the selection");
        if (self.editTool==2) [self preparePixelatedPreview];
        [self updateToolButtons]; return;
    }
    if ([name isEqualToString:@"pin"]) { if (self.completion) self.completion(self.selection,self.bounds.size); }
    else if (self.actionRequested) self.actionRequested(name,self.selection,self.bounds.size);
}
- (void)refreshOrderPanel {
    for (UIView *view in self.orderPanel.subviews) [view removeFromSuperview];
    NSDictionary *labels=@{@"rectangle":FSL(@"مستطيل",@"Rectangle"),@"line":FSL(@"خط",@"Line"),@"arrow":FSL(@"سهم",@"Arrow"),@"pen":FSL(@"قلم",@"Pen"),@"blur":FSL(@"غويش",@"Mosaic"),@"lock":FSL(@"قفل",@"Lock"),@"pin":FSL(@"تثبيت",@"Pin"),@"textcopy":FSL(@"نسخ النص",@"Copy text"),@"copy":FSL(@"نسخ الصورة",@"Copy image"),@"save":FSL(@"حفظ",@"Save"),@"more":FSL(@"المزيد",@"More")};
    CGFloat width=self.orderPanel.bounds.size.width;
    for (NSUInteger i=0;i<self.toolbarOrder.count;i++) {
        UILabel *row=[[UILabel alloc] initWithFrame:CGRectMake(46,i*38,width-102,38)];
        row.text=labels[self.toolbarOrder[i]];
        row.textColor=UIColor.blackColor; row.font=[UIFont systemFontOfSize:15]; [self.orderPanel addSubview:row];
        for (UIButton *button in self.actions) if ([button.accessibilityIdentifier isEqualToString:self.toolbarOrder[i]]) {
            UIImageView *icon=[[UIImageView alloc] initWithImage:[button imageForState:UIControlStateNormal]];
            icon.frame=CGRectMake(14,i*38+9,20,20); icon.tintColor=UIColor.systemBlueColor;
            icon.contentMode=UIViewContentModeScaleAspectFit; [self.orderPanel addSubview:icon]; break;
        }
        UILabel *handle=[[UILabel alloc] initWithFrame:CGRectMake(width-55,i*38,45,38)];
        handle.text=@"☰"; handle.textColor=UIColor.systemGrayColor; handle.textAlignment=NSTextAlignmentCenter;
        [self.orderPanel addSubview:handle];
    }
    UILabel *done=[[UILabel alloc] initWithFrame:CGRectMake(0,self.toolbarOrder.count*38,width,44)];
    done.text=FSL(@"تم",@"Done"); done.textColor=UIColor.systemBlueColor; done.textAlignment=NSTextAlignmentCenter;
    [self.orderPanel addSubview:done];
}
- (void)action:(UIButton *)button { [self requestAction:button.accessibilityIdentifier]; }
- (CGRect)selectedRect { return self.selection; }
- (void)restoreSelection:(CGRect)rect {
    CGRect clipped=CGRectIntersection(self.bounds,rect);
    if (!CGRectIsNull(clipped) && clipped.size.width>=24 && clipped.size.height>=24) { self.selection=clipped; [self updateSelection]; }
}
- (void)selectAll { self.selection=self.bounds; [self updateSelection]; }
- (void)cancel { if (self.cancelled) self.cancelled(); }
@end
