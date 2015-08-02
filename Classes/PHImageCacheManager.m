//
//  PHImageCacheManager.m
//  PHImageView 2.0
//
//  Created by Sergey Plotkin on 16.07.12.
//  Copyright (c) 2012 ITM House. All rights reserved.
//

#import "PHImageCacheManager.h"
#import "PHImageObject.h"
#import "PHImageOperation.h"
#import "PHImageCacheParams.h"

#import "ProjectHelpers.h"

static const NSInteger kDefaultMaxMemoryCacheElements = 50;
static const CGFloat kDefaultMaxDiskCacheSize = 15.0;


@interface PHImageCacheManager ()

@property (nonatomic, strong) NSMutableArray *diskImageCache;
@property (nonatomic, strong) NSMutableArray *memoryImageCache;

@property (nonatomic, assign) NSInteger currentDiskCacheSize;
@property (nonatomic, copy) NSString *diskCachePath;

@property (nonatomic, strong) NSMutableDictionary *downloadingImages;

@end

@implementation PHImageCacheManager

#pragma mark - Initialization

+ (PHImageCacheManager *)sharedManager{
    static PHImageCacheManager* _instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (id)init {
    self = [super init];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)initialize {
    _operationQueue = [[NSOperationQueue alloc] init];
    _maxMemoryCacheElements = kDefaultMaxMemoryCacheElements;
    _maxDiskCacheSize = 1024 * 1024 * kDefaultMaxDiskCacheSize;
    [self setMaxConcurrentImageOperations:5];
    
    // Setup native iOS HTTP Caching
    NSURLCache *urlCache = [[NSURLCache alloc] initWithMemoryCapacity:1024*1024*1 diskCapacity:1024*1024*4 diskPath:nil];
    [NSURLCache setSharedURLCache:urlCache];
    
    [self loadCache];
}

- (void)loadCache {
    // Creating folder for cache
    NSFileManager *fileManager = [NSFileManager defaultManager];
    self.diskCachePath = [[UIApplication cachesDirectory] stringByAppendingPathComponent:@"Constant"];
    
    NSError *error = nil;
    if (![fileManager createDirectoryAtPath:self.diskCachePath withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Caching is unavailable: %@!",error.localizedDescription);
        return;
    }
    
    // Getting contents of cache directory
    NSArray *directoryFiles = [fileManager contentsOfDirectoryAtPath:self.diskCachePath error:&error];
    if (error != nil) {
        NSLog(@"Error accessing disk cache directory: %@",error.localizedDescription);
        return;
    }
    
    self.memoryImageCache = [[NSMutableArray alloc] initWithCapacity:self.maxMemoryCacheElements];
    self.diskImageCache = [[NSMutableArray alloc] initWithCapacity:directoryFiles.count];
    self.currentDiskCacheSize = 0;
    
    // Initialize disk cache from cache folder
    for (NSString *fileName in directoryFiles) {
        PHImageObject *pObj = [PHImageObject imageObjectWithName:fileName size:[self getFileSize:[self.diskCachePath stringByAppendingPathComponent:fileName]]];
        self.currentDiskCacheSize += pObj.size;
        [self.diskImageCache addObject:pObj];
    }
    
    // Creating an array of active ImageViews (which is downloading images)
    self.downloadingImages = [NSMutableDictionary dictionary];
}

#pragma mark - Properties

- (void)setMaxConcurrentImageOperations:(NSInteger)maxConcurrentImageOperations {
    self.operationQueue.maxConcurrentOperationCount = maxConcurrentImageOperations;
}

- (NSInteger)maxConcurrentImageOperations {
    return self.operationQueue.maxConcurrentOperationCount;
}

#pragma mark - Public direct getting images methods

- (UIImage *)getImageFromCache:(NSURL *)imageUrl {
    NSString *imageName = [imageUrl.absoluteString md5];
    UIImage *image = nil;
    image = [self getImageFromMemoryCache:imageName];
    if (image == nil) {
        image = [self getImageFromDiskCache:imageName params:[PHImageCacheParams cacheParams]];
    }
    return image;
}

- (void)getImageOrDownload:(NSURL *)imageUrl shouldSaveToCache:(BOOL)shouldSave completion:(PHImageCacheCompletionBlock)completion {
    PHImageCacheParams *params = [PHImageCacheParams cacheParamsWithShouldSaveToDiskCache:shouldSave];
    params.fetchFromDiskInForeground = YES;
    [self getImage:imageUrl params:params completion:completion progress:nil];
}

- (void)getImage:(NSURL *)imageUrl params:(PHImageCacheParams *)params completion:(PHImageCacheCompletionBlock)completion progress:(PHImageCacheProgressBlock)progress {
    if (imageUrl == nil)
    {
        return;
    }
    
    NSString *imageName = [imageUrl.absoluteString md5];
    __block UIImage *image = [self getImageFromMemoryCache:imageName];
    if (image) {
        return PERFORM_BLOCK(completion, image, imageName, PHImageCacheSourceTypeMemory, nil);
    } else {
        PERFORM_BLOCK(progress, PHImageCacheGettingTypeNotInMemory);
        dispatch_queue_t workingThread = params.fetchFromDiskInForeground ? dispatch_get_main_queue() : dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        
        dispatch_async(workingThread, ^{
            image = [self getImageFromDiskCache:imageName params:params];
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PERFORM_BLOCK(progress, PHImageCacheGettingTypeOnDisk);
                    PERFORM_BLOCK(completion, image, imageName, PHImageCacheSourceTypeDisk, nil);
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PERFORM_BLOCK(progress, PHImageCacheGettingTypeDownloading);
                });
                
                if ([self shouldDownloadImage:imageName completion:completion]) {
                    [self downloadImage:imageUrl name:imageName params:params completion:completion progress:progress];
                }
            }
        });
    }
}

