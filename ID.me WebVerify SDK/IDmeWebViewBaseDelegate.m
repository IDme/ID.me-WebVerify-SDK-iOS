//
//  IDmeWebViewBaseDelegate.m
//  WebVerifySample
//
//  Created by Miguel Revetria on 28/2/17.
//  Copyright © 2017 ID.me, Inc. All rights reserved.
//

#import "IDmeWebViewBaseDelegate.h"

#import "IDmeWebVerify.h"
#import "IDmeWebView.h"

@interface IDmeWebViewBaseDelegate()

@property (nonatomic, strong, nullable) NSURLRequest *lastRequest;

@end

@implementation IDmeWebViewBaseDelegate

@synthesize reachability = _reachability;

- (instancetype)init {
    self = [super init];
    if (self) {
        _reachability = [IDmeReachability reachabilityForInternetConnection];
        self.shouldShowLoadingIndicator = YES;
    }
    return self;
}

- (void)cancelTapped:(_Nullable id)sender {
    NSDictionary *details = @{ NSLocalizedDescriptionKey: IDME_WEB_VERIFY_VERIFICATION_WAS_CANCELED };
    NSError *error = [[NSError alloc] initWithDomain:IDME_WEB_VERIFY_ERROR_DOMAIN
                                                code:IDmeWebVerifyErrorCodeVerificationWasCanceledByUser
                                            userInfo:details];
    self.callback(nil, error);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    self.lastRequest = nil;
    self.onNavigationUpdate();
    self.shouldShowLoadingIndicator = NO;
    [(IDmeWebView *) webView setLoadingIndicatorHidden:YES];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [(IDmeWebView *) webView setErrorPageHidden:self.reachability.currentReachabilityStatus != NotReachable animated:YES];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [(IDmeWebView *) webView setErrorPageHidden:self.reachability.currentReachabilityStatus != NotReachable animated:YES];
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (self.shouldShowLoadingIndicator) {
        [(IDmeWebView *) webView setLoadingIndicatorHidden:NO];
    }

    WKNavigationActionPolicy policy = [self policyForWebView:webView navigationAction:navigationAction];
    if (policy == WKNavigationActionPolicyAllow) {
        self.lastRequest = navigationAction.request;
    }
    decisionHandler(policy);
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {

    if (!navigationAction.targetFrame.isMainFrame && [[UIApplication sharedApplication] canOpenURL:navigationAction.request.URL]) {
        [[UIApplication sharedApplication] openURL:navigationAction.request.URL];
    }

    return nil;
}

- (WKNavigationActionPolicy)policyForWebView:(null_unspecified WKWebView *)webView navigationAction:(null_unspecified WKNavigationAction *)navigationAction {
    return WKNavigationActionPolicyAllow;
}

- (void)reloadWebView:(IDmeWebView *)webView {
    if (self.lastRequest) {
        NSURLRequest *request = self.lastRequest;
        self.lastRequest = nil;
        [webView loadRequest:request];
    }
}

#pragma mark - Private functions

- (NSMutableDictionary * _Nonnull)parseQueryParametersFromURL:(NSString * _Nonnull)query{
    query = [query stringByReplacingOccurrencesOfString:@"#" withString:@"&"];
    query = [query stringByReplacingOccurrencesOfString:@"?" withString:@"&"];
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
