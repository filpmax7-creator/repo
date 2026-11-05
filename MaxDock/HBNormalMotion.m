#import "HBNormalMotion.h"
#import <math.h>
HBNormalMotion HBNormalMotionFromValue(id value){if(![value isKindOfClass:NSString.class])return HBMotionClassic;if([value isEqual:@"scale"])return HBMotionScale;if([value isEqual:@"fan"])return HBMotionFan;if([value isEqual:@"elastic"])return HBMotionElastic;if([value isEqual:@"depth"])return HBMotionDepth;return HBMotionClassic;}
CATransform3D HBNormalMotionTransform(CATransform3D base,HBNormalMotion style,CGFloat influence,CGFloat signedDistance,CGFloat relativeScale,CGFloat liftDistance,CGFloat strength,BOOL horizontal){
 CGFloat e=isfinite(influence)?MAX(0,MIN(1,influence)):0;
 CGFloat side=isfinite(signedDistance)?MAX(-1,MIN(1,signedDistance)):0;
 CGFloat power=isfinite(strength)?MAX(0,MIN(1.5,strength)):1;
 CGFloat scale=isfinite(relativeScale)?MAX(.25,MIN(4,relativeScale)):1;
 CGFloat lift=isfinite(liftDistance)?MAX(0,MIN(120,liftDistance)):0;
 if(e==0||power==0)return base;
 scale=MAX(.25,1+(scale-1)*power);
 CGFloat rise=style==HBMotionScale?0:-lift*e*power;
 CGFloat spread=style==HBMotionFan?side*12*e*power:0;
 if(style==HBMotionElastic)rise*=1.12;
 CGAffineTransform affine=CGAffineTransformMakeTranslation(horizontal?spread:rise,horizontal?rise:spread);
 if(style==HBMotionFan)affine=CGAffineTransformRotate(affine,-side*.45*e*power);
 affine=CGAffineTransformScale(affine,scale,scale);
 if(style!=HBMotionDepth&&CATransform3DIsAffine(base))return CATransform3DMakeAffineTransform(CGAffineTransformConcat(CATransform3DGetAffineTransform(base),affine));
 CATransform3D motion=CATransform3DMakeAffineTransform(affine);
 if(style==HBMotionDepth){motion.m34=-1.0/650;motion=CATransform3DTranslate(motion,0,0,60*e*power);motion=CATransform3DRotate(motion,-side*.5*e*power,horizontal?0:1,horizontal?1:0,0);}
 return CATransform3DConcat(base,motion);
}
