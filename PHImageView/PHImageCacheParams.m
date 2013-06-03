//
//  PHImageCacheParams.m
//  CheapTrip
//
//  Created by Sergey on 14.01.13.
//  Copyright (c) 2013 ITM House. All rights reserved.
//

#import "PHImageCacheParams.h"

@implementation PHImageCacheParams

+ (id)cacheParams
{
    return [[self alloc] init];
}

+ (id)cacheParamsWithImageFormat:(ImageFormat)imageFormat isTemp:(BOOL)isTemp
{
    PHImageCacheParams *params = [[PHImageCacheParams alloc] init];
    params.imageFormat = imageFormat;
    params.isTemperaly = isTemp;
    return params;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _shouldSaveToDiskCache = YES;
        _imageFormat = ImageFormatJPEG;
        _isTemperaly = NO;
    }
    return self;
}

@end
