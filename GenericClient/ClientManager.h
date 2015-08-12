#import <Foundation/Foundation.h>

@class GenericClient;

@interface ClientManager : NSObject

+ (ClientManager* __nonnull)shared;
- (GenericClient* __nonnull)addClient:(GenericClient* __nonnull)client withKey:(NSString* __nonnull)key;
- (GenericClient* __nullable)removeClientWithKey:(NSString* __nonnull)key;

@end
