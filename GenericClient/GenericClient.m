#import "GenericClient.h"
#import <Tools/Tools.h>
#import <Tools/Future_internal.h>

#pragma mark - QueryStringPair

@interface QueryStringPair : NSObject

@property (copy, nonatomic) NSString* field;
@property (copy, nonatomic) NSString* value;

+ (QueryStringPair*)withField:(NSString*)field
						value:(NSString*)value;
- (NSString*)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding;
+ (NSArray*)pairsWithKey:(NSString*)key value:(id)value;

@end

@protocol QueryStringPairable <NSObject>

- (NSArray* _Nonnull)pairsWithKey:(NSString* _Nonnull)key;

@end

@interface NSDictionary (QueryStringPair) <QueryStringPairable>

@end

@implementation NSDictionary (QueryStringPair)

- (NSArray*)pairsWithKey:(NSString*)key
{
	NSMutableArray* m_components = [NSMutableArray array];
	[self enumerateKeysAndObjectsUsingBlock:^(id nestedKey, id nestedValue, BOOL *stop) {
		[m_components addObjectsFromArray:[QueryStringPair
										   pairsWithKey:key ? [NSString stringWithFormat:@"%@[%@]", key, nestedKey] : nestedKey
										   value:nestedValue]];
	}];
	return [NSArray arrayWithArray:m_components];
}

@end

@interface NSArray (QueryStringPair) <QueryStringPairable>

@end

@implementation NSArray (QueryStringPair)

- (NSArray*)pairsWithKey:(NSString*)key
{
	NSMutableArray* m_components = [NSMutableArray array];
	[self enumerateObjectsUsingBlock:^(id nestedValue, NSUInteger idx, BOOL *stop) {
		[m_components addObjectsFromArray:[QueryStringPair
										   pairsWithKey:[NSString stringWithFormat:@"%@[]", key]
										   value:nestedValue]];
	}];
	return [NSArray arrayWithArray:m_components];
}

@end

@interface NSString (QueryStringPair) <QueryStringPairable>

@end

@implementation NSString (QueryStringPair)

- (NSArray*)pairsWithKey:(NSString*)key
{
	return [[NSArray array]
			optional:[QueryStringPair
					  withField:key
					  value:self]];
}

@end

@implementation QueryStringPair

+ (QueryStringPair*)withField:(NSString*)field value:(NSString*)value
{
	QueryStringPair* pair = [QueryStringPair new];
	pair.field = field;
	pair.value = value;
	return pair;
}

+ (NSArray*)pairsWithKey:(NSString*)key value:(id)value
{
	NSMutableArray* m_queryStringComponents = [NSMutableArray array];
	if ([value respondsToSelector:@selector(pairsWithKey:)])
	{
		[m_queryStringComponents addObjectsFromArray:[value pairsWithKey:key]];
	}
	else
	{
		[m_queryStringComponents addObject:[QueryStringPair
											withField:key
											value:[value description]]];
	}
	return [NSArray arrayWithArray:m_queryStringComponents];
}

- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding
{
	return [NSString stringWithFormat:@"%@=%@",
			[QueryStringPair
			 percentEscapedQueryStringPairMemberFromString:self.field
			 withEncoding:stringEncoding],
			[QueryStringPair
			 percentEscapedQueryStringPairMemberFromString:self.value
			 withEncoding:stringEncoding]];
}

+ (NSString*)percentEscapedQueryStringPairMemberFromString:(NSString*)string
											  withEncoding:(NSStringEncoding)encoding
{
	static NSString* const kAFLegalCharactersToBeEscaped = @":/.?&=;+!@$()~";
	return (NSString*)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, (CFStringRef)kAFLegalCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(encoding)));
}

@end

#pragma mark - ClientResponse

@interface ClientResponse ()

@property (copy, nonatomic) NSURLRequest* originalRequest;
@property (copy, nonatomic) NSHTTPURLResponse* HTTPResponse;
@property (copy, nonatomic) NSData* output;

