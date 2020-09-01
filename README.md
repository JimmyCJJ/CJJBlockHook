# CJJBlockHook
让交换block的实现变得前所未有的简单

支持pod
```
pod 'CJJBlockHook'
```

此库诞生缘由？
本意是为了解决以下三道题目，进而把实现的思路以及解决方案分享给大家
>以下题目都针对于任意`void (^)(void)`形式的`block`:
- **1.实现下面的函数，将`block`的实现修改成`NSLog(@"Hello world")`，也就说，在调用完这个函数后调用`block()`时，并不调用原始实现，而是打"`Hello world`"**
```
void HookBlockToPrintHelloWorld(id block){
    
}
```
- **2.实现下面的函数，将`block`的实现修改成打印所有入参，并调用原始实现**
```
//
//比如
//      void(^block)(int a, NSString *b) = ^(int a, NSString *b){
//          NSLog(@"block invoke");
//      }
//      HookBlockToPrintArguments(block);
//      block(123,@"aaa");
//      //这里输出"123, aaa"和"block invoke"
//
void HookBlockToPrintArguments(id block){
    
}
```
- **3.实现下面的函数，使得调用这个函数之后，后面创建的任意`block`都能自动实现第二题的功能**
```
void HookEveryBlockToPrintArguments(void){
    
}
```
