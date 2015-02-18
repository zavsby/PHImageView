//
//  PHImageObject.m
//  PHImageView 2.0
//
//  Created by Sergey Plotkin on 17.07.12.
//  Copyright (c) 2012 ITM House. All rights reserved.
//

#import "PHImageObject.h"

@implementation PHImageObject

+ (instancetype)imageObjectWithName:(NSString *)name size:(NSInteger)size
{
    PHImageObject *imageObject = [[PHImageObject alloc] init];
    imageObject.key = name;
    imageObject.size = size;
    imageObject.onDiskCache = YES;
    return imageObject;
}

@end