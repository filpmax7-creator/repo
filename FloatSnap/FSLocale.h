#import <Foundation/Foundation.h>

// Follow the device's preferred language. Arabic UI for Arabic, English fallback.
static inline BOOL FSArabicUI(void) {
    NSString *language=[NSLocale preferredLanguages].firstObject ?: @"en";
    return [language.lowercaseString hasPrefix:@"ar"];
}
static inline NSString *FSL(NSString *arabic, NSString *english) {
    return FSArabicUI()?arabic:english;
}
