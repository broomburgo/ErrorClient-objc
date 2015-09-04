#import "ExceptionEntity.h"

#import <Tools/Tools.h>

@interface ExceptionEntity ()

@property (copy, nonatomic) NSException* exception;
@property (copy, nonatomic) NSArray* tags;
@property (copy, nonatomic) NSDictionary* info;

@end

@implementation ExceptionEntity

- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _tagsStringSeparator = @"|";
    return self;
}

+ (ExceptionEntity* __nonnull)withException:(NSException * __nonnull)exception {
    return [ExceptionEntity withException:exception tags:nil info:nil];
}

+ (ExceptionEntity* __nonnull)withException:(NSException * __nonnull)exception tags:(NSArray * __nullable)tags {
    return [ExceptionEntity withException:exception tags:tags info:nil];
}

+ (ExceptionEntity* __nonnull)withException:(NSException * __nonnull)exception tags:(NSArray * __nullable)tags info:(NSDictionary * __nullable)info {
    ExceptionEntity* entity = [ExceptionEntity new];
    entity.exception = exception;
    entity.tags = [Tools JSONValidatedArray:tags];
    entity.info = [Tools JSONValidatedDictionary:info];
    return entity;
}

- (NSData*)requestBody {
    return [NSJSONSerialization dataWithJSONObject:[[[[NSDictionary dictionary]
                                                      key:@"exception" optional:[NSString stringWithFormat:@"%@", self.exception]]
                                                     key:@"tags" optional:self.standardTagsString]
                                                    optionalDict:self.info]
                                           options:0
                                             error:nil];
}

- (NSString*)standardTagsString {
    NSString* separator = self.tagsStringSeparator ? self.tagsStringSeparator : @"";
    return [[self.tags
             reduceWithStartingElement:@"" reduceBlock:^id(id accumulator, id object) {
                 return [accumulator stringByAppendingFormat:@"%@%@", object, separator];
             }]
            stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:separator]];
}

@end
