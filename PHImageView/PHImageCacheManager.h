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
    // для совместимости с iOS < 5.0
    long _priorityForDispatchAsync;
}

@property (nonatomic, assign) NSInteger maxConcurrentImageOperations;
@property (nonatomic, assign) NSInteger maxDiskCacheSize;
@property (nonatomic, assign) NSInteger maxMemoryCacheElements;
@property (nonatomic, readonly) NSOperationQueue *operationQueue;

+ (id)instance;

// Инициализация и подготовка к работе кэша
- (void)loadCache;

- (UIImage *)getImageForImageView:(PHImageView *)imageView params:(PHImageCacheParams *)params;

//
// Дополнительные методы для прямого получения картинок
//

// Возвращает картинку из кэша (дискового или памяти), если картинки в кэше нет, то возвращает nil
- (UIImage *)getImageFromCache:(NSURL *)imageUrl;
// Возвращает картинку из кэша (дискового или памяти), или загружает ее, если ее там нет (через Notification)
// Notification: PHImageCacheImageWasDownloadedNotification
//- (UIImage *)getImageOrDownload:(NSURL *)imageUrl shouldSaveToCache:(BOOL)shouldSave;

//
// Методы для очистки кэша
//

// Полная очистка временного кэша в памяти
- (void)clearTemperalyImagesInMemory;
// Полная очистка врменного кэша на диске (не рекомендуется вызывать вручную)
- (void)clearTemperalyImagesOnDisk;
// Ручной запуск сборщика мусора для дискового кэша (при передаче 1 параметром очищает ВЕСЬ кэш)
- (void)clearDiskCache:(float)percent;
// Ручной запуск сборщика мусора для кэша в памяти
- (void)clearMemoryCache:(float)percent;
// Метод производит очистку кэша перед выходом из приложения, удаляя весь временный кэш, а также очищая при необходимости основной кэш
- (void)cleanDiskCacheBeforeExit;

// Возвращает текущий размер дискового кэша
+ (unsigned long)cacheSize;

@end

