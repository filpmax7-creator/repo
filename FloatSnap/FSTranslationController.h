#import <UIKit/UIKit.h>
@interface FSTranslationController : UIViewController
@property(nonatomic) BOOL startsAutomatically;
@property(nonatomic,strong) UIImage *sourceImage;
@property(nonatomic,copy) void (^imageSaveRequested)(UIImage *image);
- (instancetype)initWithText:(NSString *)text;
@end
