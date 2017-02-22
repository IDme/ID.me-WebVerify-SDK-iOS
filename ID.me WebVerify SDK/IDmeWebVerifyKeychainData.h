//
//  IDmeWebVerifyKeychainData.h
//  WebVerifySample
//
//  Copyright © 2016 ID.me, Inc. All rights reserved.
//

#ifndef IDmeWebVerifyKeychainData_h
#define IDmeWebVerifyKeychainData_h

#import <Foundation/Foundation.h>

@interface IDmeWebVerifyKeychainData : NSObject

-(NSString* _Nullable)getLatestUsedScope;
-(NSString* _Nullable)accessTokenForScope:(NSString* _Nonnull)scope;
-(NSDate* _Nullable)expirationDateForScope:(NSString* _Nonnull)scope;
-(NSString* _Nullable)refreshTokenForScope:(NSString* _Nonnull)scope;
-(NSDate * _Nullable)refreshExpirationDateForScope:(NSString * _Nonnull)scope;

// TODO: discuss if refreshToken should be nullable
-(void)setToken:(NSString * _Nonnull)accessToken
 expirationDate:(NSDate * _Nonnull)expirationDate
   refreshToken:(NSString * _Nonnull)refreshToken
 refreshExpDate:(NSDate * _Nonnull)refreshExpDate
       forScope:(NSString * _Nonnull)scope;

-(void)clean;

@end

#endif /* IDmeWebVerifyKeychainData_h */
