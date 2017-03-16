//
//  PKCEUtils.m
//  WebVerifySample
//
//  Created by Miguel Revetria on 16/3/17.
//  Copyright © 2017 ID.me, Inc. All rights reserved.
//

#import "IDmePKCEUtils.h"
#import <CommonCrypto/CommonDigest.h>

@implementation IDmePKCEUtils

- (NSString * _Nonnull)encodeBase64:(NSData * _Nonnull)data {
    NSString *encoded = [data base64EncodedStringWithOptions:0];
    encoded = [encoded stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    encoded = [encoded stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    encoded = [encoded stringByReplacingOccurrencesOfString:@"=" withString:@""];
    return encoded;
}

- (NSString * _Nullable)generateCodeVerifierWithSize:(NSUInteger)size {
    NSMutableData *data = [NSMutableData dataWithLength:size];
    int result = SecRandomCopyBytes(kSecRandomDefault, data.length, data.mutableBytes);
    return result == 0 ? [self encodeBase64:data] : nil;
}

- (NSData * _Nonnull)sha256:(NSString * _Nonnull)string {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *sha256 = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, sha256.mutableBytes);
    return sha256;
}

@end
