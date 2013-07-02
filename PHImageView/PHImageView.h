//
//  OMImageView.h
//  OmmatiHelpers
//
//  Created by Sergey on 16.07.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PHImageCacheManager.h"
#import "PHImageOperation.h"
#import "PHImageCacheParams.h"

@protocol PHImageViewDelegate;

@interface PHImageView : UIImageView
{
    PHImageCacheManager* cacheManager;
}

// Transforming image loaded to image view
@property (nonatomic, assign) SEL transformSelector;
@property (nonatomic, weak) id transformTarget;
// Image View Delegate
@property (nonatomic, weak) id<PHImageViewDelegate> delegate;
// Change image frame for image's real size
@property (nonatomic, assign) BOOL changeImageFrameToImageFrame;
// Load image automatically after settings imageURL
@property (nonatomic, assign) BOOL loadAutomaticly;
@property (nonatomic, strong) NSURL* imageURL;
// Image Name (its URL md5)
@property (nonatomic, readonly) NSString* imageName;

// Animation while loading
@property (nonatomic, strong) UIColor *defaultBackgroundColor;
@property (nonatomic, strong) UIView *animationView;

@property (nonatomic, strong) id userObject;

- (id)initWithURL:(NSURL *)imageUrl;
- (id)initWithURL:(NSURL *)imageUrl frame:(CGRect)frame;

- (void)loadImage:(NSURL *)imageUrl;
- (void)loadImage:(NSURL *)imageUrl tempCache:(BOOL)tempCache;

- (void)loadImage:(NSURL *)imageUrl params:(PHImageCacheParams *)params;

//
// Methods to override
//

// Calls while first time init
- (void)publicInit;
// Calls every time after calling loadImage method but before checking imageUrl for NULL (usefull for reuse)
- (void)willStartImageLoading;
// Calls every time when image will be loaded from disk cache or network
- (void)startImageLoading;
// Calls every time when image was loaded (even when it was loaded from memory cache, you should hadnle this situation yourself!)
- (void)finishImageLoading;
// Calls when image which connected with image view was failed to load
- (void)failedImageLoading;

@end

@protocol PHImageViewDelegate <NSObject>

@optional
// Calls every time when image will be loaded (from any cache or network)
- (void)asyncImageViewImageWillStartLoading:(PHImageView *)asyncImageView;
// Calls every time when image was loaded
- (void)asyncImageViewImageDidLoad:(PHImageView *)asyncImageView;
- (void)asyncImageViewImageDidFailedLoad:(NSError *)error;
// Calls when image was tapped (only if this method was implemented in delegate)
- (void)asyncImageViewImageDidTapped:(PHImageView *)asyncImageView;

@end