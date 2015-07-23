#import <Foundation/Foundation.h>

#import "CodeCoordinate.h"
#import "ErrorEntity.h"

extern NSString* const k_errorServerURLStringUserDefaultsKey;

@interface ErrorClient : NSObject

+ (void)setupExceptionHandler;
+ (void)sendInfo:(NSString*)info;
+ (void)inCoordinate:(CodeCoordinate*)coordinate sendInfo:(NSString*)info;
+ (void)sendWarning:(NSString*)warning;
+ (void)inCoordinate:(CodeCoordinate*)coordinate sendWarning:(NSString*)warning;
+ (void)sendError:(ErrorEntity*)error;
+ (void)inCoordinate:(CodeCoordinate*)coordinate sendError:(ErrorEntity*)error;

@end
