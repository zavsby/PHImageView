//
//  PHImageOperation.h
//  PHImageView 2.0
//
//  Created by Sergey Plotkin on 16.07.12.
//  Copyright (c) 2012 ITM House. All rights reserved.
//

#import "PHOperation.h"
#import "PHImageViewTypes.h"

@class PHImageOperation;
@class PHImageCacheParams;

typedef void(^PHImageOperationCompletionBlock)(PHImageOperation *operation);

@interface PHImageOperation : PHOperation

@property (nonatomic, readonly) NSURL *imageUrl;
@property (nonatomic, readonly) NSMutableData *responseData;
@property (nonatomic, readonly) NSError *error;
@property (nonatomic, copy) PHImageOperationCompletionBlock completionBlock;

@property (nonatomic, strong) PHImageCacheParams *params;

- (instancetype)initWithImageURL:(NSURL *)_imageUrl;
+ (instancetype)imageOperationWithURL:(NSURL *)imageUrl completion:(PHImageOperationCompletionBlock)completion;

@end
