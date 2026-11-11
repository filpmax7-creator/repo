#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <unistd.h>
#include <math.h>
#include "capi.h"
static int result(NSString *text,int confidence,NSString *failure){
 NSDictionary *value=@{@"text":text?:@"",@"confidence":@(confidence),@"error":failure?:@""};NSData *data=[NSJSONSerialization dataWithJSONObject:value options:0 error:NULL];
 const uint8_t *bytes=data.bytes;size_t left=data.length;while(left){ssize_t n=write(STDOUT_FILENO,bytes,left);if(n<=0)return 2;bytes+=n;left-=n;}return failure.length?1:0;
}
int main(int argc,char **argv){@autoreleasepool{
 NSString *models=argc>1?@(argv[1]):@"/var/jb/Library/FloatSnap/tessdata";
 // Limit all work to one explicitly selected image, and never use an OCR/network service.
 NSMutableData *input=[NSMutableData new];uint8_t chunk[32768];ssize_t n;
 while((n=read(STDIN_FILENO,chunk,sizeof(chunk)))>0){[input appendBytes:chunk length:n];if(input.length>24*1024*1024)return result(nil,0,@"imageTooLarge");}
 UIImage *image=[UIImage imageWithData:input];if(!image.CGImage)return result(nil,0,@"invalidImage");
 size_t originalW=CGImageGetWidth(image.CGImage),originalH=CGImageGetHeight(image.CGImage);
 if(!originalW||!originalH||originalW>20000||originalH>20000)return result(nil,0,@"imageTooLarge");
 double scale=MIN(3.0,sqrt(4000000.0/((double)originalW*originalH)));size_t width=MAX(1,(size_t)(originalW*scale)),height=MAX(1,(size_t)(originalH*scale));
 uint8_t *pixels=malloc(width*height);if(!pixels)return result(nil,0,@"memory");
 CGColorSpaceRef gray=CGColorSpaceCreateDeviceGray();CGContextRef context=CGBitmapContextCreate(pixels,width,height,8,width,gray,kCGImageAlphaNone);CGColorSpaceRelease(gray);
 if(!context){free(pixels);return result(nil,0,@"bitmap");}
 CGContextSetGrayFillColor(context,1,1);CGContextFillRect(context,CGRectMake(0,0,width,height));CGContextSetInterpolationQuality(context,kCGInterpolationHigh);CGContextDrawImage(context,CGRectMake(0,0,width,height),image.CGImage);CGContextRelease(context);
 // Invert dark screenshots only when the majority of the outer border is dark.
 size_t dark = 0, total = 0;
 for (size_t x = 0; x < width; x++) {
  dark += (pixels[x] < 100) + (pixels[(height - 1) * width + x] < 100);
  total += 2;
 }
 for (size_t y = 0; y < height; y++) {
  dark += (pixels[y * width] < 100) + (pixels[y * width + width - 1] < 100);
  total += 2;
 }
 if (dark * 4 > total * 3) {
  for (size_t i = 0; i < width * height; i++) pixels[i] = 255 - pixels[i];
 }
 TessBaseAPI *api=TessBaseAPICreate();if(!api){free(pixels);return result(nil,0,@"engine");}
 if(TessBaseAPIInit3(api,models.fileSystemRepresentation,"ara+eng")!=0){TessBaseAPIDelete(api);free(pixels);return result(nil,0,@"models");}
 TessBaseAPISetPageSegMode(api, PSM_SINGLE_BLOCK);
 TessBaseAPISetImage(api, pixels, (int)width, (int)height, 1, (int)width);
 TessBaseAPISetSourceResolution(api, 300);
 double start = NSProcessInfo.processInfo.systemUptime;
 ETEXT_DESC *monitor = TessMonitorCreate();
 TessMonitorSetDeadlineMSecs(monitor, 9000);
 int status = TessBaseAPIRecognize(api, monitor);
 TessMonitorDelete(monitor);
 char *utf8 = status == 0 ? TessBaseAPIGetUTF8Text(api) : NULL;
 NSString *text = utf8 ? [[NSString alloc] initWithUTF8String:utf8] : @"";
 int confidence = status == 0 ? TessBaseAPIMeanTextConf(api) : 0;
 if (utf8) TessDeleteText(utf8);

 // A sparse or irregular crop may need automatic page segmentation. Preserve
 // the established single-block result unless the second pass improves it.
 double remaining = 12 - (NSProcessInfo.processInfo.systemUptime - start);
 if (remaining > 1 && (confidence < 60 || !text.length)) {
  TessBaseAPISetPageSegMode(api, PSM_AUTO);
  TessBaseAPISetImage(api, pixels, (int)width, (int)height, 1, (int)width);
  TessBaseAPISetSourceResolution(api, 300);
  monitor = TessMonitorCreate();
  TessMonitorSetDeadlineMSecs(monitor, (int)(remaining * 1000));
  if (TessBaseAPIRecognize(api, monitor) == 0) {
   utf8 = TessBaseAPIGetUTF8Text(api);
   NSString *alternate = utf8 ? [[NSString alloc] initWithUTF8String:utf8] : @"";
   int alternateConfidence = TessBaseAPIMeanTextConf(api);
   if (alternate.length && (!text.length || alternateConfidence > confidence + 5)) {
    text = alternate;
    confidence = alternateConfidence;
    status = 0;
   }
   if (utf8) TessDeleteText(utf8);
  }
  TessMonitorDelete(monitor);
 }
 TessBaseAPIEnd(api);
 TessBaseAPIDelete(api);
 free(pixels);
 return result([text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet],
               confidence, status == 0 ? nil : @"recognition");
}}
