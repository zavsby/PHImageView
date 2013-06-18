//
//  UIApplication+ProjectHelpers.h
//  testProject
//
//  Created by Sergey on 13.07.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIApplication (ProjectHelpers)

+ (NSString *)cachesDirectory;
- (NSString *)documentsDirectory;
+ (int)screenHeight;
+ (BOOL)is4InchDevice;

@end
