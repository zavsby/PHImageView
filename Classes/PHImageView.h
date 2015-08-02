//
//  PHImageView.h
//  PHImageView 2.0
//
//  Created by Sergey Plotkin on 16.07.12.
//  Copyright (c) 2012 ITM House. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PHImageCacheManager.h"
#import "PHImageCacheParams.h"
#import "PHImageViewTypes.h"

@protocol PHImageViewDelegate;

@interface PHImageView : UIImageView

// Transforming image loaded to image view
@property (nonatomic, copy) PHImageCacheTransformBlock transfromBlock;
// Image View Delegate
@property (nonatomic, weak) id<PHImageViewDelegate> delegate;
// Load image automatically after settings imageURL
@property (nonatomic, strong) NSURL *imageURL;
// Image Name (its URL md5)
@property (nonatomic, copy, readonly) NSString *imageName;

@property (nonatomic, strong) id userObject;

- (instancetype)initWithURL:(NSURL *)imageUrl;
- (instancetype)initWithURL:(NSURL *)imageUrl frame:(CGRect)frame;

- (void)loadImage:(NSURL *)imageUrl;
- (void)loadImage:(NSURL *)imageUrl tempCache:(BOOL)tempCache;
- (void)loadImage:(NSURL *)imageUrl params:(PHImageCacheParams *)params;

@end

@protocol PHImageViewDelegate <NSObject>

@optional
- (void)imageViewDidTapped:(PHImageView *)imageView;

@end