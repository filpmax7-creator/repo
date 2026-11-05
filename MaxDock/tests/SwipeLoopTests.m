#import <UIKit/UIKit.h>
#import "../HBCircularDock.h"
#import <math.h>
static int checks=0;
#define CHECK(x) do{checks++;if(!(x)){fprintf(stderr,"line %d\n",__LINE__);return 1;}}while(0)
@interface SwipeFakeDock:UIView @end
@implementation SwipeFakeDock
-(void)setAlpha:(CGFloat)alpha{HBCircularSetNativeAlpha(self,alpha,^(CGFloat adjusted){[super setAlpha:adjusted];});}
@end
int main(){@autoreleasepool{
 CHECK(!HBSwipeGeometry(0,0,CGSizeMake(351,72),1).count);CHECK(!HBSwipeGeometry(101,0,CGSizeMake(351,72),1).count);CHECK(!HBSwipeGeometry(5,0,CGSizeMake(NAN,72),1).count);
 for(NSNumber*n in @[@1,@2,@4,@6,@12,@40,@100])for(NSNumber*p in @[@0,@.4,@-1.3,@1000000]){
  NSUInteger count=n.unsignedIntegerValue;NSArray*a=HBSwipeGeometry(count,p.doubleValue,CGSizeMake(351,72),1),*b=HBSwipeGeometry(count,p.doubleValue+2*M_PI,CGSizeMake(351,72),1);CHECK(a.count==count);int selected=0;
  for(NSUInteger i=0;i<count;i++){NSDictionary*g=a[i];CHECK(fabs([g[@"y"]doubleValue]-36)<.001);CHECK(isfinite([g[@"x"]doubleValue]));CHECK([g[@"size"]doubleValue]>=0&&[g[@"size"]doubleValue]<=48);CHECK([g[@"alpha"]doubleValue]>=0&&[g[@"alpha"]doubleValue]<=1);CHECK(fabs([g[@"x"]doubleValue]-[b[i][@"x"]doubleValue])<.001);selected+=[g[@"selected"]boolValue];}CHECK(selected==1);
 }
 for(NSUInteger count=2;count<=5;count++){NSArray*edge=HBSwipeGeometry(count,M_PI,CGSizeMake(351,72),1);CHECK([edge[0][@"alpha"]doubleValue]<.001);}CHECK(fabs([HBSwipeGeometry(1,2.2,CGSizeMake(351,72),1)[0][@"x"]doubleValue]-175.5)<.001);
 NSArray*a=HBSwipeGeometry(12,0,CGSizeMake(351,72),1),*b=HBSwipeGeometry(12,.2,CGSizeMake(351,72),1);CHECK([b[0][@"x"]doubleValue]>[a[0][@"x"]doubleValue]);CHECK([a[0][@"size"]doubleValue]>[a[1][@"size"]doubleValue]);CHECK([a[0][@"tilt"]doubleValue]==0);CHECK([a[1][@"tilt"]doubleValue]>0);
 UIWindow*w=[[UIWindow alloc]initWithFrame:CGRectMake(0,0,375,812)];UIView*root=[[UIView alloc]initWithFrame:w.bounds];[w addSubview:root];SwipeFakeDock*d=[[SwipeFakeDock alloc]initWithFrame:CGRectMake(0,712,375,88)];[root addSubview:d];d.alpha=.8;NSMutableArray*rows=[NSMutableArray new];for(int i=0;i<12;i++)[rows addObject:@{@"key":[NSString stringWithFormat:@"synthetic%d",i],@"title":@"Demo",@"badge":@""}];__block CGFloat saved=0;__block int saves=0;
 HBCircularSetSwipeMode(d,YES);HBUpdateCircularDock(d,root,d.frame,rows,0,YES,nil,^(CGFloat value){saved=value;saves++;});CHECK(HBCircularDockActive(d));UIView*view=HBCircularTestView(d);[view layoutIfNeeded];CHECK(view.clipsToBounds&&view.bounds.size.height<=88);CHECK(CGRectContainsRect(root.bounds,view.frame));CHECK(!d.userInteractionEnabled&&d.alpha==0);
 CGFloat previous=0;for(int i=0;i<80;i++){HBCircularTestRotate(d,.23,YES,NO);CHECK(isfinite(saved));CHECK(fabs(remainder(saved-previous,2*M_PI)-.23)<.001);previous=saved;}CHECK(saves==80);
 HBCircularTestRotate(d,.21,NO,YES);CHECK(saves==80);CHECK(fabs([[view valueForKey:@"phase"]doubleValue]-previous)<.001);
 HBCircularSetSwipeMode(d,NO);CHECK(!HBCircularDockActive(d));CHECK(fabs(d.alpha-.8)<.001&&d.userInteractionEnabled);HBUpdateCircularDock(d,root,d.frame,rows,0,YES,nil,nil);CHECK(HBCircularDockActive(d));view=HBCircularTestView(d);CHECK(![[view valueForKey:@"swipeMode"]boolValue]);HBUpdateCircularDock(d,nil,CGRectZero,@[],0,NO,nil,nil);CHECK(!HBCircularDockActive(d));
 printf("{\"checks\":%d,\"endlessWrapVerified\":true,\"noEndpointSnapInSwipeMode\":true,\"normalCircularPreserved\":true,\"windowShown\":false,\"realAppsMoved\":false}\n",checks);return 0;}}
