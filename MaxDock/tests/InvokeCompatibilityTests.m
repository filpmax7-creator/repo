#import <UIKit/UIKit.h>
#import "../HBInvokeCompatibility.h"
static int checks=0,calls=0;
#define CHECK(x) do{checks++;if(!(x)){fprintf(stderr,"line %d\n",__LINE__);return 1;}}while(0)
@interface Carrier:NSObject { @public id _glassView; double _scalar; }
-(id)object;-(BOOL)flag;-(CGRect)rect;-(double)number;-(id)withArgument:(id)arg;-(Class)classResult;-(id(^)(void))blockResult;
@end
@implementation Carrier
-(id)object{calls++;return @"image";}-(BOOL)flag{calls++;return YES;}-(CGRect)rect{calls++;return CGRectZero;}-(double)number{calls++;return 2;}-(id)withArgument:(id)arg{calls++;return arg;}-(Class)classResult{calls++;return Carrier.class;}-(id(^)(void))blockResult{calls++;return ^id{return @"no";};}
@end
@interface SubCarrier:Carrier @end
@implementation SubCarrier @end
int main(){@autoreleasepool{Carrier*c=[SubCarrier new];c->_glassView=[UIView new];c->_scalar=5;
 CHECK([HBObjectReturningNoArgument(c,@selector(object)) isEqual:@"image"]);CHECK(HBObjectReturningNoArgument(c,@selector(classResult))==Carrier.class);CHECK(calls==2);
 for(NSString*name in @[@"flag",@"rect",@"number",@"withArgument:",@"blockResult",@"missing"])CHECK(HBObjectReturningNoArgument(c,NSSelectorFromString(name))==nil);CHECK(calls==2);
 CHECK(HBObjectReturningNoArgument(nil,@selector(object))==nil);CHECK(HBObjectIvarValue(c,"_glassView")==c->_glassView);CHECK(HBObjectIvarValue(c,"_scalar")==nil);CHECK(HBObjectIvarValue(c,"missing")==nil);CHECK(HBObjectIvarValue(nil,"_glassView")==nil);
 printf("{\"checks\":%d,\"scalarAndStructCallsRejectedBeforeInvocation\":true,\"inheritedMethodsVerified\":true,\"objectIvarValidated\":true}\n",checks);return 0;}}