- (void)getBatchOfImages:(NSArray *)imageUrls params:(PHImageCacheParams *)params completion:(PHImageCacheBatchCompletionBlock)completion {
    if (imageUrls.count < 1) {
        return;
    }
    
    NSMutableArray *operations = [NSMutableArray array];
    NSMutableArray *downloadedImages = [NSMutableArray array];
    
    NSBlockOperation *completionOperation = [NSBlockOperation blockOperationWithBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            PERFORM_BLOCK(completion, downloadedImages.count, downloadedImages, nil);
        });
    }];
    
    for (NSURL *imageUrl in imageUrls) {
        __block UIImage *image = nil;
        NSString *imageName = [imageUrl.absoluteString md5];
        
        image = [self getImageFromMemoryCache:imageName];
        if (image == nil) {
            image = [self getImageFromDiskCache:imageName params:params];
        }
        
        if (image == nil) {
            PHImageOperation *operation = [self operationForImage:imageUrl name:imageName params:params completion:^(UIImage *image, NSString *imageName, PHImageCacheSourceType sourceType, NSError *error) {
                if (image) {
                    @synchronized(downloadedImages) {
                        [downloadedImages addObject:image];
                    }
                }
            } progress:nil];
            [operations addObject:operation];
            [completionOperation addDependency:operation];
        } else {
            [downloadedImages addObject:image];
        }
    }
    
    [self.operationQueue addOperation:completionOperation];
    [self.operationQueue addOperations:operations waitUntilFinished:NO];
}

#pragma mark - Download image operation

- (void)downloadImage:(NSURL *)url name:(NSString *)imageName params:(PHImageCacheParams *)params completion:(PHImageCacheCompletionBlock)completion progress:(PHImageCacheProgressBlock)progressBlock {
    [self.operationQueue addOperation:[self operationForImage:url name:imageName params:params completion:completion progress:progressBlock]];
}

- (PHImageOperation *)operationForImage:(NSURL *)url name:(NSString *)imageName params:(PHImageCacheParams *)params completion:(PHImageCacheCompletionBlock)completion progress:(PHImageCacheProgressBlock)progressBlock {
    PHImageOperation *imageOperation = [PHImageOperation imageOperationWithURL:url completion:^(PHImageOperation *operation) {
        @autoreleasepool {
            if (operation.error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PERFORM_BLOCK(completion, nil, imageName, 0, operation.error);
                });
                [self notifyWaitingImagesFailed:imageName error:operation.error];
            } else {
                NSData *imageData = operation.responseData;
                UIImage *image = [UIImage imageWithData:imageData];
                
                if (operation.params.transformBlock) {
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

- (BOOL)shouldDownloadImage:(NSString *)imageName completion:(PHImageCacheCompletionBlock)completion {
    BOOL shouldDownload = NO;
    @synchronized(self.downloadingImages) {
        shouldDownload = ![self.downloadingImages objectForKey:imageName];
        if (shouldDownload) {
            [self addToDownloadingImages:imageName objectCompletion:nil];
        } else {
            [self addToDownloadingImages:imageName objectCompletion:completion];
        }
    }
    return shouldDownload;
}

- (UIImage *)getImageFromMemoryCache:(NSString *)imageName {
    PHImageObject* photoObj = [self findObjectByKey:imageName inArray:self.memoryImageCache];
    if (photoObj != nil) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void) {
            [self moveAtTheBottomElement:photoObj inArray:self.memoryImageCache];
            
            if (photoObj.onDiskCache) {
                [self moveAtTheBottomElement:photoObj inArray:self.diskImageCache];
            }
        });
        return photoObj.image;
    } else {
        return nil;
    }
}

- (UIImage *)getImageFromDiskCache:(NSString *)imageName params:(PHImageCacheParams *)params {
    PHImageObject *imageObject = [self findObjectByKey:imageName inArray:self.diskImageCache];
    if (imageObject) {
        // Load image from disk in memory (adding to cache)
        NSString *imagePath = [self.diskCachePath stringByAppendingPathComponent:imageName];
        UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfFile:imagePath]];

        // Adding image to memory cache (async)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            imageObject.image = image;
            imageObject.temperaly = params.isTemperaly;
            [self addImageToMemoryCache:imageObject];
            [self moveAtTheBottomElement:imageObject inArray:self.diskImageCache];
        });
        
        return image;
    }
    return nil;
}

