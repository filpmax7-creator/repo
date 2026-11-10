#pragma once
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static NSString * const HBDiagnosticFile = @"/var/mobile/Documents/MaxDock-Diagnostics.json";

static inline NSNumber *HBDiagnosticNumber(CGFloat value) {
    return @(isfinite(value) ? value : 0);
}

static inline NSArray *HBDiagnosticRect(CGRect r) {
    return @[HBDiagnosticNumber(r.origin.x), HBDiagnosticNumber(r.origin.y),
             HBDiagnosticNumber(r.size.width), HBDiagnosticNumber(r.size.height)];
}

static inline NSArray *HBDiagnosticTransform(CATransform3D t) {
    return @[HBDiagnosticNumber(t.m11), HBDiagnosticNumber(t.m12), HBDiagnosticNumber(t.m13), HBDiagnosticNumber(t.m14),
             HBDiagnosticNumber(t.m21), HBDiagnosticNumber(t.m22), HBDiagnosticNumber(t.m23), HBDiagnosticNumber(t.m24),
             HBDiagnosticNumber(t.m31), HBDiagnosticNumber(t.m32), HBDiagnosticNumber(t.m33), HBDiagnosticNumber(t.m34),
             HBDiagnosticNumber(t.m41), HBDiagnosticNumber(t.m42), HBDiagnosticNumber(t.m43), HBDiagnosticNumber(t.m44)];
}

static inline NSDictionary *HBDiagnosticView(UIView *view) {
    UIWindow *window = view.window;
    if (!view || !window) return @{};
    CALayer *presentation = view.layer.presentationLayer;
    CALayer *windowPresentation = window.layer.presentationLayer;
    CGRect model = [view.layer convertRect:view.layer.bounds toLayer:window.layer];
    CGRect visual = presentation && windowPresentation
        ? [presentation convertRect:presentation.bounds toLayer:windowPresentation] : model;
    return @{
        @"class": NSStringFromClass(view.class), @"bounds": HBDiagnosticRect(view.bounds),
        @"frameInParent": HBDiagnosticRect(view.frame), @"rectInWindow": HBDiagnosticRect([view convertRect:view.bounds toView:window]),
        @"modelRectInWindow": HBDiagnosticRect(model), @"presentationRectInWindow": HBDiagnosticRect(visual),
        @"transform": HBDiagnosticTransform(view.layer.transform),
        @"sublayerTransform": HBDiagnosticTransform(view.layer.sublayerTransform),
        @"alpha": HBDiagnosticNumber(view.alpha), @"hidden": @(view.hidden),
        @"clipsToBounds": @(view.clipsToBounds)
    };
}
