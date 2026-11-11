#import <UIKit/UIKit.h>

@interface FSCardView : UIView
@property(nonatomic, strong, readonly) UIImage *image;
@property(nonatomic, copy) void (^closeRequested)(FSCardView *card);
@property(nonatomic, copy) void (^shareRequested)(FSCardView *card);
@property(nonatomic, copy) void (^saveRequested)(FSCardView *card);
@property(nonatomic, copy) void (^editRequested)(FSCardView *card);
@property(nonatomic,copy) void (^mergeRequested)(FSCardView *card);
- (void)replaceImage:(UIImage *)image;
- (instancetype)initWithImage:(UIImage *)image;
- (void)setPositionPinned:(BOOL)pinned;
- (void)fitInside:(CGRect)area;
@end
