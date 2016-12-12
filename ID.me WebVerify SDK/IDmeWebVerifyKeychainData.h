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

@property (nonatomic, strong) NSString *accessToken;
@property (nonatomic, strong) NSString *refreshToken;
@property (nonatomic, strong) NSDate *expirationDate;
@property (nonatomic, strong) NSString *scope;

-(void)persist;
-(void)clean;

@end

#endif /* IDmeWebVerifyKeychainData_h */
