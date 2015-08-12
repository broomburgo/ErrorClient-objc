#import <Foundation/Foundation.h>

@class CodeCoordinate;
@class MessageEntity;

extern NSString* const kErrorServerURLStringUserDefaultsKey;
extern NSString* const kCustomTagsKey;

@interface ErrorClient : NSObject

+ (void)setupExceptionHandler;
+ (void)sendInfo:(MessageEntity*)info;
+ (void)inCoordinate:(CodeCoordinate*)coordinate sendInfo:(MessageEntity*)info;
+ (void)sendWarning:(MessageEntity*)warning;
+ (void)inCoordinate:(CodeCoordinate*)coordinate sendWarning:(MessageEntity*)warning;
+ (void)sendError:(MessageEntity*)error;
+ (void)inCoordinate:(CodeCoordinate*)coordinate sendError:(MessageEntity*)error;

@end
