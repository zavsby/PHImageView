//
//  PHImageView.m
//  PHImageView 2.0
//
//  Created by Sergey Plotkin on 16.07.12.
//  Copyright (c) 2012 ITM House. All rights reserved.
//

#import "PHImageView.h"
#import "PHImageCacheManager.h"
#import "PHImageOperation.h"
#import "PHImageCacheParams.h"

#import <ProjectHelpers/ProjectHelpers.h>

@interface PHImageView ()

@property (nonatomic, weak) PHImageCacheManager *cacheManager;
@property (nonatomic, copy) NSString *imageName;

@end

@implementation PHImageView

#pragma mark - Initialization

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self)  {
        [self initialize];
    }
    return self;
}

- (void)awakeFromNib {
    [self initialize];
}

- (id)init {
    self = [super init];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)initialize {
    _cacheManager = [PHImageCacheManager sharedManager];
    
    [self publicInit];
}

- (id)initWithURL:(NSURL *)imageUrl {
    self = [super init];
    if (self) {
        [self loadImage:imageUrl];
    }
    return self;
}

- (id)initWithURL:(NSURL *)imageUrl frame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self loadImage:imageUrl];
    }
    return self;
}

#pragma mark - Async Image View

- (void)loadImage:(NSURL *)imageUrl {
    [self loadImage:imageUrl params:[PHImageCacheParams cacheParamsWithTemporary:NO]];
}

- (void)loadImage:(NSURL *)imageUrl tempCache:(BOOL)tempCache {
    [self loadImage:imageUrl params:[PHImageCacheParams cacheParamsWithTemporary:tempCache]];
}

- (void)loadImage:(NSURL *)imageUrl params:(PHImageCacheParams *)params {
    if (imageUrl == nil) {
        self.image = nil;
        return;
    }
    
    if ([imageUrl.absoluteString isEqualToString:self.imageURL.absoluteString] && self.image != nil) {
        return;
    }
    
    if (imageUrl != self.imageURL) {
        self.image = nil;
        self.imageURL = imageUrl;
        self.imageName = [imageUrl.absoluteString md5];
    }
    
    params.transformBlock = self.transfromBlock;
    
    __weak PHImageView *weakSelf = (PHImageView *)self;
    [self.cacheManager getImage:self.imageURL params:params completion:^(UIImage *image, NSString *imageName, PHImageCacheSourceType sourceType, NSError *error) {
        if ([weakSelf.imageName isEqualToString:imageName]) {
            if (error) {
                [weakSelf failedImageLoading];
            } else if (![weakSelf finishImageLoading:image sourceType:sourceType]) {
                weakSelf.image = image;
            }
        }
    } progress:^(PHImageCacheGettingType gettingType) {
        [weakSelf willLoadImage:gettingType];
    }];
}

#pragma mark - Methods to override

- (void)publicInit {}
- (BOOL)finishImageLoading:(UIImage *)image sourceType:(PHImageCacheSourceType)sourceType { return NO; }
- (void)failedImageLoading {}
- (void)willLoadImage:(PHImageCacheGettingType)gettingType {}


#pragma mark - Touch events

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (![self.delegate respondsToSelector:@selector(imageViewDidTapped:)]) {
        return;
    }
    
    UITouch *touch = [touches anyObject];
    if (touch.tapCount == 1) {
        [_delegate imageViewDidTapped:self];
    }
}

@end
