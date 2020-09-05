//
//  CJJBlockHook.m
//  CJJBlockHook
//
//  Created by JimmyCJJ on 2020/8/26.
//  Copyright © 2020 CAOJIANJIN. All rights reserved.
//

#import "CJJBlockHook.h"

#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <dlfcn.h>
#import "fishhook.h"

@interface NSInvocation (CJJBlockHook)
- (id)cjjHook_argumentAtIndex:(NSUInteger)index;
- (NSArray *)cjjHook_arguments;
@end

typedef void(*BlockCopyFunction)(void *, const void *);
typedef void(*BlockDisposeFunction)(const void *);
typedef void(*BlockInvokeFunction)(void *, ...);

// Values for Block_layout->flags to describe block objects
enum {
    BLOCK_DEALLOCATING =      (0x0001),  // runtime
    BLOCK_REFCOUNT_MASK =     (0xfffe),  // runtime
    BLOCK_NEEDS_FREE =        (1 << 24), // runtime
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25), // compiler
    BLOCK_HAS_CTOR =          (1 << 26), // compiler: helpers have C++ code
    BLOCK_IS_GC =             (1 << 27), // runtime
    BLOCK_IS_GLOBAL =         (1 << 28), // compiler
    BLOCK_USE_STRET =         (1 << 29), // compiler: undefined if !BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE  =    (1 << 30), // compiler
    BLOCK_HAS_EXTENDED_LAYOUT=(1 << 31)  // compiler
};

#define BLOCK_DESCRIPTOR_1 1
struct Block_descriptor_1 {
    uintptr_t reserved;
    uintptr_t size;
};

#define BLOCK_DESCRIPTOR_2 1
struct Block_descriptor_2 {
    // requires BLOCK_HAS_COPY_DISPOSE
    BlockCopyFunction copy;
    BlockDisposeFunction dispose;
};

#define BLOCK_DESCRIPTOR_3 1
struct Block_descriptor_3 {
    // requires BLOCK_HAS_SIGNATURE
    const char *signature;
    const char *layout;     // contents depend on BLOCK_HAS_EXTENDED_LAYOUT
};

struct Block_layout {
    void *isa;
    volatile int32_t flags; // contains ref count
    int32_t reserved;
    BlockInvokeFunction invoke;
    struct Block_descriptor_1 *descriptor;
    // imported variables
};

typedef struct Block_layout *CJJBlockLayout;

#if 0
static struct Block_descriptor_1 * _Block_descriptor_1(struct Block_layout *aBlock)
{
    return aBlock->descriptor;
}
#endif

static struct Block_descriptor_2 * _Block_descriptor_2(struct Block_layout *aBlock)
{
    if (! (aBlock->flags & BLOCK_HAS_COPY_DISPOSE)) return NULL;
    uint8_t *desc = (uint8_t *)aBlock->descriptor;
    desc += sizeof(struct Block_descriptor_1);
    return (struct Block_descriptor_2 *)desc;
}

static struct Block_descriptor_3 * _Block_descriptor_3(struct Block_layout *aBlock)
{
    if (! (aBlock->flags & BLOCK_HAS_SIGNATURE)) return NULL;
    uint8_t *desc = (uint8_t *)aBlock->descriptor;
    desc += sizeof(struct Block_descriptor_1);
    if (aBlock->flags & BLOCK_HAS_COPY_DISPOSE) {
        desc += sizeof(struct Block_descriptor_2);
    }
    return (struct Block_descriptor_3 *)desc;
}

#pragma mark - AssociatedObject

static NSString * const CJJBlockHookKey_Position = @"CJJBlockHookKey_Position";

static void cjjHook_setPosition(CJJBlockLayout originLayout, CJJBlockHookPosition position){
    objc_setAssociatedObject((__bridge id)originLayout, CJJBlockHookKey_Position.UTF8String, @(position), OBJC_ASSOCIATION_ASSIGN);
}

static NSNumber * cjjHook_getPosition(CJJBlockLayout originLayout){
    NSNumber *position = objc_getAssociatedObject((__bridge id)originLayout, CJJBlockHookKey_Position.UTF8String);
    if(!position){
        position = @(CJJBlockHookPositionReplace);
    }
    return position;
}

