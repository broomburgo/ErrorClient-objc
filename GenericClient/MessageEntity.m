#import "MessageEntity.h"

#import <Tools/Tools.h>

@interface MessageEntity ()

@property (copy, nonatomic) NSString* text;
@property (copy, nonatomic) NSArray* tags;
@property (copy, nonatomic) NSDictionary* info;

@end

@implementation MessageEntity

+ (MessageEntity* __nonnull)withText:(NSString* __nonnull)text {
    return [MessageEntity withText:text tags:nil info:nil];
}

+ (MessageEntity* __nonnull)withText:(NSString* __nonnull)text tags:(NSArray* __nullable)tags {
    return [MessageEntity withText:text tags:tags info:nil];
}

+ (MessageEntity* __nonnull)withText:(NSString* __nonnull)text tags:(NSArray* __nullable)tags info:(NSDictionary* __nullable)info {
    MessageEntity* entity = [MessageEntity new];
    entity.text = text;
    entity.tags = [Tools JSONValidatedArray:tags];
    entity.info = [Tools JSONValidatedDictionary:info];
    return entity;
}

@end
