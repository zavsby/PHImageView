//
//  PHImageCacheManager.h
//  PHImageView 2.0
//
//  Created by Sergey Plotkin on 16.07.12.
//  Copyright (c) 2012 ITM House. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "PHImageViewTypes.h"

@class PHImageView;
@class PHImageOperation;
@class PHImageCacheParams;

@interface PHImageCacheManager : NSObject

@property (nonatomic, assign) NSInteger maxConcurrentImageOperations;
@property (nonatomic, assign) NSInteger maxDiskCacheSize;
@property (nonatomic, assign) NSInteger maxMemoryCacheElements;
@property (nonatomic, readonly) NSOperationQueue *operationQueue;

+ (instancetype)sharedManager;

// Initializing and preparing for cache (do not call it manually)
- (void)loadCache;

#pragma mark - Methods for getting images directly

// Returns image from cache (disk or memory), if image is not it cache, return NIL
- (UIImage *)getImageFromCache:(NSURL *)imageUrl;
// Returns image from cache (disk or memory), or download it, if it is not in cache
- (void)getImage:(NSURL *)imageUrl params:(PHImageCacheParams *)params completion:(PHImageCacheCompletionBlock)completion progress:(PHImageCacheProgressBlock)progress;
- (void)getImageOrDownload:(NSURL *)imageUrl shouldSaveToCache:(BOOL)shouldSave completion:(PHImageCacheCompletionBlock)completion;

- (void)saveImage:(UIImage *)image imageData:(NSData *)imageData md5:(NSString *)imageName params:(PHImageCacheParams *)params;

- (void)getBatchOfImages:(NSArray *)imageUrls params:(PHImageCacheParams *)params completion:(PHImageCacheBatchCompletionBlock)completion;

#pragma mark - Removing images from cache

/**
 *  Removes image from memory and disk cache.
 *
 *  @param imageUrl URL of image to remove
 */
- (void)removeImageFromCache:(NSURL *)imageUrl;

#pragma mark - Cache cleaning methods

// Full cleaning of temporary cache in memory
- (void)clearTemperalyImagesInMemory;
// Full cleaning of temporary cache on disk (not recommended to call manually)
- (void)clearTemperalyImagesOnDisk;
// Manual launch of garbage collector for disk cache (if percent==1 then clean all cache)
- (void)clearDiskCache:(CGFloat)percent;
// Manual launch of garbage collector for memory cache (if percent==1 then clean all cache)
- (void)clearMemoryCache:(CGFloat)percent;
// Method cleans cache before exit from application, it removes temporary cache and clean main cache if needed
- (void)cleanDiskCacheBeforeExit;

// Returns current disk cache size
+ (NSInteger)cacheSize;

@end

