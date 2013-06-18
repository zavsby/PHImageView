
#import "PHImageCacheManager.h"
#import "PHImageView.h"

#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

@interface PHImageCacheManager ()

- (void)initialize;

- (void)downloadImage:(NSURL *)url md5:(NSString *)imgName params:(PHImageCacheParams *)params;
- (void)imageDownloadFinished:(PHImageOperation *)operation;
- (void)imageDownloadFailed:(PHImageOperation *)operation;

- (void)addImageToMemoryCache:(PHPhotoObject *)photoObject;
- (void)addImageToDiskCache:(PHPhotoObject *)photoObj;

- (long)getFileSize:(NSString *)fileName;
- (void)moveAtTheBottomElement:(PHPhotoObject *)photoObj inArray:(NSMutableArray *)array;
- (PHPhotoObject*)findObjectByKey:(NSString *)key inArray:(NSArray *)array;

@end

@implementation PHImageCacheManager

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

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
    _maxConcurrentImageOperations = 5;
    _maxMemoryCacheElements = 50;
    _maxDiskCacheSize = 1024 * 1024 * 15;
    // For former iOS 4.3 compatibility
    _priorityForDispatchAsync = DISPATCH_QUEUE_PRIORITY_BACKGROUND;
    // Setup native iOS HTTP Caching
    NSURLCache *urlCache = [[NSURLCache alloc] initWithMemoryCapacity:1024*1024*1 diskCapacity:1024*1024*4 diskPath:nil];
    [NSURLCache setSharedURLCache:urlCache];
    
    [self loadCache];
}

- (void)loadCache
{
    // Creating folder for cache
    NSFileManager *fileManager = [NSFileManager defaultManager];
    diskCachePath = [[UIApplication cachesDirectory] stringByAppendingPathComponent:@"Constant"];
    NSError *error = nil;
    if (![fileManager createDirectoryAtPath:diskCachePath withIntermediateDirectories:YES attributes:nil error:&error])
    {
        ALog(@"Caching is unavailable: %@!",error.localizedDescription);
        return;
    }
    // Getting contents of cache directory
    NSArray *directoryFiles = [fileManager contentsOfDirectoryAtPath:diskCachePath error:&error];
    if (error != nil)
    {
        ALog(@"Error accessing disk cache directory: %@",error.localizedDescription);
        return;
    }
    memoryImageCache = [[NSMutableArray alloc] initWithCapacity:50];
    diskImageCache = [[NSMutableArray alloc] initWithCapacity:directoryFiles.count];
    currentDiskCacheSize = 0;
    // Initialize disk cache from cache folder
    for (NSString *file in directoryFiles)
    {
        PHPhotoObject *pObj = [[PHPhotoObject alloc] init];
        pObj.key = file;
        pObj.size = [self getFileSize:[diskCachePath stringByAppendingPathComponent:file]];
        currentDiskCacheSize += pObj.size;
        [diskImageCache addObject:pObj];
    }
    // Creating an array of active ImageViews (which is downloading images)
    activeImageViews = [[NSMutableSet alloc] initWithCapacity:16];
}

#pragma mark - Properties

- (void)setMaxConcurrentImageOperations:(NSInteger)maxConcurrentImageOperations
{
    _maxConcurrentImageOperations = maxConcurrentImageOperations;
    _operationQueue.maxConcurrentOperationCount = maxConcurrentImageOperations;
}

#pragma mark - Public direct getting images methods

- (UIImage *)getImageFromCache:(NSURL *)imageUrl
{
    NSString *imageName = [imageUrl.absoluteString md5];
    UIImage *image = nil;
    image = [self getImageFromMemoryCache:imageName];
    if (image == nil)
    {
        image = [self getImageFromDiskCache:imageName];
    }
    return image;
}

#pragma mark - Download image operation

- (void)downloadImage:(NSURL *)url md5:(NSString *)imgName params:(PHImageCacheParams *)params
{
    PHImageOperation* imageOperation = [[PHImageOperation alloc] initWithImageURL:url];
    imageOperation.delegate = self;
    imageOperation.didFailSelector = @selector(imageDownloadFailed:);
    imageOperation.didFinishSelector = @selector(imageDownloadFinished:);
    imageOperation.params = params;
    [_operationQueue addOperation:imageOperation];
}

