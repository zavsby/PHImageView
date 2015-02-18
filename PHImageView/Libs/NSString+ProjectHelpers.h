//
//  NSString+ProjectHelpres.h
//  testProject
//
//  Created by Sergey on 11.07.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

@interface NSString (ProjectHelpers)

+(NSString*)stringHTTPEncodedFromString:(NSString *)str;
-(NSString*)stringHTTPEncoded;
+(NSString*)stringFromDecimalTime:(float)time;
- (NSString *) md5;
- (BOOL)isEmpty;
- (BOOL)isNotEmpty;

+ (BOOL)isEmpryString:(NSString *)string;

@end
