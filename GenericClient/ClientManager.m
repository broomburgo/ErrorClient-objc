#import "ClientManager.h"
#import "GenericClient.h"
#import <Tools/Tools.h>

@interface ClientManager ()

@property (strong, nonatomic) NSMutableDictionary* m_clients;

@end

@implementation ClientManager

- (instancetype)init
{
  self = [super init];
  if (self == nil)
  {
    return nil;
  }
  _m_clients = [NSMutableDictionary dictionary];
  return self;
}

+ (ClientManager*)shared
{
  static ClientManager* value = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    value = [ClientManager new];
  });
  return value;
}

- (GenericClient*)addClient:(GenericClient*)client
                    withKey:(NSString*)key
{
  [self.m_clients setObject:client forKey:key];
  return client;
}

- (GenericClient*)removeClientWithKey:(NSString*)key
{
  GenericClient* client = [self.m_clients
                           objectForKey:key
                           as:[GenericClient class]];
  [self.m_clients removeObjectForKey:key];
  return client;
}

@end
