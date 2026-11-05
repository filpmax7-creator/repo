#import "../HBNormalMotion.h"
#import <math.h>
static int checks=0;
#define CHECK(x) do{checks++;if(!(x)){fprintf(stderr,"line %d\n",__LINE__);return 1;}}while(0)
static BOOL Near(CATransform3D a,CATransform3D b){const CGFloat*x=(void*)&a,*y=(void*)&b;for(int i=0;i<16;i++)if(fabs(x[i]-y[i])>.00001)return NO;return YES;}
int main(){@autoreleasepool{
 CHECK(HBNormalMotionFromValue(nil)==HBMotionClassic);CHECK(HBNormalMotionFromValue(@42)==HBMotionClassic);CHECK(HBNormalMotionFromValue(@"unknown")==HBMotionClassic);
 NSArray*keys=@[@"classic",@"scale",@"fan",@"elastic",@"depth"];for(int i=0;i<5;i++)CHECK(HBNormalMotionFromValue(keys[i])==i);
 CGAffineTransform affine=CGAffineTransformRotate(CGAffineTransformMakeScale(.83,.83),.07);CATransform3D base=CATransform3DMakeAffineTransform(affine);
 for(int orientation=0;orientation<2;orientation++)for(int i=0;i<=100;i++){CGFloat e=i/100.,relative=1+.6*e,lift=-28*e;CGAffineTransform old=CGAffineTransformMakeTranslation(orientation?0:lift,orientation?lift:0);old=CGAffineTransformScale(old,relative,relative);CHECK(Near(HBNormalMotionTransform(base,HBMotionClassic,e,.4,relative,28,1,orientation),CATransform3DMakeAffineTransform(CGAffineTransformConcat(affine,old))));}
 for(int style=0;style<5;style++)for(int orientation=0;orientation<2;orientation++)for(int i=0;i<=100;i++){CGFloat e=i/100.;CATransform3D t=HBNormalMotionTransform(base,style,e,.7,1+.6*e,28,1,orientation);CGFloat*v=(void*)&t;for(int j=0;j<16;j++)CHECK(isfinite(v[j]));CHECK(Near(HBNormalMotionTransform(base,style,e,.7,1+.6*e,28,0,orientation),base));CHECK(Near(HBNormalMotionTransform(base,style,0,.7,1,28,1,orientation),base));}
 CATransform3D scale=HBNormalMotionTransform(CATransform3DIdentity,HBMotionScale,1,.5,1.7,28,1,YES);CHECK(scale.m42==0&&scale.m41==0&&fabs(scale.m11-1.7)<.001);
 CATransform3D left=HBNormalMotionTransform(CATransform3DIdentity,HBMotionFan,.7,-.5,1.4,28,1,YES),right=HBNormalMotionTransform(CATransform3DIdentity,HBMotionFan,.7,.5,1.4,28,1,YES);CHECK(left.m12*right.m12<0);CHECK(left.m41*right.m41<0);
 CATransform3D depth=HBNormalMotionTransform(CATransform3DIdentity,HBMotionDepth,1,0,1.5,28,1,YES);CHECK(depth.m43>0);CHECK(!CATransform3DIsAffine(depth));
 for(int style=0;style<5;style++){CATransform3D t=HBNormalMotionTransform(base,style,NAN,INFINITY,NAN,NAN,NAN,YES);CHECK(Near(t,base));}
 UIView*view=[[UIView alloc]initWithFrame:CGRectMake(0,0,48,48)];view.layer.transform=base;NSValue*snapshot=[NSValue valueWithBytes:&base objCType:@encode(CATransform3D)];for(int i=0;i<100;i++)view.layer.transform=HBNormalMotionTransform(base,HBMotionDepth,.9,.4,1.5,28,1,YES);CATransform3D original;[snapshot getValue:&original size:sizeof(original)];view.layer.transform=original;CHECK(Near(view.layer.transform,base));
 printf("{\"checks\":%d,\"classicFormulaPreserved\":true,\"styles\":5,\"bothOrientations\":true,\"transformRestoreVerified\":true,\"liveDockGestureTested\":false}\n",checks);return 0;}}
