//
//  CJJBlockHook.h
//  CJJBlockHook
//
//  Created by JimmyCJJ on 2020/8/26.
//  Copyright © 2020 CAOJIANJIN. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef CJJBlockHookParamsLog
#define CJJBlockHookParamsLog 1
#endif

@interface CJJBlockHook : NSObject
typedef NS_ENUM(NSUInteger, CJJBlockHookPosition) {
    CJJBlockHookPositionBefore = 0,
    CJJBlockHookPositionAfter,
    CJJBlockHookPositionReplace,
    CJJBlockHookPositionDoNothing
};

/// simple exchange IMP between originBlock && hookBlock
/// @param originBlock implicate origin IMP
/// @param hookBlock implicate hook IMP
+ (void)hookOriginBlock:(id)originBlock hookBlock:(id)hookBlock;

/// simple exchange IMP between originBlock && hookBlock, and printing parameters, just for this originBlock.
/// @param originBlock implicate origin IMP
+ (void)hookPrintParamsOriginBlock:(id)originBlock;

/// simple exchange IMP between originBlock && hookBlock, provide a lot of position.
/// @param originBlock implicate origin IMP
/// @param replaceBlock implicate hook IMP
/// @param position hook block with specified position, see CJJBlockHookPosition
+ (void)hookOriginBlock:(id)originBlock hookBlock:(id)replaceBlock position:(CJJBlockHookPosition)position;

/// simple hook block to print parameters before origin block invoke, for all block.
+ (void)fishHook;

@end

NS_ASSUME_NONNULL_END
