
#import <Foundation/Foundation.h>

@interface CodeCoordinate : NSObject

@property (nonatomic, readonly) const char * method;
@property (nonatomic, readonly) const char * file;
@property (nonatomic, readonly) NSInteger line;

+ (CodeCoordinate*)coordinateWithMethod:(const char *)method file:(const char *)file line:(NSInteger)line;

#define kCodeCoordinateHere [CodeCoordinate coordinateWithMethod:__FUNCTION__ file:__FILE__ line:__LINE__]

@end

