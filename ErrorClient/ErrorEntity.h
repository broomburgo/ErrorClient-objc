#import <Foundation/Foundation.h>

extern NSString* __nonnull const errorTag_assicurazioni;
extern NSString* __nonnull const errorTag_poller;
extern NSString* __nonnull const errorTag_recuperoQuotazioni;
extern NSString* __nonnull const errorTag_recuperoSalvataggio;

extern NSString* __nonnull const k_standardTagsStringSeparator;

@interface ErrorEntity : NSObject

@property (copy, nonatomic, readonly) NSString* __nonnull text;
@property (copy, nonatomic, readonly) NSArray* __nonnull tags;
@property (nonatomic, readonly) NSData* __nonnull requestBody;
@property (nonatomic, readonly) NSString* __nonnull standardTagsString;

@property (nonatomic, copy) NSString* __nullable tagsStringSeparator;

+ (ErrorEntity* __nonnull)withText:(NSString* __nonnull)text tags:(NSArray* __nonnull)tags;

@end
