#import <UIKit/UIKit.h>
@interface FSMergeController : UIViewController
@property(nonatomic,copy) void (^finished)(UIImage *image);
- (instancetype)initWithImages:(NSArray<UIImage *> *)images;
@end
