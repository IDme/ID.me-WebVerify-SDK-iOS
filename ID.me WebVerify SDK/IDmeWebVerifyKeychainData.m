//
//  IDmeWebVerifyKeychainData.m
//  WebVerifySample
//
//  Created by Mathias Claassen on 12/9/16.
//  Copyright © 2016 ID.me, Inc. All rights reserved.
//

#import "IDmeWebVerifyKeychainData.h"
#import <SAMKeychain/SAMKeychain.h>

/// Keychain Constants
#define IDME_KEYCHAIN_DATA_ACCOUNT              @"IDME_KEYCHAIN_DATA"
#define IDME_EXPIRATION_DATE                    @"IDME_EXPIRATION_DATE"
#define IDME_REFRESH_TOKEN                      @"IDME_REFRESH_TOKEN"
#define IDME_ACCESS_TOKEN                       @"IDME_ACCESS_TOKEN"
#define IDME_SCOPE                              @"IDME_SCOPE"

@interface IDmeWebVerifyKeychainData ()

@end

@implementation IDmeWebVerifyKeychainData {
    NSDateFormatter* _dateFormatter;
}

@synthesize scope = _scope;
@synthesize refreshToken = _refreshToken;
@synthesize accessToken = _accessToken;

- (id)init{
    self = [super init];
    if (self) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        [self loadFromKeychain];
    }

    return self;
}

-(void)persist{
    NSError* error;
    NSDictionary* dictionary =  @{IDME_EXPIRATION_DATE: [_dateFormatter stringFromDate:self.expirationDate] ?: @"",
                                  IDME_REFRESH_TOKEN: _refreshToken,
                                  IDME_ACCESS_TOKEN: _accessToken,
                                  IDME_SCOPE: _scope,
                                  };
    NSData *dictionaryRep = [NSPropertyListSerialization dataWithPropertyList:dictionary format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    [SAMKeychain setPasswordData:dictionaryRep forService:[NSBundle mainBundle].bundleIdentifier account:IDME_KEYCHAIN_DATA_ACCOUNT error:&error];
    
}

-(void)clean {
    [SAMKeychain deletePasswordForService:[NSBundle mainBundle].bundleIdentifier account:IDME_KEYCHAIN_DATA_ACCOUNT];
    self.accessToken = nil;
    self.refreshToken = nil;
    self.scope = nil;
    self.expirationDate = nil;
}

-(void)loadFromKeychain{
    NSError *error;
    NSData* data = [SAMKeychain passwordDataForService:[NSBundle mainBundle].bundleIdentifier account:IDME_KEYCHAIN_DATA_ACCOUNT];
    NSDictionary *dictionary = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&error];
    self.accessToken = dictionary[IDME_ACCESS_TOKEN];
    self.refreshToken = dictionary[IDME_REFRESH_TOKEN];
    self.scope = dictionary[IDME_SCOPE];
    self.expirationDate = [_dateFormatter dateFromString:dictionary[IDME_EXPIRATION_DATE]];
}

#pragma mark Getters and Setters

-(NSString *)scope{
    return [_scope  isEqual: @""] ? nil : _scope;
}

-(void)setScope:(NSString *)scope{
    _scope = scope ?: @"";
}

-(NSString *)accessToken{
    return [_accessToken  isEqual: @""] ? nil : _accessToken;
}

-(void)setAccessToken:(NSString *)accessToken{
    _accessToken = accessToken ?: @"";
}

-(NSString *)refreshToken{
    return [_refreshToken  isEqual: @""] ? nil : _refreshToken;
}

-(void)setRefreshToken:(NSString *)refreshToken{
    _refreshToken = refreshToken ?: @"";
}

@end
