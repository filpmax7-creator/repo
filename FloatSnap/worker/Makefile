SDK = $(THEOS)/sdks/iPhoneOS16.5.sdk
HEADERS = ../vendor/ios-arm64/libtesseract.framework/Headers
LIBRARY = ../vendor/ios-arm64/libtesseract.framework/libtesseract
ifeq ($(shell uname -s),Darwin)
WORKER_CC = xcrun --sdk iphoneos clang
WORKER_SIGN = ldid
else
WORKER_CC = /var/jb/usr/bin/clang
WORKER_SIGN = /var/jb/usr/bin/ldid
endif
all: floatsnap-ocr
floatsnap-ocr: ../FSOCRWorker.m $(LIBRARY) $(HEADERS)/capi.h $(HEADERS)/platform.h
	$(WORKER_CC) -fobjc-arc -O2 -target arm64-apple-ios16.0 -isysroot $(SDK) -I$(HEADERS) ../FSOCRWorker.m $(LIBRARY) -framework Foundation -framework UIKit -framework CoreGraphics -framework Accelerate -lc++ -lz -liconv -o $@
	$(WORKER_SIGN) -S $@
clean:
	rm -f floatsnap-ocr
