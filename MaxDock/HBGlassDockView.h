#import <UIKit/UIKit.h>
@interface HBGlassDockView:UIView
@property(nonatomic,readonly) BOOL glassEnabled;
@property(nonatomic,readonly) CGFloat materialOpacity;
- (void)configureGlass:(BOOL)enabled opacity:(CGFloat)opacity;
@end
