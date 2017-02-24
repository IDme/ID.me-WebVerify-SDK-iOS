//
//  IDmeWebVerifyKeychainData.m
//  WebVerifySample
//
//  Copyright © 2016 ID.me, Inc. All rights reserved.
//

#import "IDmeWebVerifyKeychainData.h"
#import <SAMKeychain/SAMKeychain.h>

/// Keychain Constants
#define IDME_KEYCHAIN_DATA_ACCOUNT              @"IDME_KEYCHAIN_DATA"
#define IDME_EXPIRATION_DATE                    @"IDME_EXPIRATION_DATE"
#define IDME_REFRESH_EXPIRATION_DATE            @"IDME_REFRESH_EXPIRATION_DATE"
#define IDME_REFRESH_TOKEN                      @"IDME_REFRESH_TOKEN"
#define IDME_ACCESS_TOKEN                       @"IDME_ACCESS_TOKEN"
#define IDME_SCOPE                              @"IDME_SCOPE"

@interface IDmeWebVerifyKeychainData ()
@property (strong, nonatomic) NSString* latestScope;
@property (nonatomic, strong) NSMutableDictionary *tokensByScope;
@end

@implementation IDmeWebVerifyKeychainData {
    NSDateFormatter* _dateFormatter;
}

- (id)init{
    self = [super init];
    if (self) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        _tokensByScope = [[NSMutableDictionary alloc] init];
        [self loadFromKeychain];
    }

    return self;
}

-(void)persist{
    NSError* error;
    NSData *dictionaryRep = [NSPropertyListSerialization dataWithPropertyList:[self tokensByScope] format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    [SAMKeychain setPasswordData:dictionaryRep forService:[NSBundle mainBundle].bundleIdentifier account:IDME_KEYCHAIN_DATA_ACCOUNT error:&error];
}

-(void)clean {
    [SAMKeychain deletePasswordForService:[NSBundle mainBundle].bundleIdentifier account:IDME_KEYCHAIN_DATA_ACCOUNT];
    [self.tokensByScope removeAllObjects];
}

-(void)loadFromKeychain{
    NSError *error;
    NSData* data = [SAMKeychain passwordDataForService:[NSBundle mainBundle].bundleIdentifier account:IDME_KEYCHAIN_DATA_ACCOUNT];
    if (data) {
        NSDictionary *dictionary = [NSPropertyListSerialization propertyListWithData:data
                                                                             options:NSPropertyListMutableContainersAndLeaves
                                                                              format:nil
                                                                               error:&error];
        self.tokensByScope = [NSMutableDictionary dictionaryWithDictionary:dictionary];
        __block NSDate* mostRecentDate = [NSDate dateWithTimeIntervalSince1970:0];
        __block NSString* scope = nil;
        [self.tokensByScope enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSDate* date = [_dateFormatter dateFromString:obj[IDME_EXPIRATION_DATE]];
            if ([date compare:mostRecentDate] == NSOrderedDescending) {
                mostRecentDate = date;
                scope = key;
            }
        }];
        self.latestScope = scope;
    }
}

#pragma mark Getters and Setters

-(void)setToken:(NSString * _Nonnull)accessToken expirationDate:(NSDate * _Nonnull)expirationDate
   refreshToken:(NSString * _Nonnull)refreshToken refreshExpDate:(NSDate * _Nonnull)refreshExpDate
       forScope:(NSString * _Nonnull)scope {

    self.tokensByScope[scope] = @{IDME_EXPIRATION_DATE: [_dateFormatter stringFromDate: expirationDate],
                                  IDME_REFRESH_TOKEN: refreshToken,
                                  IDME_ACCESS_TOKEN: accessToken,
                                  IDME_REFRESH_EXPIRATION_DATE: [_dateFormatter stringFromDate: refreshExpDate]};
    self.latestScope = scope;
    [self persist];
}

-(NSString * _Nullable)getLatestUsedScope {
    return self.latestScope;
}

-(NSString * _Nullable)accessTokenForScope:(NSString * _Nonnull)scope {
    return self.tokensByScope[scope][IDME_ACCESS_TOKEN];
}

-(NSString * _Nullable)refreshTokenForScope:(NSString * _Nonnull)scope {
    return self.tokensByScope[scope][IDME_REFRESH_TOKEN];
}

-(NSDate * _Nullable)expirationDateForScope:(NSString * _Nonnull)scope{
    return  [_dateFormatter dateFromString: self.tokensByScope[scope][IDME_EXPIRATION_DATE]];
}

-(NSDate * _Nullable)refreshExpirationDateForScope:(NSString * _Nonnull)scope{
    return  [_dateFormatter dateFromString: self.tokensByScope[scope][IDME_REFRESH_EXPIRATION_DATE]];
}

@end
