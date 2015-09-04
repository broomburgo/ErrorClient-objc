#import "ExceptionEntity.h"

#import <Tools/Tools.h>

@interface ExceptionEntity ()

@property (copy, nonatomic) NSException* exception;
@property (copy, nonatomic) NSArray* tags;
@property (copy, nonatomic) NSDictionary* info;

@end

@implementation ExceptionEntity

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

@end