static NSString * const CJJBlockHookKey_HookBlock = @"CJJBlockHookKey_HookBlock";

static void cjjHook_setHookBlock(CJJBlockLayout originLayout, CJJBlockLayout hookLayout){
    objc_setAssociatedObject((__bridge id)originLayout, CJJBlockHookKey_HookBlock.UTF8String, (__bridge id)hookLayout, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static id cjjHook_getHookBlock(CJJBlockLayout blockLayout){
    return objc_getAssociatedObject((__bridge id)blockLayout, CJJBlockHookKey_HookBlock.UTF8String);
}

static NSString * const CJJBlockHookKey_OriginBlock = @"CJJBlockHookKey_OriginBlock";

static void cjjHook_setOriginBlock(CJJBlockLayout originLayout, CJJBlockLayout originLayoutCopy){
    objc_setAssociatedObject((__bridge id)originLayout, CJJBlockHookKey_OriginBlock.UTF8String, (__bridge id)originLayoutCopy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static id cjjHook_getOriginBlock(CJJBlockLayout blockLayout){
    return objc_getAssociatedObject((__bridge id)blockLayout, CJJBlockHookKey_OriginBlock.UTF8String);
}

#pragma mark - Hook Logic

static BOOL NullStr(NSString *str){
    if (!str) {
        return YES;
    }
    
    if ([str isKindOfClass:[NSNull class]]) {
        return YES;
    }
    
    if (!str.length) {
        return YES;
    }

    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *trimmedStr = [str stringByTrimmingCharactersInSet:set];
    if (!trimmedStr.length) {
        return YES;
    }
    return NO;
}

static void cjjHook_forwardInvocation(id self, SEL _cmd,NSInvocation *anInvocation){
    CJJBlockLayout originLayout = (__bridge void *)anInvocation.target;
    CJJBlockLayout hookLayout = (__bridge void *)cjjHook_getHookBlock(originLayout);
    CJJBlockLayout originCopyLayout = (__bridge void *)cjjHook_getOriginBlock(originLayout);
    
    if(CJJBlockHookParamsLog == 1){
        NSString *paramsString = @"";
        for (int i = 1; i < anInvocation.methodSignature.numberOfArguments; i++) {
            NSString *part = [NSString stringWithFormat:@"%@",[anInvocation cjjHook_argumentAtIndex:i]];
            if(!NullStr(part)){
                if(NullStr(paramsString)){
                    paramsString = [paramsString stringByAppendingString:[NSString stringWithFormat:@"%@",part]];
                }else{
                    paramsString = [paramsString stringByAppendingString:[NSString stringWithFormat:@",%@",part]];
                }
            }
        }
        NSLog(@"%@",paramsString);        
    }
    NSNumber *position = cjjHook_getPosition(originLayout);
    switch (position.integerValue) {
        case CJJBlockHookPositionBefore:
            [anInvocation invokeWithTarget:(__bridge id _Nonnull)hookLayout];
            [anInvocation invokeWithTarget:(__bridge id _Nonnull)originCopyLayout];
            break;
        case CJJBlockHookPositionAfter:
            [anInvocation invokeWithTarget:(__bridge id _Nonnull)originCopyLayout];
            [anInvocation invokeWithTarget:(__bridge id _Nonnull)hookLayout];
            break;
        case CJJBlockHookPositionReplace:
            [anInvocation invokeWithTarget:(__bridge id _Nonnull)hookLayout];
            break;
        case CJJBlockHookPositionDoNothing:
            [anInvocation invokeWithTarget:(__bridge id _Nonnull)originCopyLayout];
            break;
        default:
            NSLog(@"类型错误");
            break;
    }
}

static NSMethodSignature * cjjHook_methodSignatureForSelector(id self, SEL _cmd, SEL aSelector){
    struct Block_descriptor_3 *desc3 = _Block_descriptor_3((__bridge void *)self);
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:desc3->signature];
    return signature;
}

static void cjjHook_hookMethod(SEL originSel, IMP hookIMP){
    Class cls = NSClassFromString(@"NSBlock");
    Method method = class_getInstanceMethod([NSObject class], originSel);
    BOOL success = class_addMethod(cls, originSel, hookIMP, method_getTypeEncoding(method));
    if(!success){
        class_replaceMethod(cls, originSel, hookIMP, method_getTypeEncoding(method));
    }
}

static void cjjHook_hookMsgForwardMethod(){
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cjjHook_hookMethod(@selector(methodSignatureForSelector:), (IMP)cjjHook_methodSignatureForSelector);
        cjjHook_hookMethod(@selector(forwardInvocation:), (IMP)cjjHook_forwardInvocation);
    });
}

static void cjjHook_deepCopy(CJJBlockLayout layout) {
    struct Block_descriptor_2 *desc_2 = _Block_descriptor_2(layout);
    //如果捕获的变量存在对象或者被__block修饰的变量时，在__main_block_desc_0函数内部会增加copy跟dispose函数，copy函数内部会根据修饰类型（weak or strong）对对象进行强引用还是弱引用，当block释放之后会进行dispose函数，release掉修饰对象的引用，如果都没有引用对象，将对象释放

    if (desc_2) {
        CJJBlockLayout newLayout = malloc(layout->descriptor->size);
        if (!newLayout) {
            return;
        }
        memmove(newLayout, layout, layout->descriptor->size);
        newLayout->flags &= ~(BLOCK_REFCOUNT_MASK|BLOCK_DEALLOCATING);
        newLayout->flags |= BLOCK_NEEDS_FREE | 2;  // logical refcount 1
        
        (desc_2->copy)(newLayout, layout);
        cjjHook_setOriginBlock(layout, newLayout);
    } else {
        //FishBind缺陷：以前那种grouph方式没办法拷贝变量
        CJJBlockLayout newLayout = malloc(layout->descriptor->size);
        if (!newLayout) {
            return;
        }
        memmove(newLayout, layout, layout->descriptor->size);
        newLayout->flags &= ~(BLOCK_REFCOUNT_MASK|BLOCK_DEALLOCATING);
        newLayout->flags |= BLOCK_NEEDS_FREE | 2;  // logical refcount 1
        cjjHook_setOriginBlock(layout, newLayout);
    }
}

// code from
// https://github.com/bang590/JSPatch/blob/master/JSPatch/JPEngine.m
// line 975
static IMP cjjHook_getMsgForward(const char *methodTypes) {
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    if (methodTypes[0] == '{') {
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:methodTypes];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }
    }
