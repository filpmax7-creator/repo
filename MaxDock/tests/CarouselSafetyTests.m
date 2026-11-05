#import <UIKit/UIKit.h>
#import "../HBCircularDock.h"
static int checks=0;
#define CHECK(x) do{checks++;if(!(x)){fprintf(stderr,"line %d\n",__LINE__);return 1;}}while(0)
@interface ReentrantDock:UIView
@property(nonatomic,copy) void(^onAlpha)(void);
@end
@implementation ReentrantDock
-(void)setAlpha:(CGFloat)a{HBCircularSetNativeAlpha(self,a,^(CGFloat adjusted){[super setAlpha:adjusted];if(self.onAlpha)self.onAlpha();});}
@end
int main(){@autoreleasepool{
 UIWindow*w=[[UIWindow alloc]initWithFrame:CGRectMake(0,0,375,812)];UIView*root=[[UIView alloc]initWithFrame:w.bounds];[w addSubview:root];ReentrantDock*d=[[ReentrantDock alloc]initWithFrame:CGRectMake(0,712,375,88)];[root addSubview:d];
 NSMutableArray*rows=[NSMutableArray new];for(int i=0;i<12;i++)[rows addObject:@{@"key":[NSString stringWithFormat:@"demo%d",i],@"title":@"Demo",@"badge":@""}];
 __block int nested=0;__weak ReentrantDock*weak=d;d.onAlpha=^{nested++;ReentrantDock*strong=weak;HBUpdateCircularDock(strong,root,strong.frame,rows,0,YES,nil,nil);};
 for(int mode=0;mode<2;mode++){
 HBCircularSetSwipeMode(d,mode==1);HBUpdateCircularDock(d,root,d.frame,rows,0,YES,nil,nil);CHECK(HBCircularDockActive(d));UIView*ring=HBCircularTestView(d);UIView*plane=[ring valueForKey:@"iconPlane"];UIView*blur=[ring valueForKey:@"backdrop"];
 CHECK(plane.superview==ring&&blur.superview==ring);CHECK(plane.layer.zPosition>blur.layer.zPosition);CHECK(plane.subviews.count==12);
 for(int k=0;k<240;k++){HBCircularTestRotate(d,.083,NO,NO);[ring layoutIfNeeded];int visible=0;for(UIView*b in plane.subviews){CHECK(b.superview==plane);CHECK(isfinite(b.center.x)&&isfinite(b.center.y));if(b.alpha>.15&&CGRectIntersectsRect(b.frame,plane.bounds))visible++;}CHECK(visible>=3);}
 HBCircularTestRotate(d,0,YES,NO);d.onAlpha=nil;HBUpdateCircularDock(d,nil,CGRectZero,@[],0,NO,nil,nil);CHECK(!HBCircularDockActive(d)&&d.userInteractionEnabled);CHECK(root.subviews.count==1);
 d.onAlpha=^{nested++;ReentrantDock*strong=weak;HBUpdateCircularDock(strong,root,strong.frame,rows,0,YES,nil,nil);};
 }
 CHECK(nested==2);d.onAlpha=nil;
 // Reject an icon surface within the native Dock instead of hiding its own UI.
 HBUpdateCircularDock(d,d,d.bounds,rows,0,YES,nil,nil);CHECK(!HBCircularDockActive(d));
 printf("{\"checks\":%d,\"reentrantUpdatesBlocked\":true,\"iconsAboveBackdrop\":true,\"multiIconVisibilityPhases\":480,\"actualSpringBoardCrashReproduced\":false}\n",checks);return 0;}}
