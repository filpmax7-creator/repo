#import "HBGlassDockView.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>
@interface HBGlassDockView()
@property(nonatomic,strong) UIVisualEffectView *material;
@property(nonatomic,strong) CAGradientLayer *shine;
@property(nonatomic,readwrite) BOOL glassEnabled;
@property(nonatomic,readwrite) CGFloat materialOpacity;
@end
@implementation HBGlassDockView
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])){
 self.userInteractionEnabled=NO;self.clipsToBounds=YES;self.backgroundColor=UIColor.clearColor;self.layer.cornerCurve=kCACornerCurveContinuous;
 self.material=[[UIVisualEffectView alloc]initWithEffect:nil];self.material.userInteractionEnabled=NO;[self addSubview:self.material];
 self.shine=[CAGradientLayer layer];self.shine.startPoint=CGPointMake(0,0);self.shine.endPoint=CGPointMake(1,1);self.shine.locations=@[@0,@.42,@1];[self.layer addSublayer:self.shine];
 [self configureGlass:YES opacity:.55];
 }return self;
}
- (void)configureGlass:(BOOL)enabled opacity:(CGFloat)opacity {
 opacity=isfinite(opacity)?MAX(.1,MIN(1,opacity)):.55;
 if(!self.material.effect||self.glassEnabled!=enabled)self.material.effect=[UIBlurEffect effectWithStyle:enabled?UIBlurEffectStyleSystemUltraThinMaterial:UIBlurEffectStyleSystemMaterial];
 self.glassEnabled=enabled;self.materialOpacity=opacity;self.material.alpha=enabled?opacity:1;
 [self updateAppearance];
}
- (void)updateAppearance {
 BOOL dark=self.traitCollection.userInterfaceStyle==UIUserInterfaceStyleDark;
 [CATransaction begin];[CATransaction setDisableActions:YES];
 self.shine.hidden=!self.glassEnabled;
 self.shine.colors=@[(id)[UIColor colorWithWhite:1 alpha:dark?.18:.3].CGColor,(id)[UIColor colorWithWhite:1 alpha:.025].CGColor,(id)[UIColor colorWithWhite:dark?0:1 alpha:.09].CGColor];
 self.layer.borderWidth=self.glassEnabled?.75:.5;self.layer.borderColor=[UIColor colorWithWhite:1 alpha:self.glassEnabled?(dark?.4:.65):.18].CGColor;
 [CATransaction commit];
}
- (void)traitCollectionDidChange:(UITraitCollection*)previous{[super traitCollectionDidChange:previous];[self updateAppearance];}
- (void)layoutSubviews{[super layoutSubviews];[CATransaction begin];[CATransaction setDisableActions:YES];self.material.frame=self.bounds;self.shine.frame=self.bounds;self.layer.cornerRadius=MIN(30,self.bounds.size.height/2);[CATransaction commit];}
@end
