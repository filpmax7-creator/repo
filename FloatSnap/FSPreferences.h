#import <Foundation/Foundation.h>
FOUNDATION_EXPORT BOOL FSPrefBool(NSString *key, BOOL fallback);
FOUNDATION_EXPORT double FSPrefNumber(NSString *key, double fallback, double low, double high);
