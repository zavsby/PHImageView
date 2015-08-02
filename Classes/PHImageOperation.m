//
//  PHImageOperation.m
//  PHImageView 2.0
//
//  Created by Sergey Plotkin on 16.07.12.
//  Copyright (c) 2012 ITM House. All rights reserved.
//

#import "PHImageOperation.h"
#import "PHImageCacheManager.h"
#import "PHImageCacheParams.h"

#import <ProjectHelpers/ProjectHelpers.h>

@interface PHImageOperation () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSPort *port;

@property (nonatomic, strong) NSURL *imageUrl;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSError *error;

@end

@implementation PHImageOperation

#pragma mark - Initilization

- (id)initWithImageURL:(NSURL *)imageUrl {
    self = [super init];
    if (self) {
        _imageUrl = imageUrl;
    }
    return self;
}

+ (instancetype)imageOperationWithURL:(NSURL *)imageUrl completion:(PHImageOperationCompletionBlock)completion {
    PHImageOperation *operation = [[PHImageOperation alloc] initWithImageURL:imageUrl];
    operation.completionBlock = completion;
    return operation;
}

- (void)main {
    NSURLRequest* request = [NSURLRequest requestWithURL:self.imageUrl cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0];
    
    NSURLConnection *urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    self.port = [NSPort port];
    
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
    [runloop addPort:self.port forMode:NSDefaultRunLoopMode];
    
    [urlConnection scheduleInRunLoop:runloop forMode:NSDefaultRunLoopMode];
    [urlConnection start];
    [runloop run];
}

#pragma mark - NSURLConnection Delegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if (!self.isCancelled) {
        self.error = error;
        PERFORM_BLOCK(self.completionBlock, self);
    }
    
    self.completionBlock = nil;
    [self completeRunloop:connection];
    [self completeOperation];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.response = (NSHTTPURLResponse *)response;
    self.responseData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (!self.isCancelled) {
        if (self.response.statusCode == 200) {
            PERFORM_BLOCK(self.completionBlock, self);
        } else {
            self.error = [NSError errorWithDomain:@"Error" description:@"Status code is not 200." code:self.response.statusCode];
            PERFORM_BLOCK(self.completionBlock, self);
        }
    }
    
    self.completionBlock = nil;
    [self completeRunloop:connection];
    [self completeOperation];
}

- (void)completeRunloop:(NSURLConnection *)urlConnection {
    CFRunLoopStop([[NSRunLoop currentRunLoop] getCFRunLoop]);
    [[NSRunLoop currentRunLoop] removePort:self.port forMode:NSDefaultRunLoopMode];
}


- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}

@end
