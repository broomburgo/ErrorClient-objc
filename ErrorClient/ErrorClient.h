#import <Foundation/Foundation.h>

#import "CodeCoordinate.h"
#import "MessageEntity.h"

extern NSString* const k_errorServerURLStringUserDefaultsKey;
extern NSString* const k_customTagsKey;

@interface ErrorClient : NSObject

+ (void)setupExceptionHandler;
+ (void)sendInfo:(MessageEntity*)info;
+ (void)inCoordinate:(CodeCoordinate*)coordinate sendInfo:(MessageEntity*)info;
+ (void)sendWarning:(MessageEntity*)warning;
+ (void)inCoordinate:(CodeCoordinate*)coordinate sendWarning:(MessageEntity*)warning;
+ (void)sendError:(MessageEntity*)error;
+ (void)inCoordinate:(CodeCoordinate*)coordinate sendError:(MessageEntity*)error;

@end
