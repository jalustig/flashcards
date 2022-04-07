//
//  FCRequest.h
//  ImportSDK
//
//  Created by Jason Lustig
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//


@protocol FCNetworkRequestDelegate;

@class ASIFormDataRequest;

/* DBRestRequest will download a URL either into a file that you provied the name to or it will
 create an NSData object with the result. When it has completed downloading the URL, it will
 notify the target with a selector that takes the DBRestRequest as the only parameter. */
@interface FCRequest : NSObject {
    ASIFormDataRequest* request;
    id target;

    SEL selector;
    SEL failureSelector;
    
    NSMutableData* __weak resultData;
    NSError* error;
    BOOL cancelled;
}

/*  Set this to get called when _any_ request starts or stops. This should hook into whatever
 network activity indicator system you have. */
+ (void)setNetworkRequestDelegate:(id<FCNetworkRequestDelegate>)delegate;

/*  This constructor downloads the URL into the resultData object */
- (id)initWithURLRequest:(ASIFormDataRequest*)request andInformTarget:(id)target selector:(SEL)selector;

/*  Cancels the request and prevents it from sending additional messages to the delegate. */
- (void)cancel;

- (void)connectionFinished:(ASIFormDataRequest *)theRequest;
- (void)connectionFailed:(ASIFormDataRequest *)theRequest;

@property (nonatomic, assign) SEL failureSelector; // To send failure events to a different selector set this
@property (nonatomic, assign) SEL downloadProgressSelector; // To receive download progress events set this
@property (nonatomic, assign) SEL uploadProgressSelector; // To receive upload progress events set this

@property (nonatomic, readonly) ASIFormDataRequest* request;
@property (nonatomic, readonly) NSInteger statusCode;
@property (weak, nonatomic, readonly) NSData* resultData;
@property (weak, nonatomic, readonly) NSString* resultString;
@property (weak, nonatomic, readonly) NSObject* resultJSON;
@property (nonatomic, readonly) NSError* error;
@property (nonatomic, assign) BOOL cancelled; 

@end
