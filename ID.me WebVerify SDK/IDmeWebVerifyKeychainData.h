//
//  IDmeWebVerifyKeychainData.h
//  WebVerifySample
//
//  Created by Mathias Claassen on 12/9/16.
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

-(void)setToken:(NSString * _Nonnull)accessToken expirationDate:(NSDate * _Nonnull)date
   refreshToken:(NSString * _Nullable)refreshToken forScope:(NSString * _Nonnull)scope;

-(void)clean;

@end

#endif /* IDmeWebVerifyKeychainData_h */
