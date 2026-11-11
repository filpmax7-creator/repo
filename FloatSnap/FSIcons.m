#import "FSIcons.h"
UIImage *FSIcon(NSString *name) {
    static NSCache<NSString *,UIImage *> *cache;
    static dispatch_once_t once; dispatch_once(&once,^{ cache=[NSCache new]; cache.countLimit=64; });
    UIImage *image=[cache objectForKey:name]; if (image) return image;
    NSString *path=[@"/var/jb/Library/Application Support/FloatSnap/Icons" stringByAppendingPathComponent:[name stringByAppendingString:@"@3x.png"]];
    UIImage *asset=[UIImage imageWithContentsOfFile:path];
    image=asset.CGImage?[[UIImage imageWithCGImage:asset.CGImage scale:3 orientation:UIImageOrientationUp] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]:[UIImage systemImageNamed:name];
    if (image) [cache setObject:image forKey:name]; return image;
}
void FSConfigureIconButton(UIButton *button, NSString *name, NSString *title) {
    UIButtonConfiguration *configuration=[UIButtonConfiguration plainButtonConfiguration];
    configuration.image=FSIcon(name); configuration.imagePlacement=NSDirectionalRectEdgeTop;
    configuration.imagePadding=2; configuration.contentInsets=NSDirectionalEdgeInsetsMake(2,1,2,1);
    configuration.attributedTitle=[[NSAttributedString alloc] initWithString:title attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:10 weight:UIFontWeightSemibold]}];
    button.configuration=configuration; button.accessibilityLabel=title;
}
