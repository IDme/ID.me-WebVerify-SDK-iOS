//
//  IDWebView.h
//  WebVerifySample
//
//  Created by Miguel Revetria on 27/2/17.
//  Copyright © 2017 ID.me, Inc. All rights reserved.
//

#import <WebKit/WebKit.h>

@interface IDmeWebView : WKWebView

- (void)setErrorPageHidden:(Boolean)hidden animated:(BOOL)animated;
- (void)setLoadingIndicatorHidden:(Boolean)hidden;

@end
