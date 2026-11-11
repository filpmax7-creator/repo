ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = FloatSnapPrefs
FloatSnapPrefs_FILES = FSRootListController.m
FloatSnapPrefs_CFLAGS = -fobjc-arc
FloatSnapPrefs_FRAMEWORKS = UIKit Foundation
FloatSnapPrefs_PRIVATE_FRAMEWORKS = Preferences
FloatSnapPrefs_INSTALL_PATH = /Library/PreferenceBundles
include $(THEOS_MAKE_PATH)/bundle.mk
