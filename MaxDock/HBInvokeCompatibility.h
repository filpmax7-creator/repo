#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <string.h>
// Never interpret scalar/struct results as Objective-C objects across OS versions.
static inline id HBObjectReturningNoArgument(id object,SEL selector){
 if(!object||!selector)return nil;
 Method method=class_getInstanceMethod(object_getClass(object),selector);
 if(!method||method_getNumberOfArguments(method)!=2)return nil;
 char type[256]={0};method_getReturnType(method,type,sizeof(type));const char*t=type;while(*t&&strchr("rnNoORV",*t))t++;
 if((*t!='@'||t[1]=='?')&&*t!='#')return nil;
 return ((id(*)(id,SEL))objc_msgSend)(object,selector);
}
static inline id HBObjectIvarValue(id object,const char*name){
 if(!object||!name)return nil;Ivar ivar=class_getInstanceVariable(object_getClass(object),name);if(!ivar)return nil;
 const char*t=ivar_getTypeEncoding(ivar);if(!t||*t!='@')return nil;
 return object_getIvar(object,ivar);
}
