#import "GenericClient+OutputHandling.h"
#import <Tools/Tools.h>

NS_ASSUME_NONNULL_BEGIN

@interface ErrorPair ()

@property (copy, nonatomic) NSString* name;
@property (copy, nonatomic) NSString* message;
@property (nonatomic, readonly) NSDictionary* keyValuePair;

@end

NS_ASSUME_NONNULL_END

@implementation ErrorPair

+ (ErrorPair*)withName:(NSString*)name
               message:(NSString*)message
{
  ErrorPair* pair = [ErrorPair new];
  pair.name = name;
  pair.message = message;
  return pair;
}

- (NSDictionary*)keyValuePair
{
  return @{self.name : self.message};
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"%@: %@", self.name, self.message];
}

- (instancetype)copyWithZone:(NSZone *)zone
{
  return [ErrorPair
          withName:self.name
          message:self.message];
}

@end

typedef NSArray*(^ErrorHandlingBlock)(NSDictionary*);

@implementation GenericClient (OutputHandling)

/// Either<requiredOutputClass,ClientError>
+ (Either*)outputFromClientResponse:(ClientResponse*)response
                       requiredType:(OutputType)requiredType
                 errorHandlingBlock:(NSArray*(^)(NSDictionary*))errorHandlingBlock
{
  BOOL requiredNonEmpty = requiredType != OutputTypeEmpty;
  
  /// errors validation for output dict
  NSDictionary* _Nullable(^errorsDictFromOutputDict)(NSDictionary* _Nonnull, ErrorHandlingBlock _Nullable) = ^NSDictionary*(NSDictionary* outputDict, ErrorHandlingBlock errorBlock) {
    Guard(errorBlock != nil, { return nil; })
    
    NSArray* errors = errorBlock(outputDict);
    
    Guard(errors.count > 0, { return nil; })
    
    return [errors
            mapToDictionary:^NSDictionary* (ErrorPair* pair) {
              return pair.keyValuePair;
            }];
  };
  
  return [[[[[[Either rightWith:response]
              
              /// status code validation
              flatMap:^Either*(ClientResponse* clientResponse) {
                NSInteger statusCode = clientResponse.HTTPResponse.statusCode;
                if (statusCode < 200 || statusCode > 299)
                {
                  
                  /// check if there's any error
                  Optional* optionalErrors = [[[[Optional
                                                 with:clientResponse.output]
                                                
                                                /// output into json
                                                flatMap:^Optional*(NSData* outputData) {
                                                  return [Optional with:[NSJSONSerialization
                                                                         JSONObjectWithData:outputData
                                                                         options:NSJSONReadingAllowFragments
                                                                         error:nil]];
                                                }]
                                               
                                               /// json to dict
                                               flatMap:^Optional*(id outputObject) {
                                                 return [Optional
                                                         with:outputObject
                                                         as:[NSDictionary class]];
                                               }]
                                              
                                              /// dict to errors
                                              flatMap:^Optional *(NSDictionary* outputDict) {
                                                return [Optional with:errorsDictFromOutputDict(outputDict, errorHandlingBlock)];
                                              }];
                  
                  return [Either
                          leftWith:[ClientError
                                    withStatusCode:statusCode
                                    urlString:clientResponse.HTTPResponse.URL.absoluteString
                                    headers:clientResponse.HTTPResponse.allHeaderFields
                                    outputString:[[[Optional
                                                    with:clientResponse.output]
                                                   flatMap:^Optional*(NSData* output) {
                                                     return [Optional
                                                             with:[[NSString alloc]
                                                                   initWithData:output
                                                                   encoding:NSUTF8StringEncoding]];
                                                   }]
                                                  get]
                                    serverErrors:optionalErrors.get
                                    networkError:nil]];
                }
                else
                {
                  return [Either rightWith:clientResponse];
                }
              }]
             
             /// empty output validation
             flatMap:^Either*(ClientResponse* clientResponse)
             {
               NSData* output = clientResponse.output;
               if (requiredNonEmpty && output.length == 0)
               {
                 return [Either
                         leftWith:[ClientError
                                   withStatusCode:clientResponse.HTTPResponse.statusCode
                                   urlString:clientResponse.HTTPResponse.URL.absoluteString
                                   headers:clientResponse.HTTPResponse.allHeaderFields
                                   outputString:@""
                                   serverErrors:nil
                                   networkError:nil]];
               }
               else
               {
                 return [Either rightWith:output];
               }
             }]
            
            /// json verification
            flatMap:^Either*(NSData* output) {
              if (output.length == 0)
              {
                switch (requiredType)
                {
                  case OutputTypeEmpty:
                  case OutputTypeDictionary:
                    return [Either rightWith:[NSDictionary dictionary]];
                    break;
                  case OutputTypeArray:
                    return [Either rightWith:[NSArray array]];
                  case OutputTypeString:
                    return [Either rightWith:@""];
                  case OutputTypeNumber:
                    return [Either rightWith:@0];
                    break;
                }
              }
              NSError* jsonError = nil;
              id outputObject = [NSJSONSerialization
                                 JSONObjectWithData:output
                                 options:NSJSONReadingAllowFragments
                                 error:&jsonError];
              if (jsonError != nil)
              {
                return [Either
                        leftWith:[ClientError
                                  withStatusCode:0
                                  urlString:response.HTTPResponse.URL.absoluteString
                                  headers:nil
                                  outputString:[[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding]
                                  serverErrors:nil
                                  networkError:jsonError]];
              }
              else
              {
                return [Either rightWith:outputObject];
              }
            }]
           
           /// output type verification
           flatMap:^Either *(id outputObject)
           {
             Class classToCheck = nil;
             switch (requiredType)
             {
               case OutputTypeEmpty:
               case OutputTypeDictionary:
                 classToCheck = [NSDictionary class];
                 break;
               case OutputTypeArray:
                 classToCheck = [NSArray class];
                 break;
               case OutputTypeString:
                 classToCheck = [NSString class];
                 break;
               case OutputTypeNumber:
                 classToCheck = [NSNumber class];
                 break;
             }
             if ([outputObject isKindOfClass:classToCheck])
             {
               return [Either rightWith:outputObject];
             }
             else
             {
               
               /// check if there's any error
               Optional* optionalErrors = [[[Optional
                                             with:outputObject]
                                            
                                            /// output object to dict
                                            flatMap:^Optional*(id outputObject) {
                                              if ([outputObject isKindOfClass:[NSDictionary class]])
                                              {
                                                return [Optional with:outputObject];
                                              }
                                              else
                                              {
                                                return [Optional with:nil];
                                              }
                                            }]
                                           
                                           /// dict to errors
                                           flatMap:^Optional*(NSDictionary* outputDict) {
                                             if (errorHandlingBlock != nil)
                                             {
                                               return [Optional with:errorsDictFromOutputDict(outputDict, errorHandlingBlock)];
                                             }
                                             else
                                             {
                                               return [Optional with:nil];
                                             }
                                           }];
               
               return [Either
                       leftWith:[ClientError
                                 withStatusCode:response.HTTPResponse.statusCode
                                 urlString:response.HTTPResponse.URL.absoluteString
                                 headers:response.HTTPResponse.allHeaderFields
                                 outputString:nil
                                 serverErrors:[[[NSDictionary dictionary]
                                                key:@"type error"
                                                optional:[NSString stringWithFormat:@"Object '%@' is not kind of class '%@'", outputObject, classToCheck]]
                                               optionalDict:optionalErrors.get]
                                 networkError:nil]];
             }
           }]
          
          /// output errors verification
          flatMap:^Either*(id outputObject) {
            if ([outputObject isKindOfClass:[NSDictionary class]] && errorHandlingBlock != nil)
            {
              NSDictionary* outputErrors = errorsDictFromOutputDict((NSDictionary*)outputObject,errorHandlingBlock);
              if (outputErrors.count > 0)
              {
                return [Either
                        leftWith:[ClientError
                                  withStatusCode:response.HTTPResponse.statusCode
                                  urlString:response.HTTPResponse.URL.absoluteString
                                  headers:response.HTTPResponse.allHeaderFields
                                  outputString:nil
                                  serverErrors:outputErrors
                                  networkError:nil]];
              }
            }
            return [Either rightWith:outputObject];
          }];
}

/// NSArray<ErrorPair>
+ (NSArray*(^)(NSDictionary*))standardErrorHandlingBlockWithKey:(NSString*)key
{
  return ^NSArray*(NSDictionary* outputDict) {
    id errorsObject = [outputDict objectForKey:key];
    if (errorsObject == nil)
    {
      return nil;
    }
    if ([errorsObject isKindOfClass:[NSDictionary class]])
    {
      return [(NSDictionary*)errorsObject
              mapToArray:^id(id key, id object) {
                return [ErrorPair withName:key message:object];
              }
              sortedWith:^NSComparisonResult(id object1, id object2) {
                return [((ErrorPair*)object1).name compare:((ErrorPair*)object2).name];
              }];
    }
    else if ([errorsObject isKindOfClass:[NSArray class]])
    {
      return [(NSArray*)errorsObject map:^id(id object) {
        return [ErrorPair withName:object message:@""];
      }];
    }
    else
    {
      return nil;
    }
  };
}

@end
