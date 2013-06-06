//
//  OMImageView.m
//  OmmatiHelpers
//
//  Created by Sergey on 16.07.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PHImageView.h"

@interface PHImageView ()

- (void)initialize;
- (void)mainThreadLoadImageActions:(UIImage*)image;

@end

@implementation PHImageView

@synthesize delegate;
@synthesize changeImageFrameToImageFrame;
@synthesize transformSelector;
@synthesize imageURL;
@synthesize imageName;
@synthesize loadAutomaticly;

#pragma mark - Initialization
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) 
    {
        [self initialize];
    }
    return self;
}

-(void)awakeFromNib
{
    [self initialize];
}

-(id)init
{
    self = [super init];
    if (self)
    {
        [self initialize];
    }
    return self;
}

-(void)initialize
{
    cacheManager = [PHImageCacheManager sharedManager];
    // Default Configuration
    changeImageFrameToImageFrame = NO;
    loadAutomaticly = NO;
    [self publicInit];
}

-(id)initWithURL:(NSURL *)imageUrl
{
    self = [super init];
    if (self)
    {
        [self loadImage:imageUrl];
    }
    return self;
}

-(id)initWithURL:(NSURL *)imageUrl frame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self loadImage:imageUrl];
    }
    return self;
}

#pragma mark - Properties

-(void)setImageURL:(NSURL *)_imageURL
{
    imageURL = _imageURL;
    if (loadAutomaticly)
    {
        [self loadImage:imageURL];
    }
}

- (void)setDefaultBackgroundColor:(UIColor *)defaultBackgroundColor
{
    _defaultBackgroundColor = defaultBackgroundColor;
    self.animationView.backgroundColor = defaultBackgroundColor;
}

#pragma mark - Async Image View

// PUBLIC METHOD
- (void)loadImage:(NSURL *)imageUrl
{
    [self loadImage:imageUrl tempCache:NO];
}

- (void)loadImage:(NSURL *)imageUrl tempCache:(BOOL)tempCache
{
    [self loadImage:imageURL params:[PHImageCacheParams cacheParamsWithTemporary:tempCache]];
}

- (void)loadImage:(NSURL *)imageUrl params:(PHImageCacheParams *)params
{
    [self willStartImageLoading];
    
    if (imageUrl == nil)
    {
        self.image = nil;
        return;
    }
    
    if ([imageUrl.absoluteString isEqualToString:imageURL.absoluteString] && self.image != nil)
    {
        return;
    }
    
    if (imageUrl != self.imageURL)
    {
        self.image = nil;
        self.imageURL = imageUrl;
        imageName = [imageUrl.absoluteString md5];
    }
    
    if ([delegate respondsToSelector:@selector(asyncImageViewImageWillStartLoading:)])
    {
        [delegate asyncImageViewImageWillStartLoading:self];
    }
    
    UIImage *image = [cacheManager getImageForImageView:self params:params];
    // We don't reveive nil only if image was in memory
    if (image != nil)
    {
        [self performSelectorOnMainThread:@selector(mainThreadLoadImageActions:) withObject:image waitUntilDone:NO];
    }
    else
    {
        // Else we request image from disk cache or server
        [self startImageLoading];
    }
}

- (void)mainThreadLoadImageActions:(UIImage *)image
{
    if (changeImageFrameToImageFrame)
    {
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.image.size.width, self.image.size.height);
    }
    
    [self finishImageLoading];
    
    self.image = image;
    
    if (([delegate respondsToSelector:@selector(asyncImageViewImageDidLoad:)])&&(delegate != nil))
    {
        [delegate asyncImageViewImageDidLoad:self];
    }
}

- (void)mainThreadLoadImageFailed
{
    [self failedImageLoading];
    
    if ([delegate respondsToSelector:@selector(asyncImageViewImageDidFailedLoad:)])
    {
        [delegate asyncImageViewImageDidFailedLoad:nil];
    }
}

#pragma mark - Methods to override

- (void)publicInit
{

}

- (void)willStartImageLoading
{
    
}

- (void)startImageLoading
{
}

- (void)finishImageLoading
{

}

- (void)failedImageLoading
{
    ALog(@"Failed loading image.");
}

#pragma mark - Touch events

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (![delegate respondsToSelector:@selector(asyncImageViewImageDidTapped:)])
    {
        return;
    }
    UITouch* touch = [touches anyObject];
    if (touch.tapCount == 1)
    {
        [delegate asyncImageViewImageDidTapped:self];
    }
}

@end
