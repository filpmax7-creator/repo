#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
// All capture calls run on the main thread in SpringBoard.
FOUNDATION_EXPORT UIImage * _Nullable FSCaptureScreen(NSError **error);
FOUNDATION_EXPORT UIImage * _Nullable FSCropImage(UIImage *image, CGRect selection, CGSize canvas);
FOUNDATION_EXPORT BOOL FSDeviceIsLocked(void);
FOUNDATION_EXPORT BOOL FSCanCaptureVisibleScreen(void);
NS_ASSUME_NONNULL_END
