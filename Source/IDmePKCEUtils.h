//
//  PKCEUtils.h
//  WebVerifySample
//
//  Created by Miguel Revetria on 16/3/17.
//  Copyright © 2017 ID.me, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IDmePKCEUtils : NSObject

- (NSString * _Nonnull)encodeBase64:(NSData * _Nonnull)data;

- (NSString * _Nullable)generateCodeVerifierWithSize:(NSUInteger)size;

- (NSData * _Nonnull)sha256:(NSString * _Nonnull)string;

@end
