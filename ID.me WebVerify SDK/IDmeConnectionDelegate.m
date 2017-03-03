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
#import "IDmeWebVerify.h"

#define IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM         @"error_description"
#define IDME_WEB_VERIFY_ERROR_PARAM                     @"error"
#define IDME_WEB_VERIFY_ACCESS_DENIED_ERROR             @"access_denied"

@implementation IDmeConnectionDelegate

- (WKNavigationActionPolicy)policyForWebView:(WKWebView *)webView navigationAction:(WKNavigationAction *)navigationAction {
    NSString *query = [[navigationAction.request.mainDocumentURL absoluteString] copy];
    NSDictionary *parameters = [self parseQueryParametersFromURL:query];
    
    if (query) {
        if ([parameters objectForKey:@"code"] && [query hasPrefix:self.redirectUri]) {
            self.callback(nil, nil);
            return WKNavigationActionPolicyCancel;
        } else if ([parameters objectForKey:IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM] && [parameters objectForKey:IDME_WEB_VERIFY_ERROR_PARAM]) {
            // Extract 'error_description' from URL query parameters that are separated by '&'
            NSString *errorDescription = [parameters objectForKey:IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM];
            errorDescription = [errorDescription stringByReplacingOccurrencesOfString:@"+" withString:@" "];
            NSDictionary *details = @{ NSLocalizedDescriptionKey : errorDescription };
            NSError *error;
            if ([[parameters objectForKey:IDME_WEB_VERIFY_ERROR_PARAM] isEqualToString:IDME_WEB_VERIFY_ACCESS_DENIED_ERROR]) {
                error = [[NSError alloc] initWithDomain:IDME_WEB_VERIFY_ERROR_DOMAIN code:IDmeWebVerifyErrorCodeVerificationWasDeniedByUser userInfo:details];
            } else {
                error = [[NSError alloc] initWithDomain:IDME_WEB_VERIFY_ERROR_DOMAIN code:IDmeWebVerifyErrorCodeAuthenticationFailed userInfo:details];
            }
            self.callback(nil, error);
            return WKNavigationActionPolicyCancel;
        }
    }

    return WKNavigationActionPolicyAllow;
}

@end
