//
//  PHImageCacheParams.h
//  CheapTrip
//
//  Created by Sergey on 14.01.13.
//  Copyright (c) 2013 ITM House. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PHImageViewEnums.h"

@interface PHImageCacheParams : NSObject

@property (nonatomic, assign) BOOL isTemperaly;
@property (nonatomic, assign) BOOL shouldSaveToDiskCache;
@property (nonatomic, weak) id transformTarget;
@property (nonatomic, assign) SEL transformSelector;
@property (nonatomic, strong) id argument;

+ (id)cacheParams;
+ (id)cacheParamsWithTemporary:(BOOL)isTemp;

@end
