#import <Foundation/Foundation.h>

#import "CodeCoordinate.h"
#import "ErrorEntity.h"

extern NSString* const k_errorServerURLStringUserDefaultsKey;

@interface ErrorClient : NSObject

+ (void)setupExceptionHandler;
+ (void)sendInfo:(NSString*)info;
+ (void)sendInfo:(NSString*)info coordinate:(CodeCoordinate*)coordinate;
+ (void)sendWarning:(NSString*)warning;
+ (void)sendWarning:(NSString*)warning coordinate:(CodeCoordinate*)coordinate;
+ (void)sendError:(ErrorEntity*)error;
+ (void)sendError:(ErrorEntity*)error coordinate:(CodeCoordinate*)coordinate;

@end