#endif
    return msgForwardIMP;
}

static void cjjHook_handleBlock(id originBlock){
    //swizzling系统的消息转发方法
    cjjHook_hookMsgForwardMethod();
    
    //拷贝origin block
    CJJBlockLayout layout = (__bridge CJJBlockLayout)originBlock;
    if(!cjjHook_getOriginBlock(layout)){
        //深拷贝一份origin block的副本
        cjjHook_deepCopy(layout);
        //取出签名
        struct Block_descriptor_3 *desc3 = _Block_descriptor_3(layout);
        //指向消息转发函数
        layout->invoke = (void *)cjjHook_getMsgForward(desc3->signature);
    }
}

#pragma mark - fishHook

extern const struct mach_header* _NSGetMachExecuteHeader(void);

//声明统一的block的hook函数，这个函数的定义是用汇编代码来实现，具体实现在blockhook-arm64.s/blockhook-x86_64.s中。
extern void blockhook(void);
extern void blockhook_stret(void);

//这两个全局变量保存可执行程序的代码段+数据段的开始和结束位置。
unsigned long imageTextStart = 0;
unsigned long imageTextEnd = 0;
void initImageTextStartAndEndPos()
{
    imageTextStart = (unsigned long)_NSGetMachExecuteHeader();
#ifdef __LP64__
    const struct segment_command_64 *psegment = getsegbyname("__TEXT");
#else
    const struct segment_command *psegment = getsegbyname("__TEXT");
#endif
    //imageTextEnd  等于代码段和数据段的结尾 + 对应的slide值。
    imageTextEnd = get_end() + imageTextStart - psegment->vmaddr;
}

/**
 替换block对象的默认invoke实现

 @param blockObj block对象
 */