@end

@implementation ClientResponse

+ (ClientResponse*)withOriginalRequest:(NSURLRequest*)originalRequest
						  HTTPResponse:(NSHTTPURLResponse*)HTTPResponse
								output:(NSData*)output
{
	ClientResponse* response = [ClientResponse new];
	response.originalRequest = originalRequest;
	response.HTTPResponse = HTTPResponse;
	response.output = output;
	return response;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
	return self;
}

@end

#pragma mark - ClientError

@interface ClientError ()

@property (nonatomic) NSInteger statusCode;
@property (copy, nonatomic) NSString* urlString;
@property (copy, nonatomic) NSDictionary* requestHeaders;
@property (copy, nonatomic) NSDictionary* responseHeaders;
@property (copy, nonatomic) NSString* outputString;
@property (copy, nonatomic) NSDictionary* serverErrors;
@property (copy, nonatomic) NSError* networkError;

@end

@implementation ClientError

+ (ClientError*)withStatusCode:(NSInteger)statusCode
					 urlString:(NSString*)urlString
				requestHeaders:(NSDictionary*)requestHeaders
			   responseHeaders:(NSDictionary*)responseHeaders
				  outputString:(NSString*)outputString
				  serverErrors:(NSDictionary*)serverErrors
				  networkError:(NSError*)networkError
{
	ClientError* error = [ClientError new];
	error.statusCode = statusCode;
	error.urlString = urlString;
	error.requestHeaders = requestHeaders;
	error.responseHeaders = responseHeaders;
	error.outputString = outputString;
	error.serverErrors = serverErrors;
	error.networkError = networkError;
	return error;
}

+ (ClientError*)withResponse:(ClientResponse*)response
				serverErrors:(NSDictionary*)serverErrors
				networkError:(NSError*)networkError {
	return [ClientError
			withStatusCode:response.HTTPResponse.statusCode
			urlString:response.HTTPResponse.URL.absoluteString
			requestHeaders:response.originalRequest.allHTTPHeaderFields
			responseHeaders:response.HTTPResponse.allHeaderFields
			outputString:[[[Optional
							with:response.output]
						   map:^NSString*(NSData* data){
							   return [[NSString alloc]
									   initWithData:data
									   encoding:NSUTF8StringEncoding];
						   }]
						  get]
			serverErrors:serverErrors
			networkError:networkError];
}

- (NSError *)globalError {
	NSError* basicError = [[Optional with:self.networkError] getOrElse:^NSError*{
		return [NSError
				errorWithDomain:@"ClientError"
				code:self.statusCode
				userInfo:nil];
	}];
	NSMutableDictionary* m_basicUserInfo = [[NSMutableDictionary dictionary]
											optionalDict:basicError.userInfo];
	[m_basicUserInfo key:@"status code" optional:@(self.statusCode)];
	[m_basicUserInfo key:@"url string" optional:self.urlString];
	[m_basicUserInfo key:@"request headers" optional:self.requestHeaders];
	[m_basicUserInfo key:@"response headers" optional:self.responseHeaders];
	[m_basicUserInfo key:@"output string" optional:self.outputString];
	[m_basicUserInfo key:@"server errors" optional:self.serverErrors];

	return [NSError
			errorWithDomain:basicError.domain
			code:basicError.code
			userInfo:[NSDictionary dictionaryWithDictionary:m_basicUserInfo]];
}

- (NSDictionary*)keyedDescription
{
	return [[[[[[[[NSDictionary dictionary]
				  key:@"url"
				  optional:self.urlString]
				 key:@"status code"
				 optional:@(self.statusCode)]
				key:@"request headers"
				optional:self.requestHeaders]
			   key:@"response headers"
			   optional:self.responseHeaders]
			  key:@"output"
			  optional:self.outputString]
			 key:@"server errors"
			 optional:self.serverErrors]
			key:@"network error"
			optional:self.networkError.localizedDescription];
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"url: %@\nstatus code: %d\nrequest headers: %@\nresponse headers: %@\noutput: %@\nserver errors: %@\nnetwork error: %@",
			self.urlString,
			(int)self.statusCode,
			self.requestHeaders,
			self.responseHeaders,
			self.outputString,
			self.serverErrors,
			self.networkError.localizedDescription];
}

