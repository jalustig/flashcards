
#import "FCRequest.h"
#import "JSONKit.h"

#import "ASIFormDataRequest.h"


static id networkRequestDelegate = nil;

@implementation FCRequest

+ (void)setNetworkRequestDelegate:(id<FCNetworkRequestDelegate>)delegate {
    networkRequestDelegate = delegate;
}

- (id)initWithURLRequest:(ASIFormDataRequest*)aRequest andInformTarget:(id)aTarget selector:(SEL)aSelector {
    if ((self = [super init])) {
        request = aRequest;
        target = aTarget;
        selector = aSelector;
        cancelled = NO;
        
        [aRequest setDelegate:self];
        [aRequest setDidFinishSelector:@selector(connectionFinished:)];
        [aRequest setDidFailSelector:@selector(connectionFinished:)];
        [aRequest startAsynchronous];
    }
    return self;
}

- (void) dealloc {
    [request setDelegate:nil];
    [request cancel];
    
}

@synthesize failureSelector;
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
@synthesize downloadProgressSelector;
@synthesize uploadProgressSelector;
#endif
@synthesize request;
@synthesize resultData;
@synthesize error;
@synthesize cancelled;

- (NSString*)resultString {
    return [request responseString];
}

- (NSObject*)resultJSON {
    return [[self resultString] objectFromJSONString];
} 

- (NSInteger)statusCode {
    return [request responseStatusCode];
}

- (void)cancel {
    cancelled = YES;
    [request cancel];
    [request setDelegate:nil];
    request = nil;
    target = nil;
}

#pragma mark NSURLConnection delegate methods

- (void)connectionFinished:(ASIFormDataRequest *)theRequest {
    if (cancelled) {
        return;
    }
    if (self.statusCode != 200) {
        NSMutableDictionary* errorUserInfo = [[NSMutableDictionary alloc] initWithCapacity:0];
        // To get error userInfo, first try and make sense of the response as JSON, if that
        // fails then send back the string as an error message
        NSString* resultString = [self resultString];
        NSLog(@"Output: %@", resultString);
        if ([resultString length] > 0) {
            NSMutableDictionary *resultJSON = [NSMutableDictionary dictionaryWithDictionary:[resultString objectFromJSONString]];
            if ([(NSMutableDictionary*)resultJSON valueForKey:@"error_description"] && ![(NSMutableDictionary*)resultJSON valueForKey:@"errorMessage"]) {
                NSString *errorDescription = [resultJSON valueForKey:@"error_description"];
                [resultJSON setObject:errorDescription forKey:@"errorMessage"];
            }
            [errorUserInfo addEntriesFromDictionary:(NSDictionary*)resultJSON];
            
        }
        error = [[NSError alloc] initWithDomain:@"iphoneflashcards.com" code:self.statusCode userInfo:errorUserInfo];
    }
    
    SEL sel = (error && failureSelector) ? failureSelector : selector;
    if (target) {
        [target performSelector:sel withObject:self];
    }
}

- (void)connectionFailed:(ASIFormDataRequest *)theRequest {
    if (cancelled) {
        return;
    }
    error = [[NSError alloc] initWithDomain:theRequest.error.domain code:theRequest.error.code userInfo:nil];
    
    SEL sel = failureSelector ? failureSelector : selector;
    if (target) {
        [target performSelector:sel withObject:self];
    }
}

@end
