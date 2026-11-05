#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
typedef NS_ENUM(NSInteger,HBNormalMotion){HBMotionClassic,HBMotionScale,HBMotionFan,HBMotionElastic,HBMotionDepth};
#ifdef __cplusplus
extern "C" {
#endif
HBNormalMotion HBNormalMotionFromValue(id value);
CATransform3D HBNormalMotionTransform(CATransform3D base,HBNormalMotion style,CGFloat influence,CGFloat signedDistance,CGFloat relativeScale,CGFloat liftDistance,CGFloat strength,BOOL horizontal);

#ifdef __cplusplus
}
#endif
