//
//  PHImageView.h
//  PHImageView 2.0
//
//  Created by Sergey Plotkin on 16.07.12.
//  Copyright (c) 2012 ITM House. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PHImageCacheManager.h"
#import "PHImageOperation.h"
#import "PHImageCacheParams.h"

@protocol PHImageViewDelegate;

@interface PHImageView : UIImageView
{
    PHImageCacheManager *_cacheManager;
}

// Transforming image loaded to image view
@property (nonatomic, copy) PHImageCacheTransformBlock transfromBlock;
// Image View Delegate
@property (nonatomic, weak) id<PHImageViewDelegate> delegate;
// Load image automatically after settings imageURL
@property (nonatomic, strong) NSURL *imageURL;
// Image Name (its URL md5)
@property (nonatomic, readonly) NSString *imageName;

@property (nonatomic, strong) id userObject;

-(id)initWithURL:(NSURL *)imageUrl;
-(id)initWithURL:(NSURL *)imageUrl frame:(CGRect)frame;

- (void)loadImage:(NSURL *)imageUrl;
- (void)loadImage:(NSURL *)imageUrl tempCache:(BOOL)tempCache;

- (void)loadImage:(NSURL *)imageUrl params:(PHImageCacheParams *)params;

//
// Methods to override
//

// Calls while first time init
- (void)publicInit;
// Calls every time when image was loaded (even when it was loaded from memory cache, you should hadnle this situation yourself!)
- (BOOL)finishImageLoading:(UIImage *)image sourceType:(PHImageCacheSourceType)sourceType;
// Calls when image which connected with image view was failed to load
- (void)failedImageLoading;

- (void)willLoadImage:(PHImageCacheGettingType)gettingType;

@end

@protocol PHImageViewDelegate <NSObject>

@optional
// Calls when image was tapped (only if this method was implemented in delegate)
- (void)asyncImageViewImageDidTapped:(PHImageView *)asyncImageView;

@end