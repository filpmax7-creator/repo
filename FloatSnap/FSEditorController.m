#import "FSIcons.h"
#import "FSEditorController.h"
#import "FSLocale.h"
#import <math.h>

typedef NS_ENUM(NSInteger, FSEditTool) { FSPen, FSArrow, FSRectangle, FSEllipse, FSCover, FSText, FSNumber, FSLine, FSBlur };
@interface FSMark : NSObject
@property(nonatomic) FSEditTool tool;
@property(nonatomic,strong) UIColor *color;
@property(nonatomic) CGFloat width;
@property(nonatomic) BOOL filled;
@property(nonatomic,strong) NSMutableArray<NSValue *> *points;
@property(nonatomic,copy) NSString *text;
@end
@implementation FSMark
@end

@interface FSEditCanvas : UIView
@property(nonatomic,strong) UIImage *image;
@property(nonatomic,strong) UIImage *pixelatedImage;
@property(nonatomic,strong) NSMutableArray<FSMark *> *marks;
@property(nonatomic,strong) NSMutableArray<FSMark *> *redoMarks;
@property(nonatomic,strong) FSMark *pending;
@property(nonatomic) FSEditTool tool;
@property(nonatomic,strong) UIColor *ink;
@property(nonatomic) CGFloat strokeWidth;
@property(nonatomic) BOOL fillShape;
@property(nonatomic,copy) NSString *labelText;
@property(nonatomic,copy) dispatch_block_t changed;
- (UIImage *)flattenedImage;
- (void)undo;
- (void)redo;
@end

