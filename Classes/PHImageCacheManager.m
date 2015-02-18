//
//  PHImageCacheManager.m
//  PHImageView 2.0
//
//  Created by Sergey Plotkin on 16.07.12.
//  Copyright (c) 2012 ITM House. All rights reserved.
//

#import "PHImageCacheManager.h"

@implementation PHImageCacheManager

#pragma mark - Initialization

+ (PHImageCacheManager *)sharedManager
{
    static PHImageCacheManager* _instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        [self initialize];
    }
    return self;
}

- (void)initialize
{
    _operationQueue = [[NSOperationQueue alloc] init];
    self.maxConcurrentImageOperations = 5;
    _maxMemoryCacheElements = 50;
    _maxDiskCacheSize = 1024 * 1024 * 15;
    
    // Setup native iOS HTTP Caching
    NSURLCache *urlCache = [[NSURLCache alloc] initWithMemoryCapacity:1024*1024*1 diskCapacity:1024*1024*4 diskPath:nil];
    [NSURLCache setSharedURLCache:urlCache];
    
    [self loadCache];
}

- (void)loadCache
{
    // Creating folder for cache
    NSFileManager *fileManager = [NSFileManager defaultManager];
    _diskCachePath = [[UIApplication cachesDirectory] stringByAppendingPathComponent:@"Constant"];
    NSError *error = nil;
    if (![fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:&error])
    {
        NSLog(@"Caching is unavailable: %@!",error.localizedDescription);
        return;
    }
    
    // Getting contents of cache directory
    NSArray *directoryFiles = [fileManager contentsOfDirectoryAtPath:_diskCachePath error:&error];
    if (error != nil)
    {
        NSLog(@"Error accessing disk cache directory: %@",error.localizedDescription);
        return;
    }
    _memoryImageCache = [[NSMutableArray alloc] initWithCapacity:_maxMemoryCacheElements];
    _diskImageCache = [[NSMutableArray alloc] initWithCapacity:directoryFiles.count];
    _currentDiskCacheSize = 0;
    
    // Initialize disk cache from cache folder
    for (NSString *fileName in directoryFiles)
    {
        PHImageObject *pObj = [PHImageObject imageObjectWithName:fileName size:[self getFileSize:[_diskCachePath stringByAppendingPathComponent:fileName]]];
        _currentDiskCacheSize += pObj.size;
        [_diskImageCache addObject:pObj];
    }
    
    // Creating an array of active ImageViews (which is downloading images)
    _downloadingImages = [NSMutableDictionary dictionary];
}

#pragma mark - Properties

- (void)setMaxConcurrentImageOperations:(NSInteger)maxConcurrentImageOperations
{
    _operationQueue.maxConcurrentOperationCount = maxConcurrentImageOperations;
}

- (NSInteger)maxConcurrentImageOperations
{
    return _operationQueue.maxConcurrentOperationCount;
}

#pragma mark - Public direct getting images methods

- (UIImage *)getImageFromCache:(NSURL *)imageUrl
{
    NSString *imageName = [imageUrl.absoluteString md5];
    UIImage *image = nil;
    image = [self getImageFromMemoryCache:imageName];
    if (image == nil)
    {
        image = [self getImageFromDiskCache:imageName params:[PHImageCacheParams cacheParams]];
    }
    return image;
}

- (void)getImageOrDownload:(NSURL *)imageUrl shouldSaveToCache:(BOOL)shouldSave completion:(PHImageCacheCompletionBlock)completion
{
    PHImageCacheParams *params = [PHImageCacheParams cacheParamsWithShouldSaveToDiskCache:shouldSave];
    params.fetchFromDiskInForeground = YES;
    [self getImage:imageUrl params:params completion:completion progress:nil];
}

- (void)getImage:(NSURL *)imageUrl params:(PHImageCacheParams *)params completion:(PHImageCacheCompletionBlock)completion progress:(PHImageCacheProgressBlock)progress
{
    if (imageUrl == nil)
    {
        return;
    }
    
    NSString *imageName = [imageUrl.absoluteString md5];
    __block UIImage *image = [self getImageFromMemoryCache:imageName];
    if (image)
    {
        return PERFORM_BLOCK(completion, image, imageName, PHImageCacheSourceTypeMemory, nil);
    }
    else
    {
        PERFORM_BLOCK(progress, PHImageCacheGettingTypeNotInMemory);
        dispatch_queue_t workingThread = params.fetchFromDiskInForeground ? dispatch_get_main_queue() : dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        
        dispatch_async(workingThread, ^{
            image = [self getImageFromDiskCache:imageName params:params];
            if (image)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PERFORM_BLOCK(progress, PHImageCacheGettingTypeOnDisk);
                    PERFORM_BLOCK(completion, image, imageName, PHImageCacheSourceTypeDisk, nil);
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PERFORM_BLOCK(progress, PHImageCacheGettingTypeDownloading);
                });
                
                if ([self shouldDownloadImage:imageName completion:completion])
                {
                    [self downloadImage:imageUrl name:imageName params:params completion:completion progress:progress];
                }
            }
        });
    }
}

