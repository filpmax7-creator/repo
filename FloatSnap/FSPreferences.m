#import "FSPreferences.h"
#import <math.h>
static id FSValue(NSString *key) {
    CFStringRef domain=CFSTR("local.floatsnap.tweak");
    CFPreferencesAppSynchronize(domain);
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,domain));
}
BOOL FSPrefBool(NSString *key, BOOL fallback) {
    id value=FSValue(key); return [value isKindOfClass:NSNumber.class] ? [value boolValue] : fallback;
}
double FSPrefNumber(NSString *key,double fallback,double low,double high) {
    id value=FSValue(key); double number=[value isKindOfClass:NSNumber.class] ? [value doubleValue] : fallback;
    return isfinite(number) ? fmin(high,fmax(low,number)) : fallback;
}
