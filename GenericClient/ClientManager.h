#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class GenericClient;

@interface ClientManager : NSObject

+ (ClientManager*)shared;
- (GenericClient*)addClient:(GenericClient*)client
                    withKey:(NSString*)key;
- (GenericClient* _Nullable)removeClientWithKey:(NSString*)key;
- (void(^)(BOOL, id _Nullable, id _Nullable))removeClientWithKeyOnCompletion:(NSString*)key;

@end

NS_ASSUME_NONNULL_END
