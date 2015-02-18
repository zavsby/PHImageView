//
//  PHImageCacheManager.h
//  OmmatiHelpers
//
//  Created by Sergey on 16.07.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PHPhotoObject.h"
#import "UIApplication+ProjectHelpers.h"
#import "NSString+ProjectHelpers.h"
#import "PHImageViewEnums.h"
#import "PHImageCacheParams.h"
#import "ProjectHelpers-Defs.h"

#define PHImageCacheImageWasDownloadedNotification @"PHImageCacheImgWasDownloadNotification"

@class PHImageView;
@class PHImageOperation;
@class HeapPhotoView;

@interface PHImageCacheManager : NSObject
{
    NSMutableArray *diskImageCache;
    NSInteger currentDiskCacheSize;
    NSMutableArray *memoryImageCache;
    NSMutableSet *activeImageViews;
    NSString *diskCachePath;
    // For former iOS < 5.0 compatibility
    long _priorityForDispatchAsync;
}

@property (nonatomic, assign) NSInteger maxConcurrentImageOperations;
@property (nonatomic, assign) NSInteger maxDiskCacheSize;
@property (nonatomic, assign) NSInteger maxMemoryCacheElements;
@property (nonatomic, readonly) NSOperationQueue *operationQueue;

+ (PHImageCacheManager *)sharedManager;

// Initializing and preparing for cache (do not call it manually)
- (void)loadCache;
// For internal imageView using only
- (UIImage *)getImageForImageView:(PHImageView *)imageView params:(PHImageCacheParams *)params;

//
// Methods for direct getting images
//

// Returns image from cache (disk or memory), if image is not it cache, return NIL
- (UIImage *)getImageFromCache:(NSURL *)imageUrl;
// Returns image from cache (disk or memory), or download it, if it is not in cache (NOT IMPLEMENTED YET)
// Notification: PHImageCacheImageWasDownloadedNotification
//- (UIImage *)getImageOrDownload:(NSURL *)imageUrl shouldSaveToCache:(BOOL)shouldSave;

//
// Cache cleaning methods
//

// Full cleaning of temporary cache in memory
- (void)clearTemperalyImagesInMemory;
// Full cleaning of temporary cache on disk (not recommended to call manually)
- (void)clearTemperalyImagesOnDisk;
// Manual launch of garbage collector for disk cache (if percent==1 then clean all cache)
- (void)clearDiskCache:(float)percent;
// Manual launch of garbage collector for memory cache (if percent==1 then clean all cache)
- (void)clearMemoryCache:(float)percent;
// Method cleans cache before exit from application, it removes temporary cache and clean main cache if needed
- (void)cleanDiskCacheBeforeExit;

// Returns current disk cache size
+ (unsigned long)cacheSize;

@end