#pragma mark - Memory Cache

- (void)addImageToMemoryCache:(PHImageObject *)photoObject {
    @synchronized(self.memoryImageCache) {
        [self.memoryImageCache addObject:photoObject];
    }
    
    // Check if we need garbage collect of memory cache
    if (self.memoryImageCache.count >= self.maxMemoryCacheElements) {
        @synchronized (self) {
            // Start garbage collecting
            [self clearTemperalyImagesInMemory];
            if (self.memoryImageCache.count >= self.maxMemoryCacheElements) {
                [self clearMemoryCache:0.6];
            }
        }
    }
}

- (void)clearMemoryCache:(CGFloat)percent {
    if (percent > 0.99) {
        [self.memoryImageCache removeAllObjects];
    } else {
        NSLog(@"Starting memory garbage collector.");
        NSInteger index = self.memoryImageCache.count * percent;
        @synchronized(self.memoryImageCache) {
            for (NSInteger i = 0; i < index; i++) {
                [self.memoryImageCache[i] setImage:nil];
            }
            [self.memoryImageCache removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, index)]];
        }
    }
}

- (void)clearTemperalyImagesInMemory {
    @synchronized(self.memoryImageCache) {
        NSMutableArray *imagesToRemove = [[NSMutableArray alloc] init];
        for (NSInteger i = 0; i < self.memoryImageCache.count; i++) {
            if ([self.memoryImageCache[i] temperaly]) {
                [self.memoryImageCache[i] setImage:nil];
                [imagesToRemove addObject:self.memoryImageCache[i]];
            }
        }
        [self.memoryImageCache removeObjectsInArray:imagesToRemove];
    }
}

#pragma mark - Disk Cache

- (void)addImageToDiskCache:(PHImageObject *)photoObj {
    @synchronized(self.diskImageCache) {
        [self.diskImageCache addObject:photoObj];
        self.currentDiskCacheSize += photoObj.size;
    }

    // Check if we need garbage collect of disk cache
    if (self.currentDiskCacheSize > self.maxDiskCacheSize) {
        // Start garbage collecting
        @synchronized(self) {
            [self clearTemperalyImagesOnDisk];
            if (self.currentDiskCacheSize > self.maxDiskCacheSize) {
                [self clearDiskCache:0.5];
            }
        }
    }
}

- (void)saveImage:(UIImage *)image imageData:(NSData *)imageData md5:(NSString *)imageName params:(PHImageCacheParams *)params {
    PHImageObject *imageObject = [[PHImageObject alloc] init];
    imageObject.key = imageName;
    imageObject.image = image;
    imageObject.temperaly = params.isTemperaly;
    [self addImageToMemoryCache:imageObject];
    
    if (params.shouldSaveToDiskCache) {
        NSString *cachePath = [_diskCachePath stringByAppendingPathComponent:imageName];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:cachePath]) {
            // Index file is corrupted if we are here
            NSLog(@"Error. Index file was corrupted.");
            return;
        }
        
        if (![fileManager createFileAtPath:cachePath contents:imageData attributes:nil]) {
            NSLog(@"Failed to create file!");
            return;
        }
        
        NSError *error = nil;
        BOOL success = [[NSURL fileURLWithPath:cachePath] setResourceValue:@YES
                                                                    forKey:NSURLIsExcludedFromBackupKey
                                                                     error:&error];
        if (!success) {
            NSLog(@"Failed to set NOT_BACKUP attribute.");
        }
        
        imageObject.size = [self getFileSize:cachePath];
        imageObject.onDiskCache = YES;
        [self addImageToDiskCache:imageObject];
    }
}

- (void)clearDiskCache:(CGFloat)percent {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (percent > 0.99) {
        [self.diskImageCache removeAllObjects];
        self.currentDiskCacheSize = 0;
        if (![fileManager removeItemAtPath:self.diskCachePath error:nil]) {
            NSLog(@"Error while removing disk image cache.");
            return;
        }
        [self loadCache];
    } else {
        NSLog(@"Starting disk garbage collector.");
        NSInteger index = self.diskImageCache.count * percent;
        @synchronized(self.diskImageCache) {
            for (NSInteger i = 0; i < index; i++) {
                PHImageObject *photoObj = self.diskImageCache[i];
                [fileManager removeItemAtPath:[self.diskCachePath stringByAppendingPathComponent:photoObj.key] error:nil];
                self.currentDiskCacheSize -= photoObj.size;;
            }
            [self.diskImageCache removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, index)]];
        }
    }
}