void replaceBlockInvokeFunction(const void *blockObj)
{
    //任何一个block对象都可以转化为一个struct Block_layout结构体。
    struct Block_layout *layout = (struct Block_layout*)blockObj;
    if (layout != NULL && layout->descriptor != NULL)
    {
        //这里只hook一个可执行程序image范围内定义的block代码块。
        //因为imageTextStart和imageTextEnd表示可执行程序的代码范围，因此如果某个block是在可执行程序中被定义
        //那么其invoke函数地址就一定是在(imageTextStart,imageTextEnd)范围内。
        //如果将这个条件语句去除就会hook进程中所有的block对象！
        unsigned long invokePos = (unsigned long)layout->invoke;
        if (invokePos > imageTextStart && invokePos < imageTextEnd)
        {
            //将默认的invoke实现保存到保留字段，将统一的hook函数赋值给invoke成员。
            int32_t BLOCK_USE_STRET = (1 << 29);  //如果模拟器下返回的类型是一个大于16字节的结构体，那么block的第一个参数为返回的指针，而不是block对象。
            void *hookfunc = ((layout->flags & BLOCK_USE_STRET) == BLOCK_USE_STRET) ? blockhook_stret : blockhook;
            if (layout->invoke != hookfunc)
            {
                layout->descriptor->reserved = (uintptr_t)layout->invoke;
                layout->invoke = hookfunc;
                //打印参数
                [CJJBlockHook hookPrintParamsOriginBlock:(__bridge id)layout];
            }
        }
    }
    
}

void * (*old_Block_copy)(const void *aBlock);

void *my_Block_copy(const void *aBlock){
    aBlock = old_Block_copy(aBlock);
    struct Block_layout *block;
    if(!aBlock) return NULL;
    block = (struct Block_layout *)aBlock;
    replaceBlockInvokeFunction(block);
    return (void *)aBlock;
}

//所有block调用前都会执行blockhookLog,这里的实现就是简单的将block对象的函数符号打印出来！
void blockhookLog(void *blockObj)
{
    struct Block_layout *layout = blockObj;
    
    //注意这段代码在线上的程序是无法获取到符号信息的，因为线上的程序中会删除掉所有block实现函数的符号信息。
    Dl_info dlinfo;
    memset(&dlinfo, 0, sizeof(dlinfo));
    if (dladdr((const void *)layout->descriptor->reserved, &dlinfo))
    {
//        NSLog(@"%s be called with block object:%@", dlinfo.dli_sname, blockObj);
        //打印入参
//        [CJJBlockHook hookPrintParamsOriginBlock:(__bridge id)layout];
    }
}

@implementation CJJBlockHook

+ (void)hookOriginBlock:(id)originBlock hookBlock:(id)hookBlock{
    NSParameterAssert(originBlock);
    NSParameterAssert(hookBlock);
    CJJBlockLayout originLayout = (__bridge CJJBlockLayout)originBlock;
    CJJBlockLayout hookLayout = (__bridge CJJBlockLayout)hookBlock;
    BlockInvokeFunction originInvoke = originLayout->invoke;
    BlockInvokeFunction hookInvoke = hookLayout->invoke;
    originLayout->invoke = hookInvoke;
    hookLayout->invoke = originInvoke;
}

+ (void)hookPrintParamsOriginBlock:(id)originBlock{
    [self hookOriginBlock:originBlock hookBlock:^{} position:CJJBlockHookPositionDoNothing];
}

+ (void)hookOriginBlock:(id)originBlock hookBlock:(id)hookBlock position:(CJJBlockHookPosition)position{
    NSParameterAssert(originBlock);
    NSParameterAssert(hookBlock);
    CJJBlockLayout originLayout = (__bridge CJJBlockLayout)originBlock;
    CJJBlockLayout hookLayout = (__bridge CJJBlockLayout)hookBlock;
    cjjHook_setPosition(originLayout, position);
    cjjHook_setHookBlock(originLayout, hookLayout);
    cjjHook_handleBlock(originBlock);
}

+ (void)fishHook{
    //初始化并计算可执行程序代码段和数据段的开始和结束位置。
    initImageTextStartAndEndPos();
    
    struct rebinding rebns[1] = {"_Block_copy",my_Block_copy,(void **)&old_Block_copy};
    rebind_symbols(rebns, 1);
}

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSInvocation (CJJBlockHook)

