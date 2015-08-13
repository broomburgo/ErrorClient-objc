#import "GenericClient+OutputHandling.h"
#import "MessageEntity.h"
#import "Tools.h"

@interface ErrorPair ()

@property (copy, nonatomic) NSString* __nonnull name;
@property (copy, nonatomic) NSString* __nullable message;

@end

@implementation ErrorPair

+ (ErrorPair* __nonnull)withName:(NSString* __nonnull)name message:(NSString* __nullable)message {
    ErrorPair* pair = [ErrorPair new];
    pair.name = name;
    pair.message = message;
    return pair;
}

- (NSString*)description {
    if (self.message != nil) {
        return [NSString stringWithFormat:@"%@: %@", self.name, self.message];
    }
    else {
        return self.name;
    }
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    return [ErrorPair withName:self.name message:self.message];
}

@end

typedef NSArray* __nullable(^ErrorHandlingBlock)(NSDictionary* __nonnull);

@implementation GenericClient (OutputHandling)

/// Result<requiredOutputClass,ClientError>
+ (Result* __nullable)outputFromClientResponse:(ClientResponse* __nonnull)response
                                  requiredType:(OutputType)requiredType
                            errorHandlingBlock:(NSArray* __nullable(^ __nullable)(NSDictionary* __nonnull))errorHandlingBlock {
    
    BOOL requiredNonEmpty = requiredType != OutputTypeEmpty;
    
    /// errors validation for output dict
    NSDictionary* __nullable(^errorsDictFromOutputDict)(NSDictionary* __nonnull, ErrorHandlingBlock __nonnull) = ^NSDictionary*(NSDictionary* outputDict, ErrorHandlingBlock errorHandlignBlock){
        NSArray* errors = errorHandlingBlock(outputDict);
        if (errors.count == 0) {
            return nil;
        }
        return [errors
                mapToDictionary:^NSDictionary* (ErrorPair* pair) {
                    return [@{}
                            key:pair.name optional:pair.message ?: @""];
                }];
    };
    
    return [[[[[[Result successWith:response]
                
                /// status code validation
                flatMapResult:^Result * __nonnull(ClientResponse* __nonnull clientResponse) {
                    NSInteger statusCode = clientResponse.HTTPResponse.statusCode;
                    if (statusCode < 200 || statusCode > 299) {
                        
                        /// check if there's any error
                        Optional* optionalErrors = [[[[Optional
                                                       with:clientResponse.output]
                                                      
                                                      /// output into json
                                                      flatMapOptional:^Optional * __nonnull(NSData* __nonnull outputData) {
                                                          return [Optional with:[NSJSONSerialization JSONObjectWithData:outputData options:NSJSONReadingAllowFragments error:nil]];
                                                      }]
                                                     
                                                     /// json to dict
                                                     flatMapOptional:^Optional * __nonnull(id __nonnull outputObject) {
                                                         if ([outputObject isKindOfClass:[NSDictionary class]]) {
                                                             return [Optional with:outputObject];
                                                         }
                                                         else {
                                                             return [Optional with:nil];
                                                         }
                                                     }]
                                                    
                                                    /// dict to errors
                                                    flatMapOptional:^Optional * __nonnull(NSDictionary* __nonnull outputDict) {
                                                        if (errorHandlingBlock != nil) {
                                                            return [Optional with:errorsDictFromOutputDict(outputDict, errorHandlingBlock)];
                                                        }
                                                        else {
                                                            return [Optional with:nil];
                                                        }
                                                    }];
                        
                        return [Result failureWith:[ClientError withStatusCode:statusCode
                                                                       headers:clientResponse.HTTPResponse.allHeaderFields
                                                                  outputString:nil
                                                                  serverErrors:optionalErrors.value
                                                                  networkError:nil]];
                    }
                    else {
                        return [Result successWith:clientResponse];
                    }
                }]
               
               /// empty output validation
               flatMapResult:^Result * __nonnull(ClientResponse* __nonnull clientResponse) {
                   NSData* output = clientResponse.output;
                   if (requiredNonEmpty && output.length == 0) {
                       return [Result failureWith:[ClientError withStatusCode:clientResponse.HTTPResponse.statusCode
                                                                      headers:clientResponse.HTTPResponse.allHeaderFields
                                                                 outputString:@""
                                                                 serverErrors:nil
                                                                 networkError:nil]];
                   }
                   else {
                       return [Result successWith:output];
                   }
               }]
              
              /// json verification
              flatMapResult:^Result * __nonnull(NSData* __nonnull output) {
                  if (output.length == 0) {
                      switch (requiredType) {
                          case OutputTypeEmpty:
                          case OutputTypeDictionary:
                              return [Result successWith:@{}];
                              break;
                          case OutputTypeArray:
                              return [Result successWith:@[]];
                          case OutputTypeString:
                              return [Result successWith:@""];
                          case OutputTypeNumber:
                              return [Result successWith:@0];
                              break;
                      }
                  }
                  NSError* jsonError = nil;
                  id outputObject = [NSJSONSerialization JSONObjectWithData:output options:NSJSONReadingAllowFragments error:&jsonError];
                  if (jsonError != nil) {
                      return [Result failureWith:[ClientError withStatusCode:0
                                                                     headers:nil
                                                                outputString:[[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding]
                                                                serverErrors:nil
                                                                networkError:jsonError]];
                  }
                  else {
                      return [Result successWith:outputObject];
                  }
              }]
             
             /// output type verification
             flatMapResult:^Result * __nonnull(id __nonnull outputObject) {
                 Class classToCheck = nil;
                 switch (requiredType) {
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
                 if ([outputObject isKindOfClass:classToCheck]) {
                     return [Result successWith:outputObject];
                 }
                 else {
                     
                     /// check if there's any error
                     Optional* optionalErrors = [[[Optional
                                                   with:outputObject]
                                                  
                                                  /// output object to dict
                                                  flatMapOptional:^Optional * __nonnull(id __nonnull outputObject) {
                                                      if ([outputObject isKindOfClass:[NSDictionary class]]) {
                                                          return [Optional with:outputObject];
                                                      }
                                                      else {
                                                          return [Optional with:nil];
                                                      }
                                                  }]
                                                 
                                                 /// dict to errors
                                                 flatMapOptional:^Optional * __nonnull(NSDictionary* __nonnull outputDict) {
                                                     if (errorHandlingBlock != nil) {
                                                         return [Optional with:errorsDictFromOutputDict(outputDict, errorHandlingBlock)];
                                                     }
                                                     else {
                                                         return [Optional with:nil];
                                                     }
                                                 }];
                     
                     return [Result failureWith:[ClientError withStatusCode:0
                                                                    headers:nil
                                                               outputString:nil
                                                               serverErrors:[[@{}
                                                                              key:@"type error" optional:[NSString stringWithFormat:@"Object '%@' is not kind of class '%@'", outputObject, classToCheck]]
                                                                             optionalDict:optionalErrors.value]
                                                               networkError:nil]];
                 }
             }]
            
            /// output errors verification
            flatMapResult:^Result * __nonnull(id __nonnull outputObject) {
                if ([outputObject isKindOfClass:[NSDictionary class]] && errorHandlingBlock != nil) {
                    NSDictionary* outputErrors = errorsDictFromOutputDict((NSDictionary*)outputObject,errorHandlingBlock);
                    if (outputErrors.count > 0) {
                        return [Result failureWith:[ClientError withStatusCode:0
                                                                       headers:nil
                                                                  outputString:nil
                                                                  serverErrors:outputErrors
                                                                  networkError:nil]];
                    }
                }
                return [Result successWith:outputObject];
            }];
}

/// NSArray<ErrorPair>
+ (NSArray* __nullable(^ __nullable)(NSDictionary* __nonnull))standardErrorHandlingBlockWithKey:(NSString* __nonnull)key {
    return ^NSArray* (NSDictionary* outputDict) {
        id errorsObject = [outputDict objectForKey:key];
        if (errorsObject == nil) {
            return nil;
        }
        if ([errorsObject isKindOfClass:[NSDictionary class]]) {
            return [(NSDictionary*)errorsObject
                    mapToArray:^id(id key, id object) {
                        return [ErrorPair withName:key message:object];
                    }
                    sortedUsingComparator:^NSComparisonResult(id object1, id object2) {
                        return [((ErrorPair*)object1).name compare:((ErrorPair*)object2).name];
                    }];
        }
        else if ([errorsObject isKindOfClass:[NSArray class]]) {
            return [(NSArray*)errorsObject map:^id(id object) {
                return [ErrorPair withName:object message:nil];
            }];
        }
        else {
            return nil;
        }
    };
}

@end
