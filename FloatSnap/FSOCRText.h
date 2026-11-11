#pragma once
#import <Foundation/Foundation.h>

static inline BOOL FSArabicLetter(unichar c) {
    return ((c >= 0x0600 && c <= 0x08ff) || (c >= 0xfb50 && c <= 0xfdff) ||
            (c >= 0xfe70 && c <= 0xfefc)) && [NSCharacterSet.letterCharacterSet characterIsMember:c];
}

static inline NSString *FSNormalizeOCRText(NSString *text) {
    if (!text.length) return @"";
    NSMutableString *normalized = [NSMutableString stringWithCapacity:text.length];
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if ((c >= 0xfb50 && c <= 0xfdff) || (c >= 0xfe70 && c <= 0xfefc)) {
            NSString *form = [NSString stringWithCharacters:&c length:1];
            [normalized appendString:form.precomposedStringWithCompatibilityMapping];
        } else {
            [normalized appendString:[text substringWithRange:NSMakeRange(i, 1)]];
        }
    }
    return [normalized.precomposedStringWithCanonicalMapping
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static inline BOOL FSArabicReadingDirection(NSString *text) {
    NSUInteger arabic = 0, other = 0;
    NSCharacterSet *letters = NSCharacterSet.letterCharacterSet;
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (FSArabicLetter(c)) arabic++;
        else if ([letters characterIsMember:c]) other++;
    }
    return arabic > 0 && arabic >= other;
}