-(void)imageDownloadFailed:(PHImageOperation *)operation
{
    NSString* md5 = operation.imageUrl.absoluteString.md5;
    NSMutableSet *waitingImageViews = [NSMutableSet set];
    if (activeImageViews.count > 0)
    {
        @synchronized(activeImageViews)
        {
            for (PHImageView *iv in activeImageViews)
            {
                if ([iv.imageName isEqualToString:md5])
                {
                    [waitingImageViews addObject:iv];
                }
            }
        }
    }
    if (waitingImageViews.count > 0)
    {
        for (PHImageView *imageView in waitingImageViews)
        {
            @synchronized(activeImageViews)
            {
                [activeImageViews removeObject:imageView];
                if (imageView != nil)
                {
                    [imageView performSelectorOnMainThread:@selector(mainThreadLoadImageFailed) withObject:nil waitUntilDone:NO];
                }
            }
        }
    }
}

-(void)imageDownloadFinished:(PHImageOperation *)operation
{
    // Now we should find imageView, which wants this image
    // If we found it, we start async transform (if transform selector not nil)
    // Then we start imageView show method on main thread and remove imageview from activeImageViews
    // And save image async in cache on disk and memory
    // If we didn't find imageView which was needed this image then we just save image
    @autoreleasepool
    {
        UIImage* image = [UIImage imageWithData:operation.responseData];
        NSData *imageData = operation.responseData;
        NSString* md5 = operation.imageUrl.absoluteString.md5;
        SEL transformSelector = operation.params.transformSelector;
        id transformTarget = operation.params.transformTarget;
        
        NSMutableSet *waitingImageViews = [NSMutableSet set];
        if (activeImageViews.count > 0)
        {
            @synchronized(activeImageViews)
            {
                for (PHImageView *iv in activeImageViews)
                {
                    if ([iv.imageName isEqualToString:md5])
                    {
                        [waitingImageViews addObject:iv];
                    }
                }
            }
        }
        
        if ([transformTarget respondsToSelector:transformSelector])
        {

            image = [transformTarget performSelector:transformSelector withObject:image];
            imageData = UIImagePNGRepresentation(image);
        }
        
        if (waitingImageViews.count > 0)
        {
            for (PHImageView *imageView in waitingImageViews)
            {
                @synchronized(activeImageViews)
                {
                    [activeImageViews removeObject:imageView];
                    if (imageView != nil)
                    {
                         [imageView performSelectorOnMainThread:@selector(mainThreadLoadImageActions:) withObject:image waitUntilDone:NO];
                    }
                }
            }
        }
        [self saveImage:image imageData:imageData md5:md5 params:operation.params];
    }
}

#pragma mark - Getting image

- (UIImage *)getImageForImageView:(PHImageView *)imageView params:(PHImageCacheParams *)params
{
    UIImage *imgFromMemory = [self getImageFromMemoryCache:imageView.imageName];
    if (imgFromMemory != nil)
    {
        return imgFromMemory;
    }
    
    // Check if we have image in disk cache (in background thread)
    dispatch_async(dispatch_get_global_queue(_priorityForDispatchAsync, 0), ^(void) {
        NSURL *imgUrl = imageView.imageURL;
        BOOL didFoundInCache = [self getImageFromDiskCache:imageView.imageName params:params imageView:imageView];
        if (!didFoundInCache)
        {
            //NSLog(@"We will download it from server");
            if (imgUrl == imageView.imageURL)
            {
                @synchronized(activeImageViews)
                {
                    [activeImageViews addObject:imageView];
                }
                [self downloadImage:imageView.imageURL md5:imageView.imageName params:params];
            }
        }
    });
    return nil;
}

- (UIImage *)getImageFromMemoryCache:(NSString *)imageName
{
    PHPhotoObject* photoObj = [self findObjectByKey:imageName inArray:memoryImageCache];
    if (photoObj != nil)
    {
        //NSLog(@"Found in memory cache!");
        dispatch_async(dispatch_get_global_queue(_priorityForDispatchAsync, 0), ^(void) {
            [self moveAtTheBottomElement:photoObj inArray:memoryImageCache];
            [self moveAtTheBottomElement:photoObj inArray:diskImageCache];
        });
        return photoObj.image;
    }
    else
    {
        return nil;
    }
}

