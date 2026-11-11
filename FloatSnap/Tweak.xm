#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <stdlib.h>
#import <QuartzCore/QuartzCore.h>
#import "FSCapture.h"
#import "FSPreferences.h"
#import "FSOverlayController.h"
#import "FSDiagnostics.h"

@interface SpringBoard : UIApplication
- (void)applicationDidFinishLaunching:(id)application;
@end

static void (*FSOriginalSpringBoardShot)(id, SEL);
static void (*FSOriginalServiceShot)(id, SEL, id, id, id);
static __thread BOOL FSRunningOriginal = NO;

static CFTimeInterval FSLastPress=0;
static BOOL FSLastPressLocked=NO;
static BOOL FSHasFirstPress=NO;
static BOOL FSFullShotPending=NO;
static void FSRunOriginal(dispatch_block_t original) {
    FSRunningOriginal=YES;
    @try { original(); } @finally { FSRunningOriginal=NO; }
}
static void FSRouteShot(dispatch_block_t original) {
    if (![NSThread isMainThread] || !FSCanCaptureVisibleScreen()) {
        FSRunOriginal(original); return;
    }
    if (FSFullShotPending) return;
    // A new single screenshot always starts a fresh crop, even if the old selector is still visible.
    CFTimeInterval now=CACurrentMediaTime();
    BOOL locked=FSDeviceIsLocked();
    BOOL doublePress=FSHasFirstPress && locked==FSLastPressLocked &&
        now-FSLastPress<=FSPrefNumber(@"DoublePressInterval",0.4,0.2,0.8) &&
        FSPrefBool(@"DoublePressFullScreen",YES);
    FSHasFirstPress=NO;
    if (doublePress) {
        FSLog(@"Double hardware press: full system screenshot");
        FSFullShotPending=YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,700*NSEC_PER_MSEC),dispatch_get_main_queue(), ^{ FSFullShotPending=NO; });
        [[FSOverlayController sharedController] performFullScreenshot:^{ FSRunOriginal(original); }];
        return;
    }
    NSUInteger ticket=[[FSOverlayController sharedController] prepareForSystemScreenshot];
    if (ticket && [[FSOverlayController sharedController] finishSystemScreenshot:ticket]) {
        FSLastPress=CACurrentMediaTime(); FSLastPressLocked=locked; FSHasFirstPress=YES; return;
    }
    FSRunOriginal(original);
}
static void FSSpringBoardShot(id object, SEL command) {
    if (FSRunningOriginal) { FSOriginalSpringBoardShot(object,command); return; }
    FSRouteShot(^{ FSOriginalSpringBoardShot(object,command); });
}
static void FSServiceShot(id object, SEL command, id options, id presentation, id internalOptions) {
    // ScreenshotServices may run asynchronously after SpringBoard returns.
    // Keep that service continuation on the original path during a full shot.
    if (FSRunningOriginal || FSFullShotPending) {
        FSLog(@"Passing system screenshot service continuation through");
        FSOriginalServiceShot(object,command,options,presentation,internalOptions); return;
    }
    FSRouteShot(^{ FSOriginalServiceShot(object,command,options,presentation,internalOptions); });
}
static BOOL FSValidMethod(Class cls, SEL selector, unsigned int arguments) {
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != arguments) return NO;
    char *result = method_copyReturnType(method);
    BOOL valid = result && result[0] == 'v';
    free(result);
    for (unsigned int index = 2; valid && index < arguments; index++) {
        char *type = method_copyArgumentType(method, index);
        valid = type && type[0] == '@';
        free(type);
    }
    return valid;
}
static void FSInstallScreenshotHooks(void) {
    // Called on the main queue after launch, including two bounded retries for lazy loading.
    static BOOL installedSpringBoard = NO, installedService = NO;
    Class springBoard = objc_getClass("SpringBoard");
    SEL springSelector = sel_registerName("takeScreenshot");
    if (!installedSpringBoard && FSValidMethod(springBoard, springSelector, 2)) {
        MSHookMessageEx(springBoard, springSelector, (IMP)FSSpringBoardShot, (IMP *)&FSOriginalSpringBoardShot);
        installedSpringBoard = YES;
        FSLog(@"Installed SpringBoard screenshot hook");
    }
    Class service = objc_getClass("SSScreenCapturer");
    SEL serviceSelector = sel_registerName("_preheatAndTakeScreenshotIfPossibleWithOptionsCollection:presentationOptions:appleInternalOptions:");
    if (!installedService && FSValidMethod(service, serviceSelector, 5)) {
        MSHookMessageEx(service, serviceSelector, (IMP)FSServiceShot, (IMP *)&FSOriginalServiceShot);
        installedService = YES;
        FSLog(@"Installed ScreenshotServices hook");
    }
    if (!installedService) FSLog(@"ScreenshotServices class/method not loaded or signature unsupported");
}
static void FSStart(void) {
    NSInteger major=NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
    if (major!=16 && major!=17 && major!=18 && major!=26) { FSLog(@"Unsupported OS family; keeping system screenshot behavior"); return; }
    FSLog([NSString stringWithFormat:@"OS %@; iOS 16 user-tested, other families require device validation",NSProcessInfo.processInfo.operatingSystemVersionString]);
    FSLog(@"Starting overlay and installing activation hooks");
    [[FSOverlayController sharedController] start];
    FSInstallScreenshotHooks();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ FSInstallScreenshotHooks(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ FSInstallScreenshotHooks(); });
}
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{ FSStart(); });
}
%end

%ctor {
    FSLog(@"Loaded FloatSnap 0.9.9.9-alpha");
    %init;
}
