ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FloatSnap
FloatSnap_FILES = FSArabicOCR.m Tweak.xm FSCapture.m FSSelectionView.m FSCardView.m FSOverlayController.m FSDiagnostics.m FSPreferences.m FSEditorController.m FSWordSelectionController.m FSTranslationController.m FSImageComposition.m FSMergeController.m FSIcons.m FSLanguagePicker.m
FloatSnap_CFLAGS = -fobjc-arc -Wall -Wextra
FloatSnap_FRAMEWORKS = UIKit Foundation QuartzCore Vision Photos CoreImage

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += preferences
include $(THEOS_MAKE_PATH)/aggregate.mk

# OCR runs in an isolated, bounded worker; its engine is never loaded into SpringBoard.
before-all::
	$(MAKE) -C worker THEOS="$(THEOS)" all
after-stage::
	mkdir -p $(THEOS_STAGING_DIR)/usr/libexec
	cp worker/floatsnap-ocr $(THEOS_STAGING_DIR)/usr/libexec/floatsnap-ocr
	chmod 755 $(THEOS_STAGING_DIR)/usr/libexec/floatsnap-ocr

test-fixes:
	$(MAKE) -C worker all
	/var/jb/usr/bin/clang -fobjc-arc -O1 -target arm64-apple-ios16.0 -isysroot $(THEOS)/sdks/iPhoneOS16.5.sdk -I. tests/FloatSnapTests.m FSSelectionView.m FSIcons.m FSPreferences.m FSDiagnostics.m -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -o .fix-tests
	/var/jb/usr/bin/ldid -S .fix-tests
	./.fix-tests "$(CURDIR)"
	/var/jb/usr/bin/clang -fobjc-arc -O1 -target arm64-apple-ios16.0 -isysroot $(THEOS)/sdks/iPhoneOS16.5.sdk tests/ScreenshotRouteTests.m -framework UIKit -framework Foundation -framework QuartzCore -o .route-tests
	/var/jb/usr/bin/ldid -S .route-tests
	./.route-tests
