#import <Foundation/Foundation.h>

@class Future;

typedef NS_ENUM(NSInteger, RequestParameterEncodingType) {
    RequestParameterEncodingTypeJSON,
    RequestParameterEncodingTypeForm,
    RequestParameterEncodingTypeCustom
};

@interface ClientResponse : NSObject <NSCopying>

@property (copy, nonatomic, readonly) NSHTTPURLResponse* __nonnull HTTPResponse;
@property (copy, nonatomic, readonly) NSData* __nonnull output;

+ (ClientResponse* __nonnull)withHTTPResponse:(NSHTTPURLResponse* __nonnull)HTTPResponse output:(NSData* __nonnull)output;

@end

@interface ClientError : NSObject <NSCopying>

@property (nonatomic, readonly) NSInteger statusCode;
@property (copy, nonatomic, readonly) NSString* __nullable urlString;
@property (copy, nonatomic, readonly) NSDictionary* __nullable headers;
@property (copy, nonatomic, readonly) NSString* __nullable outputString;
@property (copy, nonatomic, readonly) NSDictionary* __nullable serverErrors;
@property (copy, nonatomic, readonly) NSError* __nullable networkError;

+ (ClientError* __nonnull)withStatusCode:(NSInteger)statusCode urlString:(NSString* __nullable)urlString headers:(NSDictionary* __nullable)headers outputString:(NSString* __nullable)outputString serverErrors:(NSDictionary* __nullable)serverErrors networkError:(NSError* __nullable)networkError;

@end

@interface RequestParameterEncoding : NSObject <NSCopying>

@property (nonatomic, readonly) RequestParameterEncodingType type;

+ (RequestParameterEncoding* __nonnull)JSON;
+ (RequestParameterEncoding* __nonnull)form;
+ (RequestParameterEncoding* __nonnull)customWithEncodingBlock:(NSString* __nonnull(^ __nonnull)(NSDictionary* __nonnull))customEncodingBlock;

@end

@interface GenericClient : NSObject

@property (copy, nonatomic, readonly) NSString* __nonnull urlString;

+ (GenericClient* __nonnull)withURLString:(NSString* __nonnull)urlString;
+ (GenericClient* __nonnull)withURLString:(NSString* __nonnull)urlString parameterEncoding:(RequestParameterEncoding* __nonnull)parameterEncoding;
+ (GenericClient* __nonnull)withURLString:(NSString* __nonnull)urlStirng parameterEncoding:(RequestParameterEncoding* __nonnull)parameterEncoding customHeaders:(NSDictionary* __nullable)customHeaders;

/// Future<ClientResponse,ClientError>
- (Future* __nonnull)getRequestWithParameters:(NSDictionary* __nullable)parameters;

/// Future<ClientResponse,ClientError>
- (Future* __nonnull)postRequestWithParameters:(NSDictionary* __nullable)parameters;

#pragma mark - utility

+ (NSString* __nonnull)queryStringFromDict:(NSDictionary* __nonnull)dict;

@end