@implementation FSEditCanvas
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.backgroundColor=[UIColor colorWithWhite:0.08 alpha:1];
        self.multipleTouchEnabled=NO; self.ink=UIColor.systemRedColor; self.strokeWidth=4;
        self.marks=[NSMutableArray array]; self.redoMarks=[NSMutableArray array]; self.labelText=FSL(@"نص",@"Text");
        self.contentMode=UIViewContentModeRedraw;
    } return self;
}
- (void)setImage:(UIImage *)image { _image=image; _pixelatedImage=nil; [self setNeedsDisplay]; }
- (UIImage *)pixelatedImage {
    if (_pixelatedImage || !self.image) return _pixelatedImage;
    CGSize size=CGSizeMake(MAX(1,ceil(self.image.size.width/22)),MAX(1,ceil(self.image.size.height/22)));
    UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];
    format.scale=1; format.opaque=YES;
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    _pixelatedImage=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextSetInterpolationQuality(context.CGContext,kCGInterpolationLow);
        [self.image drawInRect:(CGRect){CGPointZero,size}];
    }];
    return _pixelatedImage;
}
- (CGRect)imageRect {
    if (self.image.size.width<=0 || self.image.size.height<=0) return CGRectZero;
    CGFloat scale=MIN(self.bounds.size.width/self.image.size.width,self.bounds.size.height/self.image.size.height);
    CGSize size=CGSizeMake(self.image.size.width*scale,self.image.size.height*scale);
    return CGRectMake((self.bounds.size.width-size.width)/2,(self.bounds.size.height-size.height)/2,size.width,size.height);
}
- (CGPoint)imagePoint:(CGPoint)point {
    CGRect rect=[self imageRect];
    return CGPointMake(MAX(0,MIN(self.image.size.width,(point.x-rect.origin.x)*self.image.size.width/MAX(1,rect.size.width))),
                       MAX(0,MIN(self.image.size.height,(point.y-rect.origin.y)*self.image.size.height/MAX(1,rect.size.height))));
}
- (void)drawMark:(FSMark *)mark {
    if (!mark.points.count) return;
    CGPoint first=mark.points.firstObject.CGPointValue,last=mark.points.lastObject.CGPointValue;
    CGRect rect=CGRectMake(MIN(first.x,last.x),MIN(first.y,last.y),fabs(last.x-first.x),fabs(last.y-first.y));
    [mark.color setStroke]; [mark.color setFill];
    UIBezierPath *path=nil;
    switch (mark.tool) {
        case FSPen:
            path=[UIBezierPath bezierPath]; [path moveToPoint:first];
            for (NSValue *value in mark.points) [path addLineToPoint:value.CGPointValue];
            if (mark.points.count==1) { [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(first.x-mark.width/2,first.y-mark.width/2,mark.width,mark.width)] fill]; return; }
            break;
        case FSArrow: {
            path=[UIBezierPath bezierPath]; [path moveToPoint:first]; [path addLineToPoint:last];
            CGFloat angle=atan2(last.y-first.y,last.x-first.x),length=MAX(12,mark.width*4);
            [path moveToPoint:CGPointMake(last.x-length*cos(angle-0.5),last.y-length*sin(angle-0.5))];
            [path addLineToPoint:last];
            [path addLineToPoint:CGPointMake(last.x-length*cos(angle+0.5),last.y-length*sin(angle+0.5))]; break;
        }
        case FSLine: path=[UIBezierPath bezierPath]; [path moveToPoint:first]; [path addLineToPoint:last]; break;
        case FSBlur: {
            if (rect.size.width<3 || rect.size.height<3) return;
            CGContextRef context=UIGraphicsGetCurrentContext(); CGContextSaveGState(context);
            CGContextClipToRect(context,CGRectIntegral(rect));
            CGContextSetInterpolationQuality(context,kCGInterpolationNone);
            [[self pixelatedImage] drawInRect:(CGRect){CGPointZero,self.image.size}];
            CGContextRestoreGState(context); return;
        }
        case FSRectangle: path=[UIBezierPath bezierPathWithRect:rect]; break;
        case FSEllipse: path=[UIBezierPath bezierPathWithOvalInRect:rect]; break;
        case FSCover:
            // Solid pixels replace the covered source region in the exported bitmap.
            [[mark.color colorWithAlphaComponent:1] setFill];
            UIRectFill(CGRectIntegral(rect)); return;
        case FSText:
        case FSNumber: {
            CGFloat fontSize=MAX(16,mark.width*5);
            NSDictionary *attributes=@{NSFontAttributeName:[UIFont boldSystemFontOfSize:fontSize],NSForegroundColorAttributeName:mark.color};
            CGSize textSize=[mark.text sizeWithAttributes:attributes];
            CGPoint location=CGPointMake(MAX(0,MIN(first.x,self.image.size.width-textSize.width)),MAX(0,MIN(first.y,self.image.size.height-textSize.height)));
            [mark.text drawAtPoint:location withAttributes:attributes]; return;
        }
    }
    path.lineWidth=mark.width; path.lineCapStyle=kCGLineCapRound; path.lineJoinStyle=kCGLineJoinRound;
    if (mark.filled && (mark.tool==FSRectangle || mark.tool==FSEllipse)) [path fill]; else [path stroke];
}
- (void)drawContent {
    [self.image drawInRect:(CGRect){CGPointZero,self.image.size}];
    for (FSMark *mark in self.marks) [self drawMark:mark];
    if (self.pending) [self drawMark:self.pending];
}
- (void)drawRect:(CGRect)dirty {
    (void)dirty; CGRect rect=[self imageRect]; if (CGRectIsEmpty(rect)) return;
    CGContextRef context=UIGraphicsGetCurrentContext(); CGContextSaveGState(context);
    CGContextClipToRect(context,rect); CGContextTranslateCTM(context,rect.origin.x,rect.origin.y);
    CGContextScaleCTM(context,rect.size.width/self.image.size.width,rect.size.height/self.image.size.height);
    [self drawContent]; CGContextRestoreGState(context);
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    CGPoint point=[touches.anyObject locationInView:self];
    if (!CGRectContainsPoint([self imageRect],point) || self.pending || self.marks.count>=200) return;
    FSMark *mark=[FSMark new]; mark.tool=self.tool; mark.color=self.ink;
    mark.width=self.strokeWidth*self.image.size.width/MAX(1,[self imageRect].size.width);
    mark.filled=self.fillShape; mark.points=[NSMutableArray arrayWithObject:[NSValue valueWithCGPoint:[self imagePoint:point]]];
    if (self.tool==FSText) mark.text=self.labelText;
    if (self.tool==FSNumber) {
        NSUInteger count=1; for (FSMark *item in self.marks) if (item.tool==FSNumber) ++count;
        mark.text=[NSString stringWithFormat:@"%lu",(unsigned long)count];
    }
    self.pending=mark; [self setNeedsDisplay];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event; if (!self.pending) return;
    NSValue *point=[NSValue valueWithCGPoint:[self imagePoint:[touches.anyObject locationInView:self]]];
    if (self.pending.tool==FSPen) { if (self.pending.points.count<4096) [self.pending.points addObject:point]; }
    else if (self.pending.tool==FSText || self.pending.tool==FSNumber) self.pending.points[0]=point;
    else { if (self.pending.points.count>1) [self.pending.points removeLastObject]; [self.pending.points addObject:point]; }
    [self setNeedsDisplay];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesMoved:touches withEvent:event]; if (!self.pending) return;
    [self.marks addObject:self.pending]; self.pending=nil; [self.redoMarks removeAllObjects];
    [self setNeedsDisplay]; if (self.changed) self.changed();
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)touches; (void)event; self.pending=nil; [self setNeedsDisplay];
}
- (void)undo {
    self.pending=nil; if (!self.marks.count) return;
    [self.redoMarks addObject:self.marks.lastObject]; [self.marks removeLastObject];
    [self setNeedsDisplay]; if (self.changed) self.changed();
}
- (void)redo {
    self.pending=nil; if (!self.redoMarks.count) return;
    [self.marks addObject:self.redoMarks.lastObject]; [self.redoMarks removeLastObject];
    [self setNeedsDisplay]; if (self.changed) self.changed();
}
- (UIImage *)flattenedImage {
    self.pending=nil;
    UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];
    format.scale=self.image.scale; format.opaque=YES;
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:self.image.size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { (void)context; [self drawContent]; }];
}
@end