- (BOOL)getImageFromDiskCache:(NSString *)imageName params:(PHImageCacheParams *)params imageView:(PHImageView *)imageView
{
    PHPhotoObject* photo = [self findObjectByKey:imageName inArray:diskImageCache];
    if (photo != nil)
    {
        //NSLog(@"Found in disk cache!");
        // Load image from disk in memory (adding to cache)
        NSString* filePath = [diskCachePath stringByAppendingPathComponent:imageName];
        UIImage* imgFromCache = [UIImage imageWithData:[NSData dataWithContentsOfFile:filePath]];
        // Here we need to show image in ImageView (in Main Thread)
        [imageView performSelectorOnMainThread:@selector(mainThreadLoadImageActions:) withObject:imgFromCache waitUntilDone:NO];
        // Adding image to memory cache (async)
        photo.image = imgFromCache;
        photo.temperaly = params.isTemperaly;
        [self addImageToMemoryCache:photo];
        [self moveAtTheBottomElement:photo inArray:diskImageCache];
        return YES;
    }
    else
    {
        return NO;
    }
}

- (UIImage *)getImageFromDiskCache:(NSString *)imageName;
{
    PHPhotoObject* photo = [self findObjectByKey:imageName inArray:diskImageCache];
    if (photo != nil)
    {
        NSString* filePath = [diskCachePath stringByAppendingPathComponent:imageName];
        UIImage* imgFromCache = [UIImage imageWithData:[NSData dataWithContentsOfFile:filePath]];
        [self moveAtTheBottomElement:photo inArray:diskImageCache];
        return imgFromCache;
    }
    return nil;
}

#pragma mark - Memory Cache

- (void)addImageToMemoryCache:(PHPhotoObject *)photoObject
{
    @synchronized(memoryImageCache)
    {
        [memoryImageCache addObject:photoObject];
    }
    // Check if we need garbage collect of memory cache
    if (memoryImageCache.count >= _maxMemoryCacheElements)
    {
        @synchronized(self)
        {
            // Start garbage collecting
            [self clearTemperalyImagesInMemory];
            if (memoryImageCache.count >= _maxMemoryCacheElements)
            {
                [self clearMemoryCache:0.6];
            }
        }
    }
}

-(void)clearMemoryCache:(float)percent
{
    if (percent > 0.99)
    {
        [memoryImageCache removeAllObjects];
    }
    else
    {
        ALog(@"Starting memory garbage collector.");
        int index = memoryImageCache.count*percent;
        @synchronized(memoryImageCache)
        {
            for (int i = 0; i < index; i++)
            {
                [[memoryImageCache objectAtIndex:i] setImage:nil];
            }
            [memoryImageCache removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, index)]];
        }
    }
}

#pragma mark - Disk Cache

-(void)addImageToDiskCache:(PHPhotoObject *)photoObj
{
    @synchronized(diskImageCache)
    {
        [diskImageCache addObject:photoObj];
        currentDiskCacheSize += photoObj.size;
    }
    //NSLog(@"currentCacheSize:%d",currentDiskCacheSize);
    // Check if we need garbage collect of disk cache
    if (currentDiskCacheSize > _maxDiskCacheSize)
    {
        // Start garbage collecting
        @synchronized(self)
        {
            [self clearTemperalyImagesOnDisk];
            if (currentDiskCacheSize > _maxDiskCacheSize)
            {
                [self clearDiskCache:0.5];
            }
        }
    }
}

- (void)saveImage:(UIImage *)image imageData:(NSData *)imageData md5:(NSString *)imageName params:(PHImageCacheParams *)params
{
    PHPhotoObject* photoImage = [[PHPhotoObject alloc] init];
    
    if (params.shouldSaveToDiskCache)
    {
        NSString *cachePath = [diskCachePath stringByAppendingPathComponent:imageName];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:cachePath] == YES)
        {
            // Index file is corrupted if we are here
            return;
        }
        if (![fileManager createFileAtPath:cachePath contents:imageData attributes:nil])
        {
            ALog(@"Failed to create file!");
            return;
        }
        
        NSError *error = nil;
        BOOL success = [[NSURL fileURLWithPath:cachePath] setResourceValue: @YES
                                                                    forKey: NSURLIsExcludedFromBackupKey error: &error];
        if (!success)
        {
            ALog(@"Failed to set NOT_BACKUP attribute.");
        }
        
        photoImage.size = [self getFileSize:cachePath];
    }
    
    photoImage.key = imageName;
    photoImage.image = image;
    photoImage.temperaly = params.isTemperaly;
    [self addImageToMemoryCache:photoImage];
    
    if (params.shouldSaveToDiskCache)
    {
        [self addImageToDiskCache:photoImage];
    }
}

