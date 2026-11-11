#import <UIKit/UIKit.h>
// Blocking on a background queue only. Worker process owns OCR memory and is time bounded.
FOUNDATION_EXPORT NSString *FSReadArabicImage(UIImage *image,NSError **error);