- (void)getBatchOfImages:(NSArray *)imageUrls params:(PHImageCacheParams *)params completion:(PHImageCacheBatchCompletionBlock)completion
{
    if (imageUrls.count < 1)
    {
        return;
    }
    
    NSMutableArray *operations = [NSMutableArray array];
    NSMutableArray *downloadedImages = [NSMutableArray array];
    
    NSBlockOperation *completionOperation = [NSBlockOperation blockOperationWithBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            PERFORM_BLOCK(completion, downloadedImages.count, downloadedImages, nil);
        });
    }];
    
    for (NSURL *imageUrl in imageUrls)
    {
        __block UIImage *image = nil;
        NSString *imageName = [imageUrl.absoluteString md5];
        image = [self getImageFromMemoryCache:imageName];
        if (image == nil)
        {
            image = [self getImageFromDiskCache:imageName params:params];
        }
        if (image == nil)
        {
            PHImageOperation *operation = [self operationForImage:imageUrl name:imageName params:params completion:^(UIImage *image, NSString *imageName, PHImageCacheSourceType sourceType, NSError *error) {
                if (image)
                {
                    @synchronized(downloadedImages)
                    {
                        [downloadedImages addObject:image];
                    }
                }
            } progress:nil];
            [operations addObject:operation];
            [completionOperation addDependency:operation];
        }
        else
        {
            [downloadedImages addObject:image];
        }
    }
    
    [_operationQueue addOperation:completionOperation];
    [_operationQueue addOperations:operations waitUntilFinished:NO];
}

#pragma mark - Download image operation

- (void)downloadImage:(NSURL *)url name:(NSString *)imageName params:(PHImageCacheParams *)params completion:(PHImageCacheCompletionBlock)completion progress:(PHImageCacheProgressBlock)progressBlock
{
    [_operationQueue addOperation:[self operationForImage:url name:imageName params:params completion:completion progress:progressBlock]];
}

- (PHImageOperation *)operationForImage:(NSURL *)url name:(NSString *)imageName params:(PHImageCacheParams *)params completion:(PHImageCacheCompletionBlock)completion progress:(PHImageCacheProgressBlock)progressBlock
{
    PHImageOperation *imageOperation = [PHImageOperation imageOperationWithURL:url completion:^(PHImageOperation *operation) {
        @autoreleasepool
        {
            if (operation.error)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PERFORM_BLOCK(completion, nil, imageName, 0, operation.error);
                });
                [self notifyWaitingImagesFailed:imageName error:operation.error];
            }
            else
            {
                NSData *imageData = operation.responseData;
                UIImage *image = [UIImage imageWithData:imageData];
                
                if (operation.params.transformBlock)
                {
                    image = operation.params.transformBlock(image);
                    imageData = UIImagePNGRepresentation(image);
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    PERFORM_BLOCK(completion, image, imageName, PHImageCacheSourceTypeServer, nil);
                });
                [self notifyWaitingImagesCompleted:imageName image:image];
                
                [self saveImage:image imageData:imageData md5:imageName params:operation.params];
            }
        }
    }];
    
    imageOperation.params = params;
    
    return imageOperation;
}

#pragma mark - Getting image

- (BOOL)shouldDownloadImage:(NSString *)imageName completion:(PHImageCacheCompletionBlock)completion
{
    BOOL shouldDownload = NO;
    @synchronized(_downloadingImages)
    {
        shouldDownload = ![_downloadingImages objectForKey:imageName];
        if (shouldDownload)
        {
            [self addToDownloadingImages:imageName objectCompletion:nil];
        }
        else
        {
            [self addToDownloadingImages:imageName objectCompletion:completion];
        }
    }
    return shouldDownload;
}

- (UIImage *)getImageFromMemoryCache:(NSString *)imageName
{
    PHImageObject* photoObj = [self findObjectByKey:imageName inArray:_memoryImageCache];
    if (photoObj != nil)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void) {
            [self moveAtTheBottomElement:photoObj inArray:_memoryImageCache];
            
            if (photoObj.onDiskCache)
            {
                [self moveAtTheBottomElement:photoObj inArray:_diskImageCache];
            }
        });
        return photoObj.image;
    }
    else
    {
        return nil;
    }
}

