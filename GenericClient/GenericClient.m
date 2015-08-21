#import "GenericClient.h"
#import "Tools.h"
#import "Future_Internal.h"

@interface QueryStringPair : NSObject

@property (copy, nonatomic) NSString* field;
@property (copy, nonatomic) NSString* value;

+ (QueryStringPair*)withField:(NSString*)field value:(NSString*)value;
- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding;

@end

@implementation QueryStringPair

+ (QueryStringPair*)withField:(NSString*)field value:(NSString*)value {
    QueryStringPair* pair = [QueryStringPair new];
    pair.field = field;
    pair.value = value;
    return pair;
}

+ (NSArray*)pairsWithKey:(NSString*)key value:(id)value {
    NSMutableArray* m_queryStringComponents = [NSMutableArray array];
    if([value isKindOfClass:[NSDictionary class]]) {
        [value enumerateKeysAndObjectsUsingBlock:^(id nestedKey, id nestedValue, BOOL *stop) {
            [m_queryStringComponents addObjectsFromArray:[QueryStringPair pairsWithKey:key ? [NSString stringWithFormat:@"%@[%@]", key, nestedKey] : nestedKey
                                                                                 value:nestedValue]];
        }];
    }
    else if([value isKindOfClass:[NSArray class]]) {
        [value enumerateObjectsUsingBlock:^(id nestedValue, NSUInteger idx, BOOL *stop) {
            [m_queryStringComponents addObjectsFromArray:[QueryStringPair pairsWithKey:[NSString stringWithFormat:@"%@[]", key]
                                                                                 value:nestedValue]];
        }];
    }
    else if([value isKindOfClass:[NSString class]]) {
        [m_queryStringComponents addObject:[QueryStringPair withField:key
                                                                value:value]];
    }
    else {
        [m_queryStringComponents addObject:[QueryStringPair withField:key
                                                                value:[value description]]];
    }
    return [NSArray arrayWithArray:m_queryStringComponents];
}

- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding {
    return [NSString stringWithFormat:@"%@=%@",
            [QueryStringPair percentEscapedQueryStringPairMemberFromString:self.field withEncoding:stringEncoding],
            [QueryStringPair percentEscapedQueryStringPairMemberFromString:self.value withEncoding:stringEncoding]];
}

+ (NSString*)percentEscapedQueryStringPairMemberFromString:(NSString*)string withEncoding:(NSStringEncoding)encoding {
    static NSString * const kAFLegalCharactersToBeEscaped = @":/.?&=;+!@$()~";
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, (CFStringRef)kAFLegalCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(encoding)));
}

@end

@interface ClientResponse ()

@property (copy, nonatomic) NSHTTPURLResponse* __nonnull HTTPResponse;
@property (copy, nonatomic) NSData* __nonnull output;

@end

@implementation ClientResponse

+ (ClientResponse* __nonnull)withHTTPResponse:(NSHTTPURLResponse* __nonnull)HTTPResponse output:(NSData* __nonnull)output {
    ClientResponse* response = [ClientResponse new];
    response.HTTPResponse = HTTPResponse;
    response.output = output;
    return response;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return self;
}

@end

@interface ClientError ()

@property (nonatomic) NSInteger statusCode;
@property (copy, nonatomic) NSString* __nullable urlString;
@property (copy, nonatomic) NSDictionary* __nullable headers;
@property (copy, nonatomic) NSString* __nullable outputString;
@property (copy, nonatomic) NSDictionary* __nullable serverErrors;
@property (copy, nonatomic) NSError* __nonnull networkError;

@end

@implementation ClientError

+ (ClientError*)withStatusCode:(NSInteger)statusCode urlString:(NSString*)urlString headers:(NSDictionary*)headers outputString:(NSString*)outputString serverErrors:(NSDictionary*)serverErrors networkError:(NSError*)networkError {
    ClientError* error = [ClientError new];
    error.statusCode = statusCode;
    error.urlString = urlString;
    error.headers = headers;
    error.outputString = outputString;
    error.serverErrors = serverErrors;
    error.networkError = networkError;
    return error;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return self;
}