-(void)clearDiskCache:(float)percent
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if (percent > 0.99)
    {
        [diskImageCache removeAllObjects];
        currentDiskCacheSize = 0;
        if (![fileManager removeItemAtPath:diskCachePath error:nil])
        {
            ALog(@"Error while removing disk image cache");
            return;
        }
    }
    else
    {
        ALog(@"Starting disk garbage collector.");
        int index = diskImageCache.count * percent;
        @synchronized(diskImageCache)
        {
            for (int i = 0; i < index; i++)
            {
                PHPhotoObject *photoObj = [diskImageCache objectAtIndex:i];
                [fileManager removeItemAtPath:[diskCachePath stringByAppendingPathComponent:photoObj.key] error:nil];
                currentDiskCacheSize -= photoObj.size;;
            }
            [diskImageCache removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, index)]];
        }
    }
}

#pragma mark - Cleaning on exit

// This method could be overridden
-(void)cleanDiskCacheBeforeExit
{
    [self clearTemperalyImagesOnDisk];
    if (currentDiskCacheSize > 0.85 * _maxDiskCacheSize)
    {
        [self clearDiskCache:0.3];
    }
    else
    {
        if (currentDiskCacheSize > 0.75 * _maxDiskCacheSize)
        {
            [self clearDiskCache:0.25];
        }
        else
        {
            if (currentDiskCacheSize > 0.65 * _maxDiskCacheSize)
            {
                [self clearDiskCache:0.2];
            }
            else
            {
                if (currentDiskCacheSize > 0.5 * _maxDiskCacheSize)
                {
                    [self clearDiskCache:0.1];
                }
            }
        }
    }
}

- (void)clearTemperalyImagesInMemory
{
    @synchronized(memoryImageCache)
    {
        NSMutableArray *imagesToRemove = [[NSMutableArray alloc] init];
        for (int i = 0; i < memoryImageCache.count; i++)
        {
            if ([[memoryImageCache objectAtIndex:i] temperaly] == YES)
            {
                [[memoryImageCache objectAtIndex:i] setImage:nil];
                [imagesToRemove addObject:[memoryImageCache objectAtIndex:i]];
                ALog(@"CLEAR!");
            }
        }
        [memoryImageCache removeObjectsInArray:imagesToRemove];
    }
}

- (void)clearTemperalyImagesOnDisk
{
    @synchronized(diskImageCache)
    {
        NSMutableArray *photosToRemove = [NSMutableArray array];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        for (PHPhotoObject *photo in diskImageCache)
        {
            if (photo.temperaly == YES)
            {
                [photosToRemove addObject:photo];
                [fileManager removeItemAtPath:[diskCachePath stringByAppendingPathComponent:photo.key] error:nil];
                currentDiskCacheSize -= photo.size;;
            }
        }
        [diskImageCache removeObjectsInArray:photosToRemove];
    }
}

#pragma mark - Helper methods

- (long)getFileSize:(NSString *)fileName
{
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:fileName error:nil];
    return [[attrs objectForKey:NSFileSize] longValue];
}

- (void)moveAtTheBottomElement:(PHPhotoObject *)photoObj inArray:(NSMutableArray *)array
{
    // checking  whether the item is already on top
    @synchronized(array)
    {
        if (photoObj == [array objectAtIndex:array.count-1])
        {
            return;
        }
        //ALog(@"Moving UP!");
        // Maybe memory managment problems
        [array removeObject:photoObj];
        [array addObject:photoObj];
    }
}

- (PHPhotoObject *)findObjectByKey:(NSString *)key inArray:(NSArray *)array
{
    if (array.count > 0)
    {
        @synchronized(array)
        {
            for (PHPhotoObject *obj in array)
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
    NSString *path = [[[UIApplication sharedApplication] documentsDirectory] stringByAppendingPathComponent:@"Constant"];
    NSArray *filesArray = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:path error:nil];
    NSEnumerator *filesEnumerator = [filesArray objectEnumerator];
    NSString *fileName;
    unsigned long int fileSize = 0;
    
    while (fileName = [filesEnumerator nextObject]) {
        NSDictionary *fileDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:[path stringByAppendingPathComponent:fileName] error:nil];
        fileSize += [fileDictionary fileSize];
    }
    
    return fileSize;
}

#pragma clang diagnostic pop

@end
