//
//  IDWebView.h
//  WebVerifySample
//
//  Created by Miguel Revetria on 27/2/17.
//  Copyright © 2017 ID.me, Inc. All rights reserved.
//

#import <WebKit/WebKit.h>

@class IDmeWebView;

@protocol IDmeWebViewDelegate <NSObject, WKNavigationDelegate, WKUIDelegate>

- (void)reloadWebView:(IDmeWebView *)webView;

@end

@interface IDmeWebView : WKWebView

@property (nonatomic, strong, nullable) NSString *errorPageTitle;
@property (nonatomic, strong, nullable) NSString *errorPageDescription;

@property (nonatomic, weak, nullable) id<IDmeWebViewDelegate> delegate;

- (void)setErrorPageHidden:(Boolean)hidden animated:(BOOL)animated;
- (void)setLoadingIndicatorHidden:(Boolean)hidden;

@end
