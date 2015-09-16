#import "GenericClient.h"
#import <Tools/Tools.h>
#import <Tools/Future_internal.h>

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

- (NSDictionary*)keyedDescription {
    return [[[[[[[NSDictionary dictionary]
                 key:@"url"
                 optional:self.urlString]
                key:@"status code"
                optional:@(self.statusCode)]
               key:@"headers"
               optional:self.headers]
              key:@"output"
              optional:self.outputString]
             key:@"server errors"
             optional:self.serverErrors]
            key:@"network error"
            optional:self.networkError.localizedDescription];
}

- (NSString*)description {
    return [NSString stringWithFormat:@"url: %@\nstatus code: %d\nheaders: %@\noutput: %@\nserver errors: %@\nnetwork error: %@",
            self.urlString,
            (int)self.statusCode,
            self.headers,
            self.outputString,
            self.serverErrors,
            self.networkError.localizedDescription];
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

+ (NSDictionary*)basicAuthorizationHeaderWithUsername:(NSString*)username password:(NSString*)password {
  return @{@"Authorization" : [NSString stringWithFormat:@"Basic %@", [self base64EncodedString:[NSString stringWithFormat:@"%@:%@", username, password]]]};
}

+ (NSString*)base64EncodedString:(NSString* __nonnull)string {
  NSData *data = [NSData dataWithBytes:[string UTF8String] length:[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
  NSUInteger length = [data length];
  NSMutableData *mutableData = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
  uint8_t *input = (uint8_t *)[data bytes];
  uint8_t *output = (uint8_t *)[mutableData mutableBytes];
  for (NSUInteger i = 0; i < length; i += 3) {
    NSUInteger value = 0;
    for (NSUInteger j = i; j < (i + 3); j++) {
      value <<= 8;
      if (j < length) {
        value |= (0xFF & input[j]);
      }
    }
    static uint8_t const kAFBase64EncodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    NSUInteger idx = (i / 3) * 4;
    output[idx + 0] = kAFBase64EncodingTable[(value >> 18) & 0x3F];
    output[idx + 1] = kAFBase64EncodingTable[(value >> 12) & 0x3F];
    output[idx + 2] = (i + 1) < length ? kAFBase64EncodingTable[(value >> 6)  & 0x3F] : '=';
    output[idx + 3] = (i + 2) < length ? kAFBase64EncodingTable[(value >> 0)  & 0x3F] : '=';
  }
  return [[NSString alloc] initWithData:mutableData encoding:NSASCIIStringEncoding];
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
                                                outputString:[[[Optional
                                                                with:[self.m_dataBucket copy]]
                                                               flatMap:^Optional*(NSData* responseData) {
                                                                   return [Optional
                                                                           with:[[NSString alloc]
                                                                                 initWithData:responseData
                                                                                 encoding:NSUTF8StringEncoding]];
                                                               }]
                                                              value]
                                                serverErrors:nil
                                                networkError:error]];
    [self clean];
}

@end
