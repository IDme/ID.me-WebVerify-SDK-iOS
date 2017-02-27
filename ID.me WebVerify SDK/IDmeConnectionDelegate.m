//
//  ConnectionDelegate.m
//  WebVerifySample
//
//  Created by Mathias Claassen on 2/2/17.
//  Copyright © 2017 ID.me, Inc. All rights reserved.
//

#import "IDmeConnectionDelegate.h"

#import "IDmeReachability.h"
#import "IDmeWebView.h"

@implementation IDmeConnectionDelegate

- (WKNavigationActionPolicy)policyForWebView:(WKWebView *)webView navigationAction:(WKNavigationAction *)navigationAction {
    NSString *query = [[navigationAction.request.mainDocumentURL absoluteString] copy];

    if (query) {
        if ([query hasPrefix:self.redirectUri]) {
            self.callback(nil, nil);
            return WKNavigationActionPolicyCancel;
        }
    }

    return WKNavigationActionPolicyAllow;
}

@end
