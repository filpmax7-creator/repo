#import <UIKit/UIKit.h>

@interface FSSelectionView : UIView
@property(nonatomic, copy) void (^completion)(CGRect selection, CGSize canvas);
@property(nonatomic, copy) void (^cancelled)(void);
@property(nonatomic, copy) void (^actionRequested)(NSString *action, CGRect selection, CGSize canvas);
@property(nonatomic,strong) UIImage *sourceImage;
@property(nonatomic,copy) UIImage * (^sourceImageRequested)(void);
- (BOOL)selectionIsLocked;
- (UIImage *)imageByApplyingMarksToCrop:(UIImage *)crop selection:(CGRect)selection;
- (CGRect)selectedRect;
- (void)restoreSelection:(CGRect)rect;
- (instancetype)initWithFrame:(CGRect)frame;
@end
