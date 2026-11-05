#import <UIKit/UIKit.h>
#import "../HBGlassDockView.h"
#import "../HBCircularDock.h"
#import <math.h>
static int checks=0;
#define CHECK(x) do{checks++;if(!(x)){fprintf(stderr,"line %d\n",__LINE__);return 1;}}while(0)
int main(){@autoreleasepool{
 HBGlassDockView*g=[[HBGlassDockView alloc]initWithFrame:CGRectMake(0,0,351,72)];CHECK(!g.userInteractionEnabled&&g.clipsToBounds);CHECK(g.glassEnabled);CHECK(fabs(g.materialOpacity-.55)<.001);
 for(int i=0;i<100;i++){[g configureGlass:i%2 opacity:i%3==0?NAN:(i%3==1?-4:8)];[g layoutIfNeeded];CHECK(g.subviews.count==1);CHECK(g.materialOpacity>=.1&&g.materialOpacity<=1);UIView*m=g.subviews.firstObject;CHECK(CGRectEqualToRect(m.frame,g.bounds));CHECK(g.layer.cornerRadius<=g.bounds.size.height/2);}
 UIWindow*w=[[UIWindow alloc]initWithFrame:CGRectMake(0,0,375,812)];UIView*root=[[UIView alloc]initWithFrame:w.bounds];[w addSubview:root];UIView*d=[[UIView alloc]initWithFrame:CGRectMake(0,712,375,88)];[root addSubview:d];NSArray*rows=@[@{@"key":@"demo",@"title":@"Demo",@"badge":@""}];
 for(int mode=0;mode<2;mode++){HBCircularSetSwipeMode(d,mode);HBUpdateCircularDock(d,root,d.frame,rows,0,YES,nil,nil);UIView*ring=HBCircularTestView(d);HBGlassDockView*glass=[ring valueForKey:@"backdrop"];
 HBCircularSetGlassStyle(d,YES,.3,NO);CHECK(glass.glassEnabled&&!glass.hidden);CHECK(fabs(glass.materialOpacity-.3)<.001);HBCircularSetGlassStyle(d,YES,.7,YES);CHECK(glass.hidden);HBCircularSetGlassStyle(d,NO,.7,NO);CHECK(!glass.glassEnabled&&!glass.hidden);CHECK(!glass.userInteractionEnabled);HBUpdateCircularDock(d,nil,CGRectZero,@[],0,NO,nil,nil);}
 printf("{\"checks\":%d,\"glassModesVerified\":2,\"hideBackgroundHonored\":true,\"realWindowShown\":false}\n",checks);return 0;}}