- (void)clearTemperalyImagesOnDisk {
    @synchronized(self.diskImageCache) {
        NSMutableArray *photosToRemove = [NSMutableArray array];
        for (PHImageObject *photo in self.diskImageCache) {
            if (photo.temperaly) {
                photo.onDiskCache = NO;
                [photosToRemove addObject:photo];
                [[NSFileManager defaultManager] removeItemAtPath:[self.diskCachePath stringByAppendingPathComponent:photo.key] error:nil];
                self.currentDiskCacheSize -= photo.size;;
            }
        }
        [self.diskImageCache removeObjectsInArray:photosToRemove];
    }
}

#pragma mark - Cleaning on exit

- (void)cleanDiskCacheBeforeExit {
    [self clearTemperalyImagesOnDisk];
    
    if (self.currentDiskCacheSize > 0.85 * self.maxDiskCacheSize) {
        [self clearDiskCache:0.3];
    } else {
        if (self.currentDiskCacheSize > 0.75 * self.maxDiskCacheSize) {
            [self clearDiskCache:0.25];
        } else {
            if (self.currentDiskCacheSize > 0.65 * self.maxDiskCacheSize) {
                [self clearDiskCache:0.2];
            } else {
                if (self.currentDiskCacheSize > 0.5 * self.maxDiskCacheSize) {
                    [self clearDiskCache:0.1];
                }
            }
        }
    }
}

#pragma mark - Helper methods

- (NSInteger)getFileSize:(NSString *)fileName {
    return [[[NSFileManager defaultManager] attributesOfItemAtPath:fileName error:nil][NSFileSize] longValue];
}

- (void)moveAtTheBottomElement:(PHImageObject *)imageObject inArray:(NSMutableArray *)array {
    @synchronized(array) {
        // Checking  whether the item is already on top
        if (imageObject == array.lastObject) {
            return;
        }

        [array removeObject:imageObject];
        [array addObject:imageObject];
    }
}

- (PHImageObject *)findObjectByKey:(NSString *)key inArray:(NSArray *)array {
    if (array.count > 0) {
        @synchronized(array) {
            for (PHImageObject *obj in array) {
                if ([obj.key isEqualToString:key]) {
                    return obj;
                }
            }
        }
    }
    return nil;
}

+ (NSInteger)cacheSize {
    NSString *path = [[UIApplication cachesDirectory] stringByAppendingPathComponent:@"Constant"];
    NSArray *filesArray = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:path error:nil];
    NSEnumerator *filesEnumerator = [filesArray objectEnumerator];
    NSString *fileName = nil;
    unsigned long int fileSize = 0;
    
    while (fileName = [filesEnumerator nextObject]) {
        fileSize += [[[NSFileManager defaultManager] attributesOfItemAtPath:[path stringByAppendingPathComponent:fileName] error:nil] fileSize];
    }
    
    return fileSize;
}

#pragma mark - Downloading images methods

- (void)addToDownloadingImages:(NSString *)imageName objectCompletion:(PHImageCacheCompletionBlock)completion {
    if (completion) {
        id object = self.downloadingImages[imageName];
        if (object == [NSNull null]) {
            [self.downloadingImages setObject:[NSMutableArray arrayWithObject:completion] forKey:imageName];
        } else {
            [object addObject:completion];
        }
    } else {
        [self.downloadingImages setObject:[NSNull null] forKey:imageName];
    }
}

- (void)notifyWaitingImagesCompleted:(NSString *)imageName image:(UIImage *)image {
    id object = self.downloadingImages[imageName];
    if (object != [NSNull null]) {
        if ([object count] > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSInteger i = 0; i < [object count]; i++) {
                    PERFORM_BLOCK(((PHImageCacheCompletionBlock)object[i]), image, imageName, PHImageCacheSourceTypeServer, nil);
                }
            });
        }
    }
    
    @synchronized(self.downloadingImages) {
        [self.downloadingImages removeObjectForKey:imageName];
    }
}

- (void)notifyWaitingImagesFailed:(NSString *)imageName error:(NSError *)error {
    id object = self.downloadingImages[imageName];
    if (object != [NSNull null]) {
        if ([object count] > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSInteger i = 0; i < [object count]; i++) {
                    PERFORM_BLOCK(((PHImageCacheCompletionBlock)object[i]), nil, imageName, 0, error);
                }
            });
        }
    }
    
    @synchronized(self.downloadingImages) {
        [self.downloadingImages removeObjectForKey:imageName];
    }
}

@end
