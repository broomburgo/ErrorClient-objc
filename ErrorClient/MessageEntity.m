#import "MessageEntity.h"
#import "Optional.h"
#import "Tools.h"

NSString* const k_standardTagsStringSeparator = @"|";

@interface MessageEntity ()

@property (copy, nonatomic) NSString* text;
@property (copy, nonatomic) NSArray* tags;
@property (copy, nonatomic) NSDictionary* info;

@end

@implementation MessageEntity

- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _tagsStringSeparator = k_standardTagsStringSeparator;
    return self;
}

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

- (NSData*)requestBody {
    return [NSJSONSerialization dataWithJSONObject:[[[@{}
                                                      key:@"text" optional:self.text]
                                                     key:@"tags" optional:self.standardTagsString]
                                                    optionalDict:self.info]
                                           options:0
                                             error:nil];
}

- (NSString*)standardTagsString {
    NSString* separator = self.tagsStringSeparator ? self.tagsStringSeparator : @"";
    return [[(NSArray*)
             [[OptionalArray with:self.tags]
              value]
             reduceWithStartingElement:@"" reduceBlock:^id(id accumulator, id object) {
                 return [accumulator stringByAppendingFormat:@"%@%@", object, separator];
             }]
            stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:separator]];
}

@end
