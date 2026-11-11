#import "FSImageComposition.h"
#import <math.h>
UIImage *FSMergeImages(NSArray<UIImage *> *images, BOOL horizontal) {
    if (images.count<2 || images.count>5) return nil;
    CGFloat cross=0,total=0;
    for (UIImage *image in images) {
        if (!image.CGImage || image.size.width<=0 || image.size.height<=0) return nil;
        cross=MAX(cross,(horizontal?image.size.height:image.size.width)*image.scale);
    }
    cross=MIN(cross,2048);
    for (UIImage *image in images) total+=cross*(horizontal?image.size.width/image.size.height:image.size.height/image.size.width);
    CGFloat width=horizontal?total:cross,height=horizontal?cross:total;
    CGFloat reduction=MIN(1,MIN(8192/MAX(width,height),sqrt(12000000/(width*height))));
    width=MAX(1,floor(width*reduction)); height=MAX(1,floor(height*reduction)); cross*=reduction;
    UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat]; format.scale=1; format.opaque=YES;
    return [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(width,height) format:format] imageWithActions:^(UIGraphicsImageRendererContext *context) {
        (void)context; [UIColor.whiteColor setFill]; UIRectFill(CGRectMake(0,0,width,height)); CGFloat offset=0;
        for (UIImage *image in images) {
            CGFloat along=cross*(horizontal?image.size.width/image.size.height:image.size.height/image.size.width);
            CGRect rect=horizontal?CGRectMake(offset,0,along,cross):CGRectMake(0,offset,cross,along);
            [image drawInRect:rect]; offset+=along;
        }
    }];
}
UIImage *FSImageWithTranslation(UIImage *image, NSString *text) {
    if (!image.CGImage || !text.length || text.length>20000) return nil;
    CGFloat width=MIN(1600,MAX(600,image.size.width*image.scale)),padding=32;
    CGFloat imageHeight=MIN(4000,width*image.size.height/MAX(1,image.size.width));
    CGFloat fittedWidth=imageHeight*image.size.width/MAX(1,image.size.height);
    NSMutableParagraphStyle *paragraph=[NSMutableParagraphStyle new]; paragraph.alignment=NSTextAlignmentNatural;
    paragraph.baseWritingDirection=NSWritingDirectionNatural; paragraph.lineBreakMode=NSLineBreakByWordWrapping;
    NSDictionary *attributes=@{NSFontAttributeName:[UIFont systemFontOfSize:28],NSForegroundColorAttributeName:UIColor.blackColor,NSParagraphStyleAttributeName:paragraph};
    NSString *caption=[@"الترجمة\n\n" stringByAppendingString:text];
    CGRect bounds=[caption boundingRectWithSize:CGSizeMake(width-padding*2,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:attributes context:nil];
    CGFloat height=imageHeight+padding*2+ceil(bounds.size.height);
    if (height>8192 || width*height>12000000) return nil;
    UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat]; format.scale=1; format.opaque=YES;
    return [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(width,height) format:format] imageWithActions:^(UIGraphicsImageRendererContext *context) {
        (void)context; [UIColor.whiteColor setFill]; UIRectFill(CGRectMake(0,0,width,height));
        [image drawInRect:CGRectMake((width-fittedWidth)/2,0,fittedWidth,imageHeight)];
        [caption drawWithRect:CGRectMake(padding,imageHeight+padding,width-padding*2,ceil(bounds.size.height)) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:attributes context:nil];
    }];
}
