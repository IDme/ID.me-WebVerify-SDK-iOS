//
//  ConnectionDelegate.m
//  WebVerifySample
//
//  Created by Mathias Claassen on 2/2/17.
//  Copyright © 2017 ID.me, Inc. All rights reserved.
//

#import "ConnectionDelegate.h"

@implementation ConnectionDelegate

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

-(void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

-(void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

-(void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

-(void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    NSString *query = [[navigationAction.request.mainDocumentURL absoluteString] copy];

    if (query) {

        if ([query hasPrefix:self.redirectUri]) {
            self.callback(nil);
            decisionHandler(WKNavigationActionPolicyCancel);
        }
    }


    decisionHandler(WKNavigationActionPolicyAllow);
}

-(void)cancelTapped:(id)sender {
    NSDictionary *details = @{ NSLocalizedDescriptionKey : IDME_WEB_VERIFY_VERIFICATION_WAS_CANCELED };
    NSError *error = [[NSError alloc] initWithDomain:IDME_WEB_VERIFY_ERROR_DOMAIN
                                                code:IDmeWebVerifyErrorCodeVerificationWasCanceledByUser
                                            userInfo:details];
    self.callback(error);
}

@end
