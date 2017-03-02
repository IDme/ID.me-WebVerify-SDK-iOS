//
//  IDmeAuthenticationDelegate.m
//  WebVerifySample
//
//  Created by Miguel Revetria on 28/2/17.
//  Copyright © 2017 ID.me, Inc. All rights reserved.
//

#import "IDmeAuthenticationDelegate.h"

#import "IDmeWebVerify.h"

#define IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM @"error_description"

@implementation IDmeAuthenticationDelegate

- (WKNavigationActionPolicy)policyForWebView:(WKWebView *)webView navigationAction:(WKNavigationAction *)navigationAction {
    NSString *query = [[navigationAction.request.mainDocumentURL absoluteString] copy];
    if (![query hasPrefix:self.redirectUri]) {
        return WKNavigationActionPolicyAllow;
    }

    if (query) {
        /*
         Ideally, we should use '[[webView.request.mainDocumentURL query] copy]',
         but that doesn't work well with '#', which is what the ID.me API result returns.

         This is why we've opted to use '[[webView.request.mainDocumentURL absoluteString] copy]',
         since it allows us to split the return string by components separated by '&'.
         */
        query = [query stringByReplacingOccurrencesOfString:@"#" withString:@"&"];
        query = [query stringByReplacingOccurrencesOfString:@"?" withString:@"&"];

    }

    NSDictionary *parameters = [self parseQueryParametersFromURL:query];
    if ([parameters objectForKey:@"code"]) {
        if (self.callback) {
            self.callback([parameters objectForKey:@"code"], nil);
        }
        return WKNavigationActionPolicyCancel;
    } else if ([parameters objectForKey:IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM]) {
        // Extract 'error_description' from URL query parameters that are separated by '&'
        NSString *errorDescription = [parameters objectForKey:IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM];
        errorDescription = [errorDescription stringByReplacingOccurrencesOfString:@"+" withString:@" "];
        NSDictionary *details = @{ NSLocalizedDescriptionKey : errorDescription };
        NSError *error = [[NSError alloc] initWithDomain:IDME_WEB_VERIFY_ERROR_DOMAIN code:IDmeWebVerifyErrorCodeVerificationWasDeniedByUser userInfo:details];
        if (self.callback) {
            self.callback(nil, error);
        }
        
        return WKNavigationActionPolicyCancel;
    }
    return WKNavigationActionPolicyAllow;
}

#pragma mark - Private functions

- (NSMutableDictionary * _Nonnull)parseQueryParametersFromURL:(NSString * _Nonnull)query;{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    NSArray *components = [query componentsSeparatedByString:@"&"];
    for (NSString *component in components) {
        NSArray *parts = [component componentsSeparatedByString:@"="];
        NSString *key = [[parts objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if ([parts count] > 1) {
            id value = [[parts objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            [parameters setObject:value forKey:key];
        }
    }
    
    return parameters;
}



@end
