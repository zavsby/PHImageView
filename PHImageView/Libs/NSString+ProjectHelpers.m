//
//  NSString+ProjectHelpres.m
//  testProject
//
//  Created by Sergey on 11.07.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSString+ProjectHelpers.h"

@implementation NSString (ProjectHelpers)

+ (NSString*)stringHTTPEncodedFromString:(NSString *)str
{
    return [str stringHTTPEncoded];
}

-(NSString*)stringHTTPEncoded
{
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes( NULL,(CFStringRef)self,NULL,(CFStringRef)@"!Т\"();:@&=+$,/?%#[]% ",kCFStringEncodingISOLatin1));
}

+(NSString*)stringFromDecimalTime:(float)time
{
    int minutes = ((int)(time*60))%60;
    return [NSString stringWithFormat:@"%dh%dm",(int)time,minutes];
}

- (NSString *) md5
{
	const char *cStr = [self UTF8String];
	unsigned char result[16];
	CC_MD5( cStr, strlen(cStr), result ); // This is the md5 call
	return [NSString stringWithFormat:
			@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
			result[0], result[1], result[2], result[3],
			result[4], result[5], result[6], result[7],
			result[8], result[9], result[10], result[11],
			result[12], result[13], result[14], result[15]
			];
}

- (BOOL)isEmpty
{
    return ([[self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]) ? YES : NO;
}

- (BOOL)isNotEmpty
{
    return ([[self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]) ? NO : YES;
}

+ (BOOL)isEmpryString:(NSString *)string
{
    if (string == nil || [string isEmpty])
    {
        return YES;
    }
    return NO;
}

@end
