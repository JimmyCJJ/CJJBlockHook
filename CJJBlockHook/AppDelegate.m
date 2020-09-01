//
//  AppDelegate.m
//  CJJBlockHook
//
//  Created by JimmyCJJ on 2020/8/26.
//  Copyright © 2020 CAOJIANJIN. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [self configureWindow];
    
    return YES;
}



- (void)configureWindow{
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    self.window.rootViewController = [ViewController new];
    [self.window makeKeyAndVisible];
}




@end
