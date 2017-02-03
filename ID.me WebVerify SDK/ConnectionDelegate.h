//
//  ConnectionDelegate.h
//  WebVerifySample
//
//  Created by Mathias Claassen on 2/2/17.
//  Copyright © 2017 ID.me, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "IDmeWebVerify.h"

@interface ConnectionDelegate : NSObject <WKNavigationDelegate>

@property (nonatomic, copy) void (^callback)(NSError* error);
@property (nonatomic) NSString *redirectUri;

@end
