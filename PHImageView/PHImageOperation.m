//
//  PHImageOperation.m
//  OmmatiHelpers
//
//  Created by Sergey on 16.07.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PHImageOperation.h"

@implementation PHImageOperation

- (id)initWithImageURL:(NSURL *)imageUrl
{
    self = [super init];
    if (self)
    {
        _imageUrl = imageUrl;
    }
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

- (void)main
{
//    NSURLResponse* response = nil;
//    NSError *error = nil;
//    DDLogInfo(@"Started request %@ in THREAD %@", self.imageUrl, [NSThread currentThread]);
    NSURLRequest* request = [NSURLRequest requestWithURL:_imageUrl cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0];
    NSURLConnection *urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    _port = [NSPort port];
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
    [runloop addPort:_port forMode:NSDefaultRunLoopMode];
    [urlConnection scheduleInRunLoop:runloop forMode:NSDefaultRunLoopMode];
    [urlConnection start];
    [runloop run];
    

//    _responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//    if (!self.isCancelled)
//    {
//        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
//        if (error == nil && httpResponse.statusCode == 200)
//        {
//            if ([_delegate respondsToSelector:_didFinishSelector])
//            {
//                [_delegate  performSelector:_didFinishSelector withObject:self];
//            }
//        }
//        else
//        {
//            _error = error;
//            if ([_delegate respondsToSelector:_didFailSelector])
//            {
//                [_delegate performSelector:_didFailSelector withObject:self];
//            }
//        }
//
//    }
//    [self completeOperation];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    DDLogInfo(@"FAIL CONNECTION!");
    if (!self.isCancelled)
    {
        _error = error;
        if ([_delegate respondsToSelector:_didFailSelector])
        {
            [_delegate performSelector:_didFailSelector withObject:self];
        }
    }
    [self completeOperation];
    [self completeRunloop:connection];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
//    DDLogInfo(@"Received response %@ in THREAD %@", self.imageUrl, [NSThread currentThread]);
    _response = (NSHTTPURLResponse *)response;
    _responseData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
//    DDLogInfo(@"Finished request %@ in THREAD %@", self.imageUrl, [NSThread currentThread]);
    if (!self.isCancelled)
    {
        if (_response.statusCode == 200)
        {
            if ([_delegate respondsToSelector:_didFinishSelector])
            {
                [_delegate  performSelector:_didFinishSelector withObject:self];
            }
        }
        else
        {
            if ([_delegate respondsToSelector:_didFailSelector])
            {
                [_delegate performSelector:_didFailSelector withObject:self];
            }
        }
    }
    [self completeRunloop:connection];
    [self completeOperation];
}

- (void)completeRunloop:(NSURLConnection *)urlConnection
{
//    [urlConnection unscheduleFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    CFRunLoopStop([[NSRunLoop currentRunLoop] getCFRunLoop]);
    [[NSRunLoop currentRunLoop] removePort:_port forMode:NSDefaultRunLoopMode];
}


- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return nil;
}

#pragma clang diagnostic pop

@end
