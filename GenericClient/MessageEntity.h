#import <Foundation/Foundation.h>

@interface MessageEntity : NSObject

@property (copy, nonatomic, readonly) NSString* __nonnull text;
@property (copy, nonatomic, readonly) NSArray* __nullable tags;
@property (copy, nonatomic, readonly) NSDictionary* __nullable info;
@property (nonatomic, readonly) NSData* __nonnull requestBody;
@property (nonatomic, readonly) NSString* __nullable standardTagsString;

@property (nonatomic, copy) NSString* __nullable tagsStringSeparator;

+ (MessageEntity* __nonnull)withText:(NSString* __nonnull)text;
+ (MessageEntity* __nonnull)withText:(NSString* __nonnull)text tags:(NSArray* __nullable)tags;
+ (MessageEntity* __nonnull)withText:(NSString* __nonnull)text tags:(NSArray* __nullable)tags info:(NSDictionary* __nullable)info;

@end
