#import "FSCapture.h"
#import "FSDiagnostics.h"
#import <dlfcn.h>
#import <math.h>
#import "FSPreferences.h"

// Private API declarations are isolated here; never assume they exist on-device.
@interface NSObject (FSLockState)
+ (id)sharedInstance;
- (BOOL)isUILocked;
@end

static NSInteger FSLockState(void) {
    Class cls = NSClassFromString(@"SBLockScreenManager");
    if (![cls respondsToSelector:@selector(sharedInstance)]) {
        static dispatch_once_t once; dispatch_once(&once, ^{ FSLog(@"Lock API missing: SBLockScreenManager.sharedInstance"); });
        return -1;
    }
    id manager = [cls sharedInstance];
    if (![manager respondsToSelector:@selector(isUILocked)]) {
        static dispatch_once_t once; dispatch_once(&once, ^{ FSLog(@"Lock API missing: isUILocked"); });
        return -1;
    }
    return [manager isUILocked];
}

BOOL FSDeviceIsLocked(void) { return FSLockState()!=0; }
BOOL FSCanCaptureVisibleScreen(void) {
    NSInteger state=FSLockState();
    return FSPrefBool(@"Enabled",YES) && (state==0 || (state==1 && FSPrefBool(@"LockScreenEnabled",YES)));
}
UIImage *FSCaptureScreen(NSError **error) {
    NSCAssert([NSThread isMainThread], @"Capture requires the main thread");
    typedef UIImage *(*CaptureFunction)(BOOL);
    static CaptureFunction capture;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        capture = (CaptureFunction)dlsym(RTLD_DEFAULT, "_UICreateScreenUIImageWithRotation");
    });
    UIImage *image = nil;
    NSString *reason = nil;
    if (!FSCanCaptureVisibleScreen()) {
        reason = @"افتح قفل الجهاز أولاً";
    } else if (!capture) {
        reason = @"واجهة الالتقاط غير متاحة على هذا الإصدار";
    } else {
        image = capture(YES);
        if (!image.CGImage) reason = @"تعذّر التقاط الشاشة";
    }
    if (reason) {
        if (error) *error = [NSError errorWithDomain:@"FloatSnap" code:1
            userInfo:@{NSLocalizedDescriptionKey:reason}];
        return nil;
    }
    // Flatten orientation so the selector and pixel crop use the same coordinates.
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = image.scale;
    format.opaque = YES;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:image.size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        (void)context;
        [image drawInRect:(CGRect){CGPointZero, image.size}];
    }];
}

UIImage *FSCropImage(UIImage *image, CGRect selection, CGSize canvas) {
    if (!image.CGImage || canvas.width <= 0 || canvas.height <= 0) return nil;
    if (!isfinite(selection.origin.x) || !isfinite(selection.origin.y) ||
        !isfinite(selection.size.width) || !isfinite(selection.size.height)) return nil;
    CGRect area = CGRectIntersection(CGRectStandardize(selection), (CGRect){CGPointZero, canvas});
    if (CGRectIsNull(area) || CGRectIsEmpty(area)) return nil;
    CGFloat width = CGImageGetWidth(image.CGImage);
    CGFloat height = CGImageGetHeight(image.CGImage);
    CGFloat sx = width / canvas.width, sy = height / canvas.height;
    CGRect pixels = CGRectIntegral(CGRectMake(area.origin.x * sx, area.origin.y * sy,
                                              area.size.width * sx, area.size.height * sy));
    pixels = CGRectIntersection(pixels, CGRectMake(0, 0, width, height));
    CGImageRef crop = CGImageCreateWithImageInRect(image.CGImage, pixels);
    if (!crop) return nil;
    UIImage *result = [UIImage imageWithCGImage:crop scale:image.scale orientation:UIImageOrientationUp];
    CGImageRelease(crop);
    return result;
}
