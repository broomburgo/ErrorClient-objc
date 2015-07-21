#import "ErrorEntity.h"
#import "Optional.h"
#import "Tools.h"

NSString* const errorTag_assicurazioni = @"assicurazioni";
NSString* const errorTag_poller = @"poller";
NSString* const errorTag_recuperoQuotazioni = @"recupero_quotazioni";
NSString* const errorTag_recuperoSalvataggio = @"recupero_salvataggio";

NSString* const k_standardTagsStringSeparator = @"|";

@interface ErrorEntity ()

@property (copy, nonatomic) NSString* text;
@property (copy, nonatomic) NSArray* tags;

@end

@implementation ErrorEntity

- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _tagsStringSeparator = k_standardTagsStringSeparator;
    return self;
}

+ (ErrorEntity*)withText:(NSString*)text tags:(NSArray*)tags {
    ErrorEntity* entity = [ErrorEntity new];
    entity.text = text;
    entity.tags = tags;
    return entity;
}

- (NSData*)requestBody {
    return [NSJSONSerialization dataWithJSONObject:@{ @"text": self.text, @"tags": self.tags}
                                           options:NSJSONWritingPrettyPrinted
                                             error:nil];
}

- (NSString*)standardTagsString {
    NSString* separator = self.tagsStringSeparator ? self.tagsStringSeparator : @"";
    return [[(NSArray*)
             [[OptionalArray with:self.tags]
              valueDefaultedTo:@[]]
             reduceWithStartingElement:@"" reduceBlock:^id(id accumulator, id object) {
                 return [accumulator stringByAppendingFormat:@"%@%@", object, separator];
             }]
            stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:separator]];
}

@end