- (instancetype)copyWithZone:(NSZone *)zone
{
	return self;
}

@end

#pragma mark - RequestParameterEncoding

@interface RequestParameterEncoding ()

@property (nonatomic) RequestParameterEncodingType type;
@property (copy, nonatomic) NSString*(^ customEncodingBlock)(NSDictionary*);

@end

@implementation RequestParameterEncoding

+ (RequestParameterEncoding*)withType:(RequestParameterEncodingType)type
			  customWithEncodingBlock:(NSString*(^)(NSDictionary*))customEncodingBlock
{
	RequestParameterEncoding* parameterEncoding = [RequestParameterEncoding new];
	parameterEncoding.type = type;
	parameterEncoding.customEncodingBlock = customEncodingBlock;
	return parameterEncoding;
}

+ (RequestParameterEncoding*)JSON
{
	return [RequestParameterEncoding
			withType:RequestParameterEncodingTypeJSON
			customWithEncodingBlock:nil];
}

+ (RequestParameterEncoding*)form
{
	return [RequestParameterEncoding
			withType:RequestParameterEncodingTypeForm
			customWithEncodingBlock:nil];
}

+ (RequestParameterEncoding*)customWithEncodingBlock:(NSString*(^)(NSDictionary*))customEncodingBlock
{
	return [RequestParameterEncoding
			withType:RequestParameterEncodingTypeCustom
			customWithEncodingBlock:customEncodingBlock];
}

- (instancetype)copyWithZone:(NSZone *)zone
{
	return self;
}

@end

#pragma mark - GenericClient

static BOOL GenericClientLogActive = NO;

@interface GenericClient () <NSURLConnectionDataDelegate>

@property (copy, nonatomic) NSString* urlString;
@property (copy, nonatomic) RequestParameterEncoding* parameterEncoding;
@property (copy, nonatomic) NSDictionary* customHeaders;
@property (copy, nonatomic) NSArray<NSString*>* trustedHosts;
@property (nonatomic) NSMutableData* m_dataBucket;
@property (nonatomic) Future* currentFuture;
@property (nonatomic) NSURLConnection* currentConnection;
@property (nonatomic) NSHTTPURLResponse* currentResponse;

@end

@implementation GenericClient

+ (void)setLogActive:(BOOL)logActive {
	GenericClientLogActive = logActive;
}

+ (GenericClient*)withURLString:(NSString*)urlString
{
	return [GenericClient
			withURLString:urlString
			parameterEncoding:[RequestParameterEncoding JSON]
			customHeaders:nil
			trustedHosts:nil];
}

+ (GenericClient*)withURLString:(NSString*)urlString
			  parameterEncoding:(RequestParameterEncoding*)parameterEncoding
{
	return [GenericClient
			withURLString:urlString
			parameterEncoding:parameterEncoding
			customHeaders:nil
			trustedHosts:nil];
}

+ (GenericClient*)withURLString:(NSString*__nonnull)urlString parameterEncoding:(RequestParameterEncoding*)parameterEncoding customHeaders:(NSDictionary*)customHeaders
				   trustedHosts:(NSArray<NSString *>*)trustedHosts
{
	GenericClient* client = [GenericClient new];
	client.urlString = urlString;
	client.parameterEncoding = parameterEncoding;
	client.customHeaders = customHeaders;
	client.trustedHosts = trustedHosts;
	return client;
}

- (void)clean
{
	self.currentFuture = nil;
	self.m_dataBucket = nil;
	self.currentConnection = nil;
	self.currentResponse = nil;
}

