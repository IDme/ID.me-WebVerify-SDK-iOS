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
#import "IDmeWebView.h"

@interface IDmeWebViewBaseDelegate : NSObject <IDmeWebViewDelegate>

@property (copy, nonatomic, nullable) void (^callback)(id _Nullable result, NSError * _Nullable error);
@property (copy, nonatomic, copy, nullable) void (^onNavigationUpdate)();

@property (nonatomic, nonnull, readonly, strong) IDmeReachability *reachability;
@property (nonatomic, nullable, strong) NSString *redirectUri;
@property (nonatomic) BOOL shouldShowLoadingIndicator;

- (void)cancelTapped:(_Nullable id)sender;

@end

@interface IDmeWebViewBaseDelegate(Protected)

#pragma mark - WKWebView delegate methods

- (void)reloadWebView:(null_unspecified IDmeWebView *)webView;
- (void)webView:(null_unspecified WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation;
- (void)webView:(null_unspecified WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(null_unspecified NSError *)error;
- (void)webView:(null_unspecified WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(null_unspecified NSError *)error;
- (void)webView:(null_unspecified WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation;
- (void)webView:(null_unspecified WKWebView *)webView decidePolicyForNavigationAction:(null_unspecified WKNavigationAction *)navigationAction decisionHandler:(null_unspecified void (^)(WKNavigationActionPolicy))decisionHandler;
- (null_unspecified WKWebView *)webView:(null_unspecified WKWebView *)webView createWebViewWithConfiguration:(null_unspecified WKWebViewConfiguration *)configuration forNavigationAction:(null_unspecified WKNavigationAction *)navigationAction windowFeatures:(null_unspecified WKWindowFeatures *)windowFeatures;

#pragma mark - Must be overriden

- (WKNavigationActionPolicy)policyForWebView:(null_unspecified WKWebView *)webView navigationAction:(null_unspecified WKNavigationAction *)navigationAction;

#pragma mark - Parameter parsing
- (NSMutableDictionary * _Nonnull)parseQueryParametersFromURL:(NSString * _Nonnull)query;

@end