- (UIImage *)getImageFromDiskCache:(NSString *)imageName params:(PHImageCacheParams *)params
{
    PHImageObject *imageObject = [self findObjectByKey:imageName inArray:_diskImageCache];
    if (imageObject)
    {
        // Load image from disk in memory (adding to cache)
        NSString *imagePath = [_diskCachePath stringByAppendingPathComponent:imageName];
        UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfFile:imagePath]];

        // Adding image to memory cache (async)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            imageObject.image = image;
            imageObject.temperaly = params.isTemperaly;
            [self addImageToMemoryCache:imageObject];
            [self moveAtTheBottomElement:imageObject inArray:_diskImageCache];
        });
        
        return image;
    }
    return nil;
}

#pragma mark - Memory Cache

- (void)addImageToMemoryCache:(PHImageObject *)photoObject
{
    @synchronized(_memoryImageCache)
    {
        [_memoryImageCache addObject:photoObject];
    }
    
    // Check if we need garbage collect of memory cache
    if (_memoryImageCache.count >= _maxMemoryCacheElements)
    {
        @synchronized (self)
        {
            // Start garbage collecting
            [self clearTemperalyImagesInMemory];
            if (_memoryImageCache.count >= _maxMemoryCacheElements)
            {
                [self clearMemoryCache:0.6];
            }
        }
    }
}

- (void)clearMemoryCache:(float)percent
{
    if (percent > 0.99)
    {
        [_memoryImageCache removeAllObjects];
    }
    else
    {
        NSLog(@"Starting memory garbage collector.");
        int index = _memoryImageCache.count * percent;
        @synchronized(_memoryImageCache)
        {
            for (int i = 0; i < index; i++)
            {
                [_memoryImageCache[i] setImage:nil];
            }
            [_memoryImageCache removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, index)]];
        }
    }
}

- (void)clearTemperalyImagesInMemory
{
    @synchronized(_memoryImageCache)
    {
        NSMutableArray *imagesToRemove = [[NSMutableArray alloc] init];
        for (int i = 0; i < _memoryImageCache.count; i++)
        {
            if ([_memoryImageCache[i] temperaly] == YES)
            {
                [_memoryImageCache[i] setImage:nil];
                [imagesToRemove addObject:_memoryImageCache[i]];
            }
        }
        [_memoryImageCache removeObjectsInArray:imagesToRemove];
    }
}

#pragma mark - Disk Cache

- (void)addImageToDiskCache:(PHImageObject *)photoObj
{
    @synchronized(_diskImageCache)
    {
        [_diskImageCache addObject:photoObj];
        _currentDiskCacheSize += photoObj.size;
    }

    // Check if we need garbage collect of disk cache
    if (_currentDiskCacheSize > _maxDiskCacheSize)
    {
        // Start garbage collecting
        @synchronized(self)
        {
            [self clearTemperalyImagesOnDisk];
            if (_currentDiskCacheSize > _maxDiskCacheSize)
            {
                [self clearDiskCache:0.5];
            }
        }
    }
}

- (void)saveImage:(UIImage *)image imageData:(NSData *)imageData md5:(NSString *)imageName params:(PHImageCacheParams *)params
{
    PHImageObject *imageObject = [[PHImageObject alloc] init];
    imageObject.key = imageName;
    imageObject.image = image;
    imageObject.temperaly = params.isTemperaly;
    [self addImageToMemoryCache:imageObject];
    
    if (params.shouldSaveToDiskCache)
    {
        NSString *cachePath = [_diskCachePath stringByAppendingPathComponent:imageName];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:cachePath] == YES)
        {
            // Index file is corrupted if we are here
            NSLog(@"Error. Index file was corrupted.");
            return;
        }
        
        if (![fileManager createFileAtPath:cachePath contents:imageData attributes:nil])
        {
            NSLog(@"Failed to create file!");
            return;
        }
        
        NSError *error = nil;
        BOOL success = [[NSURL fileURLWithPath:cachePath] setResourceValue: @YES
                                                                    forKey: NSURLIsExcludedFromBackupKey error: &error];
        if (!success)
        {
            NSLog(@"Failed to set NOT_BACKUP attribute.");
        }
        
        imageObject.size = [self getFileSize:cachePath];
        imageObject.onDiskCache = YES;
        [self addImageToDiskCache:imageObject];
    }
}

- (void)clearDiskCache:(float)percent
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (percent > 0.99)
    {
        [_diskImageCache removeAllObjects];
        _currentDiskCacheSize = 0;
        if (![fileManager removeItemAtPath:_diskCachePath error:nil])
        {
            NSLog(@"Error while removing disk image cache.");
            return;
        }
        [self loadCache];
    }
    else
    {
        NSLog(@"Starting disk garbage collector.");
        int index = _diskImageCache.count * percent;
        @synchronized(_diskImageCache)
        {
            for (int i = 0; i < index; i++)
            {
                PHImageObject *photoObj = _diskImageCache[i];
                [fileManager removeItemAtPath:[_diskCachePath stringByAppendingPathComponent:photoObj.key] error:nil];
                _currentDiskCacheSize -= photoObj.size;;
            }
            [_diskImageCache removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, index)]];
        }
    }
}

