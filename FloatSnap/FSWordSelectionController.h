#import <UIKit/UIKit.h>
@interface FSWordSelectionController : UIViewController
@property(nonatomic,copy) void (^textCopyRequested)(NSString *text);
@property(nonatomic,copy) dispatch_block_t closeRequested;
@property(nonatomic,strong) UIImage *sourceImage;
@property(nonatomic,copy) void (^imageSaveRequested)(UIImage *image);
- (instancetype)initWithText:(NSString *)text;
@end
