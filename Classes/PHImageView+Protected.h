//
//  PHImageView+Protected.h
//  PHImageView
//
//  Created by Sergey on 02.08.15.
//  Copyright (c) 2015 Sergey Plotkin. All rights reserved.
//

#import "PHImageView.h"

@interface PHImageView ()

/**
 *  Calls while first time initializtion.
 */
- (void)publicInit;

/**
 *  Calls every time when state of loading image process changes.
 *
 *  @param gettingType Current state.
 */
- (void)willLoadImage:(PHImageCacheGettingType)gettingType;
/**
 *  Calls every time when image was loaded (from any source)
 *
 *  @param image      Loaded image
 *  @param sourceType Source from which image was loaded
 *  @return If YES you should set self.image in this method
 */
- (BOOL)finishImageLoading:(UIImage *)image sourceType:(PHImageCacheSourceType)sourceType;
/**
 *  Calls when image was failed to be loaded.
 */
- (void)failedImageLoading;

@end
