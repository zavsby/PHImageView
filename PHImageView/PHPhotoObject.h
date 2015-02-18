//
//  PHPhotoObject.h
//  OmmatiHelpers
//
//  Created by Sergey on 17.07.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PHPhotoObject : NSObject

@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign) NSInteger size;
@property (nonatomic, assign) BOOL temperaly;

@end