@end

@interface RequestParameterEncoding ()

@property (nonatomic) RequestParameterEncodingType type;
@property (copy, nonatomic) NSString* __nonnull(^ __nullable customEncodingBlock)(NSDictionary* __nonnull);

@end

@implementation RequestParameterEncoding

+ (RequestParameterEncoding* __nonnull)withType:(RequestParameterEncodingType)type customWithEncodingBlock:(NSString* __nonnull(^ __nullable)(NSDictionary* __nonnull))customEncodingBlock {
    RequestParameterEncoding* parameterEncoding = [RequestParameterEncoding new];
    parameterEncoding.type = type;
    parameterEncoding.customEncodingBlock = customEncodingBlock;
    return parameterEncoding;
}

+ (RequestParameterEncoding* __nonnull)JSON {
    return [RequestParameterEncoding withType:RequestParameterEncodingTypeJSON customWithEncodingBlock:nil];
}

+ (RequestParameterEncoding* __nonnull)form {
    return [RequestParameterEncoding withType:RequestParameterEncodingTypeForm customWithEncodingBlock:nil];
}

+ (RequestParameterEncoding* __nonnull)customWithEncodingBlock:(NSString* __nonnull(^ __nonnull)(NSDictionary* __nonnull))customEncodingBlock {
    return [RequestParameterEncoding withType:RequestParameterEncodingTypeCustom customWithEncodingBlock:customEncodingBlock];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return self;
}

@end

@interface GenericClient () <NSURLConnectionDataDelegate>

@property (copy, nonatomic) NSString* urlString;
@property (copy, nonatomic) RequestParameterEncoding* parameterEncoding;
@property (copy, nonatomic) NSDictionary* customHeaders;
@property NSMutableData* m_dataBucket;
@property (nonatomic) Future* currentFuture;
@property (nonatomic) NSURLConnection* currentConnection;
@property (nonatomic) NSHTTPURLResponse* currentResponse;

@end

@implementation GenericClient

+ (GenericClient*)withURLString:(NSString* __nonnull)urlString {
    return [GenericClient withURLString:urlString parameterEncoding:[RequestParameterEncoding JSON] customHeaders:nil];
}

+ (GenericClient*)withURLString:(NSString* __nonnull)urlString parameterEncoding:(RequestParameterEncoding* __nonnull)parameterEncoding  {
    return [GenericClient withURLString:urlString parameterEncoding:parameterEncoding customHeaders:nil];
}

+ (GenericClient*)withURLString:(NSString*__nonnull)urlString parameterEncoding:(RequestParameterEncoding* __nonnull)parameterEncoding customHeaders:(NSDictionary* __nullable)customHeaders {
    GenericClient* client = [GenericClient new];
    client.urlString = urlString;
    client.parameterEncoding = parameterEncoding;
    client.customHeaders = customHeaders;
    return client;
}

- (void)clean {
    self.currentFuture = nil;
    self.m_dataBucket = nil;
    self.currentConnection = nil;
    self.currentResponse = nil;
}

- (Future*)getRequestWithParameters:(NSDictionary * __nullable)parameters {
    return [self HTTPRequestWithMethod:@"GET" parameters:parameters];
}

- (Future*)postRequestWithParameters:(NSDictionary * __nullable)parameters {
    return [self HTTPRequestWithMethod:@"POST" parameters:parameters];
}

