//
//  PHImageOperation.m
//  PHImageView 2.0
//
//  Created by Sergey Plotkin on 16.07.12.
//  Copyright (c) 2012 ITM House. All rights reserved.
//

#import "PHImageOperation.h"

@implementation PHImageOperation

#pragma mark - Initilization

- (id)initWithImageURL:(NSURL *)imageUrl
{
    self = [super init];
    if (self)
    {
        _imageUrl = imageUrl;
    }
    return self;
}

+ (instancetype)imageOperationWithURL:(NSURL *)imageUrl completion:(PHImageOperationCompletionBlock)completion
{
    PHImageOperation *operation = [[PHImageOperation alloc] initWithImageURL:imageUrl];
    operation.completionBlock = completion;
    return operation;
}

- (void)main
{
    NSURLRequest* request = [NSURLRequest requestWithURL:_imageUrl cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0];
    
    NSURLConnection *urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    _port = [NSPort port];
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
    [runloop addPort:_port forMode:NSDefaultRunLoopMode];
    [urlConnection scheduleInRunLoop:runloop forMode:NSDefaultRunLoopMode];
    [urlConnection start];
    [runloop run];
}

#pragma mark - NSURLConnection Delegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (!self.isCancelled)
    {
        _error = error;
        PERFORM_BLOCK(self.completionBlock, self);
    }
    
    self.completionBlock = nil;
    [self completeRunloop:connection];
    [self completeOperation];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    _response = (NSHTTPURLResponse *)response;
    _responseData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (!self.isCancelled)
    {
        if (_response.statusCode == 200)
        {
            PERFORM_BLOCK(self.completionBlock, self);
        }
        else
        {
            _error = [NSError errorWithDomain:@"Error" description:@"Status code is not 200." code:_response.statusCode];
            PERFORM_BLOCK(self.completionBlock, self);
        }
    }
    
    self.completionBlock = nil;
    [self completeRunloop:connection];
    [self completeOperation];
}

- (void)completeRunloop:(NSURLConnection *)urlConnection
{
    CFRunLoopStop([[NSRunLoop currentRunLoop] getCFRunLoop]);
    [[NSRunLoop currentRunLoop] removePort:_port forMode:NSDefaultRunLoopMode];
}


- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return nil;
}

@end
