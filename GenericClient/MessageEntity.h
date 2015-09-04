#import <Foundation/Foundation.h>

@interface MessageEntity : NSObject

@property (copy, nonatomic, readonly) NSString* __nonnull text;
@property (copy, nonatomic, readonly) NSArray* __nullable tags;
@property (copy, nonatomic, readonly) NSDictionary* __nullable info;

+ (MessageEntity* __nonnull)withText:(NSString* __nonnull)text;
+ (MessageEntity* __nonnull)withText:(NSString* __nonnull)text tags:(NSArray* __nullable)tags;
+ (MessageEntity* __nonnull)withText:(NSString* __nonnull)text tags:(NSArray* __nullable)tags info:(NSDictionary* __nullable)info;

@end
