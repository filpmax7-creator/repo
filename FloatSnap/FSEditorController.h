#import <UIKit/UIKit.h>
@interface FSEditorController : UIViewController
@property(nonatomic, copy) void (^finished)(UIImage *image);
- (instancetype)initWithImage:(UIImage *)image;
- (void)selectTool:(NSInteger)tool;
@end
