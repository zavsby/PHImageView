//
//  UIApplication+ProjectHelpers.m
//  testProject
//
//  Created by Sergey on 13.07.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "UIApplication+ProjectHelpers.h"

@implementation UIApplication (ProjectHelpers)

- (NSString *)documentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

+ (NSString *)cachesDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *basePath = (paths.count > 0) ? paths[0] : nil;
    return basePath;
}

+ (int)screenHeight
{
    return (int)[[UIScreen mainScreen] bounds].size.height;
}

+ (BOOL)is4InchDevice
{
    return ([self screenHeight] > 480) ? YES : NO;
}

@end