- (Future*)getRequestWithParameters:(NSDictionary *)parameters
{
	return [self
			HTTPRequestWithMethod:@"GET"
			parameters:parameters];
}

- (Future*)postRequestWithParameters:(NSDictionary *)parameters
{
	return [self
			HTTPRequestWithMethod:@"POST"
			parameters:parameters];
}

- (Future*)HTTPRequestWithMethod:(NSString*)method parameters:(NSDictionary*)parameters
{
	[self.currentConnection cancel];

	NSString* urlString = [self.urlString
						   stringByAppendingString:[self
													queryStringForMethod:method
													parameters:parameters]];
	NSString* parametersString = [self
								  parametersStringForMethod:method
								  parameters:parameters];

	NSMutableURLRequest* m_request = [[NSMutableURLRequest
									   requestWithURL:[NSURL URLWithString:urlString]
									   cachePolicy:NSURLRequestReloadIgnoringCacheData
									   timeoutInterval:60]
									  setup:^(NSMutableURLRequest* m_request) {
										  m_request.HTTPMethod = method;
										  m_request.HTTPBody = [[[Optional with:parametersString]
																 flatMap:^Optional*(NSString* parametersString) {
																	 return [Optional
																			 with:[parametersString
																				   dataUsingEncoding:NSUTF8StringEncoding]];
																 }]
																get];
										  [self setupMutableRequestHeaders:m_request];
									  }];

	if (GenericClientLogActive) {
		NSLog(@"%@ - will send request\n%@\n%@\nHeaders: %@\nBody: %@",
			  self,
			  m_request.URL,
			  m_request.HTTPMethod,
			  [[[[Optional with:m_request.allHTTPHeaderFields]
				 flatMap:^Optional*(NSDictionary* headers) {
					 return [Optional with:[NSJSONSerialization
											dataWithJSONObject:headers
											options:NSJSONWritingPrettyPrinted
											error:nil]];
				 }]
				flatMap:^Optional*(NSData* data) {
					return [Optional with:[[NSString alloc]
										   initWithData:data
										   encoding:NSUTF8StringEncoding]];
				}]
			   get],
			  [[NSString alloc] initWithData:m_request.HTTPBody encoding:NSUTF8StringEncoding]);
	}

	self.currentFuture = [Future new];
	self.m_dataBucket = [NSMutableData new];
	self.currentConnection = [NSURLConnection connectionWithRequest:m_request delegate:self];
	[self.currentConnection start];

	return self.currentFuture;
}

#pragma mark - utility

- (NSString* _Nonnull)queryStringForMethod:(NSString* _Nonnull)method
								parameters:(NSDictionary* _Nullable)parameters
{
	Guard([method isEqualToString:@"GET"] && parameters.count > 0, { return @""; })
	return [@"?" stringByAppendingString:[GenericClient queryStringFromDict:parameters]];
}

- (NSString* _Nullable)parametersStringForMethod:(NSString* _Nonnull)method
									  parameters:(NSDictionary*)parameters
{
	Guard([method isEqualToString:@"POST"] && parameters.count > 0, { return nil; })

	switch (self.parameterEncoding.type)
	{
		case RequestParameterEncodingTypeForm:
		{
			return [GenericClient queryStringFromDict:parameters];
			break;
		}
		case RequestParameterEncodingTypeJSON:
		{
			return [[NSString alloc]
					initWithData:[NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil]
					encoding:NSUTF8StringEncoding];
			break;
		}
		case RequestParameterEncodingTypeCustom:
		{
			Guard(self.parameterEncoding.customEncodingBlock != nil, { return nil; })

			return self.parameterEncoding.customEncodingBlock(parameters);
			break;
		}
		default:
			return nil;
			break;
	}
}

