#import "GenericClient.h"

typedef NS_ENUM(NSInteger, OutputType) {
    OutputTypeEmpty,
    OutputTypeDictionary,
    OutputTypeArray,
    OutputTypeString,
    OutputTypeNumber
};

@class Result;

@interface ErrorPair : NSObject <NSCopying>

@property (copy, nonatomic, readonly) NSString* __nonnull name;
@property (copy, nonatomic, readonly) NSString* __nullable message;

+ (ErrorPair* __nonnull)withName:(NSString* __nonnull)name message:(NSString* __nullable)message;

@end

@interface GenericClient (OutputHandling)

/// output: Result<requiredOutputClass,ClientError>
/// errorHandlingBlock: NSArray<ErrorPair>
+ (Result* __nullable)outputFromClientResponse:(ClientResponse* __nonnull)response
                                  requiredType:(OutputType)requiredType
                            errorHandlingBlock:(NSArray* __nullable(^ __nullable)(NSDictionary* __nonnull))errorHandlingBlock;


/// output: NSArray<ErrorPair>
+ (NSArray* __nullable(^ __nullable)(NSDictionary* __nonnull))standardErrorHandlingBlockWithKey:(NSString* __nonnull)key;

@end
