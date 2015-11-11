#import "GenericClient.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OutputType)
{
    OutputTypeEmpty,
    OutputTypeDictionary,
    OutputTypeArray,
    OutputTypeString,
    OutputTypeNumber
};

@class Either;

@interface ErrorPair : NSObject <NSCopying>

@property (copy, nonatomic, readonly) NSString* name;
@property (copy, nonatomic, readonly) NSString* message;

+ (ErrorPair*)withName:(NSString*)name
               message:(NSString*)message;

@end

@interface GenericClient (OutputHandling)

/// output: Either<requiredOutputClass,ClientError>
/// errorHandlingBlock: NSArray<ErrorPair>
+ (Either* _Nullable)outputFromClientResponse:(ClientResponse*)response
                         validHTTPStatusCodes:(NSArray*)validCodes
                           requiredOutputType:(OutputType)requiredType
                           errorHandlingBlock:(NSArray* _Nullable(^ _Nullable)(NSDictionary*))errorHandlingBlock;


/// output: NSArray<ErrorPair>
+ (NSArray* _Nullable(^ _Nullable)(NSDictionary*))standardErrorHandlingBlockWithKey:(NSString*)key;

+ (NSArray*)standardValidHTTPStatusCodes;

@end

NS_ASSUME_NONNULL_END