- (void)clearTemperalyImagesOnDisk
{
    @synchronized(_diskImageCache)
    {
        NSMutableArray *photosToRemove = [NSMutableArray array];
        for (PHImageObject *photo in _diskImageCache)
        {
            if (photo.temperaly == YES)
            {
                photo.onDiskCache = NO;
                [photosToRemove addObject:photo];
                [[NSFileManager defaultManager] removeItemAtPath:[_diskCachePath stringByAppendingPathComponent:photo.key] error:nil];
                _currentDiskCacheSize -= photo.size;;
            }
        }
        [_diskImageCache removeObjectsInArray:photosToRemove];
    }
}

#pragma mark - Cleaning on exit

- (void)cleanDiskCacheBeforeExit
{
    [self clearTemperalyImagesOnDisk];
    if (_currentDiskCacheSize > 0.85 * _maxDiskCacheSize)
    {
        [self clearDiskCache:0.3];
    }
    else
    {
        if (_currentDiskCacheSize > 0.75 * _maxDiskCacheSize)
        {
            [self clearDiskCache:0.25];
        }
        else
        {
            if (_currentDiskCacheSize > 0.65 * _maxDiskCacheSize)
            {
                [self clearDiskCache:0.2];
            }
            else
            {
                if (_currentDiskCacheSize > 0.5 * _maxDiskCacheSize)
                {
                    [self clearDiskCache:0.1];
                }
            }
        }
    }
}

#pragma mark - Helper methods

- (long)getFileSize:(NSString *)fileName
{
    return [[[NSFileManager defaultManager] attributesOfItemAtPath:fileName error:nil][NSFileSize] longValue];
}

- (void)moveAtTheBottomElement:(PHImageObject *)imageObject inArray:(NSMutableArray *)array
{
    @synchronized(array)
    {
        // Checking  whether the item is already on top
        if (imageObject == array.lastObject)
        {
            return;
        }

        [array removeObject:imageObject];
        [array addObject:imageObject];
    }
}

- (PHImageObject *)findObjectByKey:(NSString *)key inArray:(NSArray *)array
{
    if (array.count > 0)
    {
        @synchronized(array)
        {
            for (PHImageObject *obj in array)
            {
                if ([obj.key isEqualToString:key])
                {
                    return obj;
                }
            }
        }
    }
    return nil;
}

+ (unsigned long)cacheSize
{
    NSString *path = [[UIApplication cachesDirectory] stringByAppendingPathComponent:@"Constant"];
    NSArray *filesArray = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:path error:nil];
    NSEnumerator *filesEnumerator = [filesArray objectEnumerator];
    NSString *fileName = nil;
    unsigned long int fileSize = 0;
    
    while (fileName = [filesEnumerator nextObject])
    {
        fileSize += [[[NSFileManager defaultManager] attributesOfItemAtPath:[path stringByAppendingPathComponent:fileName] error:nil] fileSize];
    }
    
    return fileSize;
}

#pragma mark - Downloading images methods

- (void)addToDownloadingImages:(NSString *)imageName objectCompletion:(PHImageCacheCompletionBlock)completion
{
    if (completion)
    {
        id object = _downloadingImages[imageName];
        if (object == [NSNull null])
        {
            [_downloadingImages setObject:[NSMutableArray arrayWithObject:completion] forKey:imageName];
        }
        else
        {
            [object addObject:completion];
        }
    }
    else
    {
        [_downloadingImages setObject:[NSNull null] forKey:imageName];
    }
}

- (void)notifyWaitingImagesCompleted:(NSString *)imageName image:(UIImage *)image
{
    id object = _downloadingImages[imageName];
    if (object != [NSNull null])
    {
        if ([object count] > 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                for (int i = 0; i < [object count]; i++)
                {
                    PERFORM_BLOCK(((PHImageCacheCompletionBlock)object[i]), image, imageName, PHImageCacheSourceTypeServer, nil);
                }
            });
        }
    }
    
    @synchronized(_downloadingImages)
    {
        [_downloadingImages removeObjectForKey:imageName];
    }
}

- (void)notifyWaitingImagesFailed:(NSString *)imageName error:(NSError *)error
{
    id object = _downloadingImages[imageName];
    if (object != [NSNull null])
    {
        if ([object count] > 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                for (int i = 0; i < [object count]; i++)
                {
                    PERFORM_BLOCK(((PHImageCacheCompletionBlock)object[i]), nil, imageName, 0, error);
                }
            });
        }
    }
    
    @synchronized(_downloadingImages)
    {
        [_downloadingImages removeObjectForKey:imageName];
    }
}

@end
