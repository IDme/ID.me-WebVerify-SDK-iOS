//
//  IDmeWebViewBaseDelegate.h
//  WebVerifySample
//
//  Created by Miguel Revetria on 28/2/17.
//  Copyright © 2017 ID.me, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#import "IDmeReachability.h"

@interface IDmeWebViewBaseDelegate : NSObject <WKNavigationDelegate, WKUIDelegate>

@property (copy, nonatomic, nullable) void (^callback)(id _Nullable result, NSError * _Nullable error);
@property (copy, nonatomic, copy, nullable) void (^onNavigationUpdate)();

@property (nonatomic, nonnull, readonly, strong) IDmeReachability *reachability;
@property (nonatomic, nullable, strong) NSString *redirectUri;
@property (nonatomic) BOOL shouldShowLoadingIndicator;

- (void)cancelTapped:(_Nullable id)sender;

@end

@interface IDmeWebViewBaseDelegate(Protected)

#pragma mark - WKWebView delegate methods

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation;
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error;
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error;
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation;
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler;
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures;

#pragma mark - Must be overriden

- (WKNavigationActionPolicy)policyForWebView:(null_unspecified WKWebView *)webView navigationAction:(null_unspecified WKNavigationAction *)navigationAction;

@end
