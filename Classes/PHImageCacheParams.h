//
//  PHImageCacheParams.h
//  PHImageView 2.0
//
//  Created by Sergey on 14.01.13.
//  Copyright (c) 2013 ITM House. All rights reserved.
//

@import Foundation;
@import UIKit;

typedef UIImage *(^PHImageCacheTransformBlock)(UIImage *image);

@interface PHImageCacheParams : NSObject

@property (nonatomic, assign) BOOL isTemperaly;
@property (nonatomic, assign) BOOL shouldSaveToDiskCache;
@property (nonatomic, assign) BOOL fetchFromDiskInForeground;
@property (nonatomic, copy) PHImageCacheTransformBlock transformBlock;
@property (nonatomic, strong) id argument;

+ (instancetype)cacheParams;
+ (instancetype)cacheParamsWithTemporary:(BOOL)isTemp;
+ (instancetype)cacheParamsWithShouldSaveToDiskCache:(BOOL)shouldSave;

@end
