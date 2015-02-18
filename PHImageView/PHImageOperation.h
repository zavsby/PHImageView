//
//  PHImageOperation.h
//  OmmatiHelpers
//
//  Created by Sergey on 16.07.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PHImageCacheManager.h"
#import "PHOperation.h"
#import "PHImageCacheParams.h"

@interface PHImageOperation : PHOperation <NSURLConnectionDelegate,NSURLConnectionDataDelegate>
{
    NSHTTPURLResponse *_response;
    NSPort *_port;
}

@property (nonatomic, readonly) NSURL *imageUrl;
@property (nonatomic, readonly) NSMutableData *responseData;
@property (nonatomic, readonly) NSError *error;
@property (nonatomic, strong) PHImageCacheParams *params;
@property (nonatomic, assign) SEL didFinishSelector;
@property (nonatomic, assign) SEL didFailSelector;
@property (nonatomic, weak) id delegate;

- (id)initWithImageURL:(NSURL *)_imageUrl;

@end