@implementation NSInvocation (CJJBlockHook)

// Thanks to the ReactiveCocoa team for providing a generic solution for this.
- (id)cjjHook_argumentAtIndex:(NSUInteger)index {
    const char *argType = [self.methodSignature getArgumentTypeAtIndex:index];
    // Skip const type qualifier.
    if (argType[0] == _C_CONST) argType++;

#define WRAP_AND_RETURN(type) do { type val = 0; [self getArgument:&val atIndex:(NSInteger)index]; return @(val); } while (0)
    if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
        __autoreleasing id returnObj;
        [self getArgument:&returnObj atIndex:(NSInteger)index];
        return returnObj;
    }else if (strcmp(argType, "@\"NSString\"") == 0){
        NSString *val = @"";
        [self getArgument:&val atIndex:(NSInteger)index];
        return val;
    } else if (strcmp(argType, @encode(SEL)) == 0) {
        SEL selector = 0;
        [self getArgument:&selector atIndex:(NSInteger)index];
        return NSStringFromSelector(selector);
    } else if (strcmp(argType, @encode(Class)) == 0) {
        __autoreleasing Class theClass = Nil;
        [self getArgument:&theClass atIndex:(NSInteger)index];
        return theClass;
        // Using this list will box the number with the appropriate constructor, instead of the generic NSValue.
    } else if (strcmp(argType, @encode(char)) == 0) {
        WRAP_AND_RETURN(char);
    } else if (strcmp(argType, @encode(int)) == 0) {
        WRAP_AND_RETURN(int);
    } else if (strcmp(argType, @encode(short)) == 0) {
        WRAP_AND_RETURN(short);
    } else if (strcmp(argType, @encode(long)) == 0) {
        WRAP_AND_RETURN(long);
    } else if (strcmp(argType, @encode(long long)) == 0) {
        WRAP_AND_RETURN(long long);
    } else if (strcmp(argType, @encode(unsigned char)) == 0) {
        WRAP_AND_RETURN(unsigned char);
    } else if (strcmp(argType, @encode(unsigned int)) == 0) {
        WRAP_AND_RETURN(unsigned int);
    } else if (strcmp(argType, @encode(unsigned short)) == 0) {
        WRAP_AND_RETURN(unsigned short);
    } else if (strcmp(argType, @encode(unsigned long)) == 0) {
        WRAP_AND_RETURN(unsigned long);
    } else if (strcmp(argType, @encode(unsigned long long)) == 0) {
        WRAP_AND_RETURN(unsigned long long);
    } else if (strcmp(argType, @encode(float)) == 0) {
        WRAP_AND_RETURN(float);
    } else if (strcmp(argType, @encode(double)) == 0) {
        WRAP_AND_RETURN(double);
    } else if (strcmp(argType, @encode(BOOL)) == 0) {
        WRAP_AND_RETURN(BOOL);
    } else if (strcmp(argType, @encode(bool)) == 0) {
        WRAP_AND_RETURN(BOOL);
    } else if (strcmp(argType, @encode(char *)) == 0) {
        WRAP_AND_RETURN(const char *);
    } else if (strcmp(argType, @encode(void (^)(void))) == 0) {
        __unsafe_unretained id block = nil;
        [self getArgument:&block atIndex:(NSInteger)index];
        return [block copy];
    } else {
        NSUInteger valueSize = 0;
        NSGetSizeAndAlignment(argType, &valueSize, NULL);

        unsigned char valueBytes[valueSize];
        [self getArgument:valueBytes atIndex:(NSInteger)index];

        return [NSValue valueWithBytes:valueBytes objCType:argType];
    }
    return nil;
#undef WRAP_AND_RETURN
}

- (NSArray *)cjjHook_arguments {
    NSMutableArray *argumentsArray = [NSMutableArray array];
    for (NSUInteger idx = 1; idx < self.methodSignature.numberOfArguments; idx++) {
        [argumentsArray addObject:[self cjjHook_argumentAtIndex:idx] ?: NSNull.null];
    }
    return [argumentsArray copy];
}

@end