- (NSMutableURLRequest* _Nonnull)setupMutableRequestHeaders:(NSMutableURLRequest* _Nonnull)m_request
{
	[m_request setValue:@"gzip, deflate" forHTTPHeaderField:@"Accept-Encoding"];
	[m_request setValue:@"*/*" forHTTPHeaderField:@"Accept"];

	NSString *charset = (NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));

	switch (self.parameterEncoding.type)
	{
		case RequestParameterEncodingTypeJSON:
			[m_request setValue:[NSString stringWithFormat:@"application/json; charset=%@", charset] forHTTPHeaderField:@"Content-Type"];
			break;
		case RequestParameterEncodingTypeForm:
			[m_request setValue:[NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@", charset] forHTTPHeaderField:@"Content-Type"];
			break;
		default:
			break;
	}

	[self.customHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		[m_request setValue:obj forHTTPHeaderField:key];
	}];

	return m_request;
}

+ (NSString*)queryStringFromDict:(NSDictionary*)dict
{
	return [[[QueryStringPair
			  pairsWithKey:nil
			  value:dict]
			 map:^NSString*(QueryStringPair* pair) {
				 return [pair URLEncodedStringValueWithEncoding:NSUTF8StringEncoding];
			 }]
			componentsJoinedByString:@"&"];
}

+ (NSDictionary*)basicAuthorizationHeaderWithUsername:(NSString*)username password:(NSString*)password
{
	return @{@"Authorization" : [NSString stringWithFormat:@"Basic %@", [self base64EncodedString:[NSString stringWithFormat:@"%@:%@", username, password]]]};
}

+ (NSString*)base64EncodedString:(NSString*)string
{
	NSData *data = [NSData dataWithBytes:[string UTF8String] length:[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
	NSUInteger length = [data length];
	NSMutableData *mutableData = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
	uint8_t *input = (uint8_t *)[data bytes];
	uint8_t *output = (uint8_t *)[mutableData mutableBytes];
	for (NSUInteger i = 0; i < length; i += 3)
	{
		NSUInteger value = 0;
		for (NSUInteger j = i; j < (i + 3); j++)
		{
			value <<= 8;
			if (j < length)
			{
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
	return [[NSString alloc]
			initWithData:mutableData
			encoding:NSASCIIStringEncoding];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	if (GenericClientLogActive) {
		NSLog(@"%@ - did receive response: %@", self, response);
	}
	self.currentResponse = (NSHTTPURLResponse*)response;
}

- (void)connection:(NSURLConnection *)connection
	didReceiveData:(NSData *)data
{
	[self.m_dataBucket appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSData* responseData = [self.m_dataBucket copy];

	if (GenericClientLogActive) {
		NSLog(@"%@ - did load data: %@", self, [[NSString alloc]
												initWithData:responseData
												encoding:NSUTF8StringEncoding]);
	}

	[self.currentFuture
	 succeedWith:[ClientResponse
				  withOriginalRequest:connection.originalRequest
				  HTTPResponse:self.currentResponse
				  output:responseData]];
	[self clean];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
	if (GenericClientLogActive) {
		NSLog(@"%@ - did fail with error: %@", self, error);
	}

	[self.currentFuture
	 failWith:[ClientError
			   withStatusCode:self.currentResponse.statusCode
			   urlString:connection.currentRequest.URL.absoluteString
			   requestHeaders:connection.originalRequest.allHTTPHeaderFields
			   responseHeaders:self.currentResponse.allHeaderFields
			   outputString:[[[Optional
							   with:[self.m_dataBucket copy]]
							  flatMap:^Optional*(NSData* responseData) {
								  return [Optional
										  with:[[NSString alloc]
												initWithData:responseData
												encoding:NSUTF8StringEncoding]];
							  }]
							 get]
			   serverErrors:nil
			   networkError:error]];
	[self clean];
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
	Guard([self.trustedHosts containsObject:challenge.protectionSpace.host], {
		[[challenge sender] performDefaultHandlingForAuthenticationChallenge:challenge];
		return;
	})
	[[challenge sender]
	 useCredential:[NSURLCredential
					credentialForTrust:challenge.protectionSpace.serverTrust]
	 forAuthenticationChallenge:challenge];
}

@end
