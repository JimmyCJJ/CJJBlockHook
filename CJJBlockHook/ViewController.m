//
//  ViewController.m
//  CJJBlockHook
//
//  Created by JimmyCJJ on 2020/8/26.
//  Copyright © 2020 CAOJIANJIN. All rights reserved.
//

#import "ViewController.h"
#import "CJJBlockHook.h"
#import "fishhook.h"
typedef void (^CommonBlock)(void);

@interface ViewController ()
@property (nonatomic,copy) void (^theBlock)(void);
@end

@implementation ViewController

//>以下题目都针对于任意`void (^)(void)`形式的`block`:
//- **1.实现下面的函数，将`block`的实现修改成`NSL(@"Hello world")`，也就说，在调用完这个函数后调用`block()`时，并不调用原始实现，而是打"`Hello world`"**
//```
void HookBlockToPrintHelloWorld(id block){
    [CJJBlockHook hookOriginBlock:block hookBlock:^{
        NSLog(@"第一题替换后：Hello world");
    }];
}

//```
//- **2.实现下面的函数，将`block`的实现修改成打印所有入参，并调用原始实现**
//```
////
//比如
//      void(^block)(int a, NSString *b) = ^(int a, NSString *b){
//          NSLog(@"block invoke");
//      }
//      HookBlockToPrintArguments(block);
//      block(123,@"aaa");
//      //这里输出"123, aaa"和"block invoke"
//
void HookBlockToPrintArguments(id block){
//    [CJJBlockHook hookOriginBlock:block hookBlock:^{
//        NSLog(@"Hello world");
//    } position:CJJBlockHookPositionDoNothing];
    [CJJBlockHook hookPrintParamsOriginBlock:block];
}

//```
//- **3.实现下面的函数，使得调用这个函数之后，后面创建的任意`block`都能自动实现第二题的功能**
//```
void HookEveryBlockToPrintArguments(void){
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [CJJBlockHook fishHook];
    });
}
//```

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    self.view.backgroundColor = [UIColor greenColor];
    
    //第一题
    void (^originBlock1)(void) = ^{
        NSLog(@"第一题替换前：你好");
    };
    originBlock1();
    HookBlockToPrintHelloWorld(originBlock1);
    originBlock1();
    
    NSLog(@"——————————————————————————————————————");
//    
    //第二题
    void (^originBlock2)(int a, id b, NSString *string) = ^(int a, id b, NSString *string){
        NSLog(@"第二题原实现：%d-%@-%@",a,b,string);
    };
    HookBlockToPrintArguments(originBlock2);
    originBlock2(2,@"笔",@"爱上");
    
    NSLog(@"——————————————————————————————————————");
    
    //第三题
    HookEveryBlockToPrintArguments();
    void (^originBlock3)(NSString *str, int num, CGFloat meter) = ^(NSString *str, int num, CGFloat meter){
        NSLog(@"第三题原实现：%@-%d-%f",str,num,meter);
    };
    originBlock3(@"呵呵",33,4.0);
}

@end
