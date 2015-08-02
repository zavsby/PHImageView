//
//  PHImageViewTypes.h
//  PHImageView
//
//  Created by Sergey on 02.08.15.
//  Copyright (c) 2015 Sergey Plotkin. All rights reserved.
//

#ifndef PHImageView_PHImageViewTypes_h
#define PHImageView_PHImageViewTypes_h

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, PHImageCacheGettingType)
{
    PHImageCacheGettingTypeNotInMemory,
    PHImageCacheGettingTypeOnDisk,
    PHImageCacheGettingTypeDownloading,
    PHImageCacheGettingTypeDownloadFinished
};

typedef NS_ENUM(NSUInteger, PHImageCacheSourceType)
{
    PHImageCacheSourceTypeMemory,
    PHImageCacheSourceTypeDisk,
    PHImageCacheSourceTypeServer
};

typedef void(^PHImageCacheCompletionBlock)(UIImage *image, NSString *imageName, PHImageCacheSourceType sourceType, NSError *error);
typedef void(^PHImageCacheProgressBlock)(PHImageCacheGettingType gettingType);
typedef void(^PHImageCacheBatchCompletionBlock)(NSUInteger numberOfSuccessfullOperation, NSArray *images, NSError *error);

typedef UIImage *(^PHImageCacheTransformBlock)(UIImage *image);

#endif
