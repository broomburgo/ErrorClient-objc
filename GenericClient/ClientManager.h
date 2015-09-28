#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class GenericClient;

@interface ClientManager : NSObject

+ (ClientManager*)shared;
- (GenericClient*)addClient:(GenericClient*)client
                    withKey:(NSString*)key;
- (GenericClient* _Nullable)removeClientWithKey:(NSString*)key;

@end

NS_ASSUME_NONNULL_END
