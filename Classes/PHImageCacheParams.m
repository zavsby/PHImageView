//
//  PHImageCacheParams.m
//  PHImageView 2.0
//
//  Created by Sergey on 14.01.13.
//  Copyright (c) 2013 ITM House. All rights reserved.
//

#import "PHImageCacheParams.h"

@implementation PHImageCacheParams

+ (id)cacheParams {
    return [[self alloc] init];
}

+ (id)cacheParamsWithTemporary:(BOOL)isTemp {
    PHImageCacheParams *params = [[PHImageCacheParams alloc] init];
    params.isTemperaly = isTemp;
    return params;
}

+ (id)cacheParamsWithShouldSaveToDiskCache:(BOOL)shouldSave {
    PHImageCacheParams *params = [[PHImageCacheParams alloc] init];
    params.shouldSaveToDiskCache = shouldSave;
    return params;
}

- (id)init {
    self = [super init];
    if (self) {
        _shouldSaveToDiskCache = YES;
        _isTemperaly = NO;
    }
    return self;
}

@end
