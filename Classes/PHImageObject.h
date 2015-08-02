//
//  PHImageObject.h
//  PHImageView 2.0
//
//  Created by Sergey Plotkin on 17.07.12.
//  Copyright (c) 2012 ITM House. All rights reserved.
//

@import Foundation;
@import UIKit;

@interface PHImageObject : NSObject

@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) NSInteger size;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign) BOOL temperaly;
@property (nonatomic, assign) BOOL onDiskCache;

+ (instancetype)imageObjectWithName:(NSString *)name size:(NSInteger)size;

@end
