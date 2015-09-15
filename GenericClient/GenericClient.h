#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class Future;

typedef NS_ENUM(NSInteger, RequestParameterEncodingType) {
    RequestParameterEncodingTypeJSON,
    RequestParameterEncodingTypeForm,
    RequestParameterEncodingTypeCustom
};

@interface ClientResponse : NSObject <NSCopying>

@property (copy, nonatomic, readonly) NSHTTPURLResponse* HTTPResponse;
@property (copy, nonatomic, readonly) NSData* output;

+ (ClientResponse*)withHTTPResponse:(NSHTTPURLResponse*)HTTPResponse output:(NSData*)output;

@end

@interface ClientError : NSObject <NSCopying>

@property (nonatomic, readonly) NSInteger statusCode;
@property (copy, nonatomic, readonly) NSString* __nullable urlString;
@property (copy, nonatomic, readonly) NSDictionary* __nullable headers;
@property (copy, nonatomic, readonly) NSString* __nullable outputString;
@property (copy, nonatomic, readonly) NSDictionary* __nullable serverErrors;
@property (copy, nonatomic, readonly) NSError* __nullable networkError;

@property (nonatomic, readonly) NSDictionary* keyedDescription;

+ (ClientError*)withStatusCode:(NSInteger)statusCode urlString:(NSString* __nullable)urlString headers:(NSDictionary* __nullable)headers outputString:(NSString* __nullable)outputString serverErrors:(NSDictionary* __nullable)serverErrors networkError:(NSError* __nullable)networkError;

@end

@interface RequestParameterEncoding : NSObject <NSCopying>

@property (nonatomic, readonly) RequestParameterEncodingType type;

+ (RequestParameterEncoding*)JSON;
+ (RequestParameterEncoding*)form;
+ (RequestParameterEncoding*)customWithEncodingBlock:(NSString*(^)(NSDictionary*))customEncodingBlock;

@end

@interface GenericClient : NSObject

@property (copy, nonatomic, readonly) NSString* urlString;

+ (GenericClient*)withURLString:(NSString*)urlString;
+ (GenericClient*)withURLString:(NSString*)urlString parameterEncoding:(RequestParameterEncoding*)parameterEncoding;
+ (GenericClient*)withURLString:(NSString*)urlStirng parameterEncoding:(RequestParameterEncoding*)parameterEncoding customHeaders:(NSDictionary* __nullable)customHeaders;

/// Future<ClientResponse,ClientError>
- (Future*)getRequestWithParameters:(NSDictionary* __nullable)parameters;

/// Future<ClientResponse,ClientError>
- (Future*)postRequestWithParameters:(NSDictionary* __nullable)parameters;

#pragma mark - utility

+ (NSString*)queryStringFromDict:(NSDictionary*)dict;
+ (NSDictionary*)basicAuthorizationHeaderWithUsername:(NSString*)username password:(NSString*)password;

@end

NS_ASSUME_NONNULL_END
