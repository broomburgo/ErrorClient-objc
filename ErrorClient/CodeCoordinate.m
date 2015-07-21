#import "CodeCoordinate.h"

@interface CodeCoordinate ()

@property (nonatomic) NSString* method_;
@property (nonatomic) NSString* file_;
@property (nonatomic) NSInteger line;

@end

@implementation CodeCoordinate

+ (CodeCoordinate*)coordinateWithMethod:(const char *)method file:(const char *)file line:(NSInteger)line {
    CodeCoordinate* coordinate = [CodeCoordinate new];
    coordinate.method_ = method ? [NSString stringWithUTF8String:method] : nil;
    coordinate.file_ = file ? [NSString stringWithUTF8String:file] : nil;
    coordinate.line = line;
    return coordinate;
}

- (const char *)method {
    return self.method_ ? self.method_.UTF8String : NULL;
}

- (const char *)file {
    return self.file_ ? self.file_.UTF8String : NULL;
}

@end