@interface FSEditorController ()
@property(nonatomic,strong) UIImage *source;
@property(nonatomic,strong) FSEditCanvas *canvas;
@property(nonatomic,strong) UIScrollView *controls;
@property(nonatomic,strong) UILabel *hint;
@property(nonatomic,strong) NSArray<UIButton *> *toolButtons;
@property(nonatomic,strong) NSArray<UIButton *> *colorButtons;
@property(nonatomic,strong) UIButton *undoButton;
@property(nonatomic,strong) UIButton *redoButton;
@end
@implementation FSEditorController
- (instancetype)initWithImage:(UIImage *)image { if ((self=[super init])) _source=image; return self; }
- (UIButton *)button:(NSString *)title frame:(CGRect)frame action:(SEL)action parent:(UIView *)parent {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem]; button.frame=frame;
    [button setTitle:title forState:UIControlStateNormal]; [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.layer.cornerRadius=8; [parent addSubview:button]; return button;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=FSL(@"تعديل القصاصة",@"Edit clip"); self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:FSL(@"إلغاء",@"Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:FSL(@"تم",@"Done") style:UIBarButtonItemStyleDone target:self action:@selector(done)];
    self.canvas=[[FSEditCanvas alloc] initWithFrame:CGRectZero]; self.canvas.image=self.source; [self.view addSubview:self.canvas];
    self.hint=[UILabel new]; self.hint.font=[UIFont systemFontOfSize:12]; self.hint.textAlignment=NSTextAlignmentCenter; self.hint.numberOfLines=2;
    self.hint.text=FSL(@"اسحب فوق الصورة للرسم • تم يطبّق التعديلات على القصاصة",@"Draw on image • Done applies changes"); [self.view addSubview:self.hint];
    self.controls=[UIScrollView new]; self.controls.alwaysBounceHorizontal=YES; [self.view addSubview:self.controls];
    NSArray *names=@[FSL(@"قلم",@"Pen"),FSL(@"سهم",@"Arrow"),FSL(@"مستطيل",@"Rectangle"),FSL(@"دائرة",@"Circle"),FSL(@"تغطية",@"Cover"),FSL(@"نص",@"Text"),FSL(@"ترقيم",@"Number"),FSL(@"خط",@"Line"),FSL(@"غويش",@"Mosaic")];
    NSArray *icons=@[@"pencil",@"arrow.up.right",@"rectangle",@"circle",@"rectangle.fill",@"textformat",@"number",@"line.diagonal",@"square.dashed"];
    NSMutableArray *buttons=[NSMutableArray array];
    for (NSUInteger i=0;i<names.count;i++) {
        UIButton *button=[self button:names[i] frame:CGRectMake(i*72,0,68,44) action:@selector(tool:) parent:self.controls]; button.tag=i; FSConfigureIconButton(button,icons[i],names[i]); [buttons addObject:button];
    } self.toolButtons=buttons;
    NSArray *colors=@[UIColor.systemRedColor,UIColor.systemOrangeColor,UIColor.systemYellowColor,UIColor.systemGreenColor,UIColor.systemBlueColor,UIColor.systemPurpleColor,UIColor.whiteColor,UIColor.blackColor];
    NSArray *colorNames=@[FSL(@"أحمر",@"Red"),FSL(@"برتقالي",@"Orange"),FSL(@"أصفر",@"Yellow"),FSL(@"أخضر",@"Green"),FSL(@"أزرق",@"Blue"),FSL(@"بنفسجي",@"Purple"),FSL(@"أبيض",@"White"),FSL(@"أسود",@"Black")];
    NSMutableArray *colorButtons=[NSMutableArray array];
    for (NSUInteger i=0;i<colors.count;i++) {
        UIButton *button=[self button:@"" frame:CGRectMake(i*46,48,40,40) action:@selector(color:) parent:self.controls];
        button.backgroundColor=colors[i]; button.accessibilityLabel=colorNames[i]; button.layer.borderColor=UIColor.systemGrayColor.CGColor; button.layer.borderWidth=1; [colorButtons addObject:button];
    } self.colorButtons=colorButtons;
    self.undoButton=[self button:FSL(@"تراجع",@"Undo") frame:CGRectMake(372,48,62,44) action:@selector(undo) parent:self.controls];
    self.redoButton=[self button:FSL(@"إعادة",@"Redo") frame:CGRectMake(438,48,62,44) action:@selector(redo) parent:self.controls];
    FSConfigureIconButton(self.undoButton,@"arrow.uturn.backward",FSL(@"تراجع",@"Undo"));
    FSConfigureIconButton(self.redoButton,@"arrow.uturn.forward",FSL(@"إعادة",@"Redo"));
    UILabel *width=[UILabel new]; width.frame=CGRectMake(0,100,70,40); width.text=FSL(@"السُمك",@"Width"); [self.controls addSubview:width];
    UISlider *slider=[[UISlider alloc] initWithFrame:CGRectMake(72,100,180,40)]; slider.minimumValue=1; slider.maximumValue=12; slider.value=4; slider.accessibilityLabel=FSL(@"سُمك الخط وحجم النص",@"Line width and text size");
    [slider addTarget:self action:@selector(width:) forControlEvents:UIControlEventValueChanged]; [self.controls addSubview:slider];
    UILabel *fill=[UILabel new]; fill.frame=CGRectMake(270,100,80,40); fill.text=FSL(@"تعبئة",@"Fill"); [self.controls addSubview:fill];
    UISwitch *toggle=[[UISwitch alloc] initWithFrame:CGRectMake(350,104,52,32)]; toggle.accessibilityLabel=FSL(@"تعبئة الأشكال",@"Fill shapes");
    [toggle addTarget:self action:@selector(fill:) forControlEvents:UIControlEventValueChanged]; [self.controls addSubview:toggle];
    self.controls.contentSize=CGSizeMake(MAX(648,names.count*72),148);
    __weak typeof(self) weakSelf=self; self.canvas.changed=^{ [weakSelf updateButtons]; };
    [self updateButtons];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; CGRect safe=self.view.safeAreaLayoutGuide.layoutFrame;
    CGFloat controlsHeight=148,hintHeight=36;
    self.controls.frame=CGRectMake(safe.origin.x+8,CGRectGetMaxY(safe)-controlsHeight,MAX(0,safe.size.width-16),controlsHeight);
    self.hint.frame=CGRectMake(safe.origin.x,CGRectGetMinY(self.controls.frame)-hintHeight,safe.size.width,hintHeight);
    self.canvas.frame=CGRectMake(safe.origin.x,safe.origin.y,safe.size.width,MAX(1,CGRectGetMinY(self.hint.frame)-safe.origin.y));
}
- (void)updateButtons {
    self.undoButton.enabled=self.canvas.marks.count>0; self.redoButton.enabled=self.canvas.redoMarks.count>0;
    for (UIButton *button in self.toolButtons) button.backgroundColor=button.tag==self.canvas.tool?[UIColor.systemBlueColor colorWithAlphaComponent:0.2]:UIColor.clearColor;
    for (UIButton *button in self.colorButtons) button.layer.borderWidth=[button.backgroundColor isEqual:self.canvas.ink]?4:1;
    if (self.canvas.marks.count>=200) self.hint.text=FSL(@"وصلت إلى 200 إضافة؛ تراجع أو طبّق التعديل",@"200 marks reached; undo or apply changes");
}
- (void)tool:(UIButton *)sender {
    self.canvas.tool=(FSEditTool)sender.tag; [self updateButtons];
    self.hint.text=self.canvas.tool==FSBlur?FSL(@"اسحب مستطيلاً لتغويش المنطقة",@"Drag a rectangle to mosaic an area"):self.canvas.tool==FSCover?FSL(@"اسحب مستطيلاً لتغطية المعلومات بلون ثابت",@"Drag a rectangle to cover information"):FSL(@"اسحب على الصورة • حرّك النص قبل رفع الإصبع",@"Draw on the image • drag text to position");
    if (self.canvas.tool==FSText) {
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:FSL(@"النص",@"Text") message:FSL(@"بعد الإضافة، المس الصورة لوضعه",@"Tap the image to place it") preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text=self.canvas.labelText; field.placeholder=FSL(@"اكتب النص",@"Enter text"); }];
        [alert addAction:[UIAlertAction actionWithTitle:FSL(@"إلغاء",@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:FSL(@"إضافة",@"Add") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            (void)action; NSString *text=alert.textFields.firstObject.text;
            if (text.length) self.canvas.labelText=text.length>200?[text substringToIndex:200]:text;
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
- (void)selectTool:(NSInteger)tool { [self loadViewIfNeeded]; self.canvas.tool=(FSEditTool)tool; [self updateButtons]; if (tool==FSBlur) self.hint.text=FSL(@"اسحب مستطيلاً لتغويش المنطقة",@"Drag a rectangle to mosaic an area"); }
- (void)color:(UIButton *)sender { self.canvas.ink=sender.backgroundColor; [self updateButtons]; }
- (void)width:(UISlider *)sender { self.canvas.strokeWidth=sender.value; }
- (void)fill:(UISwitch *)sender { self.canvas.fillShape=sender.on; }
- (void)undo { [self.canvas undo]; }
- (void)redo { [self.canvas redo]; }
- (void)cancel { if (self.finished) self.finished(nil); }
- (void)done { if (self.finished) self.finished([self.canvas flattenedImage]); }
@end