- (Future*)HTTPRequestWithMethod:(NSString* __nonnull)method parameters:(NSDictionary* __nullable)parameters {
    if (self.currentConnection != nil) {
        [self.currentConnection cancel];
    }
    
    NSString* urlString = self.urlString;
    NSString* parametersString = parameters != nil ? [self parametersStringWithParameters:parameters] : nil;
    
    if (parametersString.length > 0 && [method isEqualToString:@"GET"]) {
        urlString = [urlString stringByAppendingFormat:@"?%@", parametersString];
    }
    
    NSMutableURLRequest* m_request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    m_request.HTTPMethod = method;
    
    if (parametersString.length > 0 && [method isEqualToString:@"POST"]) {
        m_request.HTTPBody = [parametersString dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    NSString *charset = (NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    switch (self.parameterEncoding.type) {
        case RequestParameterEncodingTypeJSON:
            [m_request setValue:[NSString stringWithFormat:@"application/json; charset=%@", charset] forHTTPHeaderField:@"Content-Type"];
            break;
        case RequestParameterEncodingTypeForm:
            [m_request setValue:[NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@", charset] forHTTPHeaderField:@"Content-Type"];
            break;
        default:
            break;
    }
    
    if (self.customHeaders) {
        [self.customHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [m_request setValue:obj forHTTPHeaderField:key];
        }];
    }
    
    self.currentFuture = [Future new];
    self.m_dataBucket = [NSMutableData new];
    self.currentConnection = [NSURLConnection connectionWithRequest:m_request delegate:self];
    [self.currentConnection start];
    
    return self.currentFuture;
}

- (NSString* __nullable)parametersStringWithParameters:(NSDictionary* __nonnull)parameters {
    if (parameters.count == 0) {
        return nil;
    }
    switch (self.parameterEncoding.type) {
        case RequestParameterEncodingTypeForm: {
            return [GenericClient queryStringFromDict:parameters];
//            NSString*(^percentEscapedStringForQueryString)(NSString*) = ^NSString*(NSString* string) {
//                NSString* legalCharactersToBeEscaped = @":/.?&=;+!@$()~";
//                return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, (CFStringRef)legalCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding)));
//            };
//            return [@"?" stringByAppendingString:
//                    [[parameters
//                      reduceWithStartingElement:@[] reduceBlock:^NSArray*(NSArray* accumulator, id key, id object) {
//                          if ([key isKindOfClass:[NSString class]] == NO || [object isKindOfClass:[NSString class]] == NO) {
//                              return accumulator;
//                          }
//                          else {
//                              NSString* keyString = percentEscapedStringForQueryString((NSString*)key);
//                              NSString* objectString = percentEscapedStringForQueryString((NSString*)object);
//                              return [accumulator arrayByAddingObject:[NSString stringWithFormat:@"%@=%@", keyString, objectString]];
//                          }
//                      }]
//                     componentsJoinedByString:@"&"]];
            
            break;
        }
        case RequestParameterEncodingTypeJSON: {
            return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil] encoding:NSUTF8StringEncoding];
            break;
        }
        case RequestParameterEncodingTypeCustom: {
            if (self.parameterEncoding.customEncodingBlock) {
                return self.parameterEncoding.customEncodingBlock(parameters);
            }
            else {
                return nil;
            }
            break;
        }
        default:
            return nil;
            break;
    }
}

#pragma mark - utility

+ (NSString* __nonnull)queryStringFromDict:(NSDictionary* __nonnull)dict {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (QueryStringPair* pair in [QueryStringPair pairsWithKey:nil value:dict]) {
        [mutablePairs addObject:[pair URLEncodedStringValueWithEncoding:NSUTF8StringEncoding]];
    }
    return [mutablePairs componentsJoinedByString:@"&"];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.currentResponse = (NSHTTPURLResponse*)response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.m_dataBucket appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSData* responseData = [self.m_dataBucket copy];
    [self.currentFuture succeedWith:[ClientResponse withHTTPResponse:self.currentResponse output:responseData]];
    [self clean];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.currentFuture failWith:[ClientError withStatusCode:self.currentResponse.statusCode
                                                   urlString:connection.currentRequest.URL.absoluteString
                                                     headers:self.currentResponse.allHeaderFields
                                                outputString:nil
                                                serverErrors:nil
                                                networkError:error]];
    [self clean];
}

@end
