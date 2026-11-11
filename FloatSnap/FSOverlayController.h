#import <UIKit/UIKit.h>

@interface FSOverlayController : UIViewController
+ (instancetype)sharedController;
- (void)start;
- (void)performFullScreenshot:(dispatch_block_t)original;
- (NSUInteger)prepareForSystemScreenshot;
- (BOOL)finishSystemScreenshot:(NSUInteger)ticket;
- (BOOL)hasActiveSelection;
- (BOOL)hasSelector;
@end
