#import "ClientManager.h"
#import "GenericClient.h"
#import "Tools.h"

@interface ClientManager ()

@property (copy, nonatomic) NSMutableDictionary* m_clients;

@end

@implementation ClientManager

- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _m_clients = [NSMutableDictionary dictionary];
    return self;
}

+ (ClientManager* __nonnull)shared {
    static ClientManager* value = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        value = [ClientManager new];
    });
    return value;
}

- (GenericClient* __nonnull)addClient:(GenericClient* __nonnull)client withKey:(NSString* __nonnull)key; {
    [self.m_clients setObject:client forKey:key];
    return client;
}

- (GenericClient* __nullable)removeClientWithKey:(NSString* __nonnull)key {
    GenericClient* client = [self.m_clients objectForKey:key as:[GenericClient class]];
    [self.m_clients removeObjectForKey:key];
    return client;
}

@end
