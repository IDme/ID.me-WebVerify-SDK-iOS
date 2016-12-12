//
//  IDmeWebVerify.m,
//  ID.me WebVerify
//
//  Created by Arthur Sabintsev on 9/24/13.
//  Copyright (c) 2013 ID.me, Inc. All rights reserved.
//

#import "IDmeWebVerify.h"
#import "IDmeWebVerifyNavigationController.h"
#import <WebKit/WebKit.h>
#import "IDmeWebVerifyKeychainData.h"

/// API Constants (Production)
#define IDME_WEB_VERIFY_GET_AUTH_URI                    @"https://api.id.me/oauth/authorize?client_id=%@&redirect_uri=%@&response_type=token&scope=%@"
#define IDME_WEB_VERIFY_GET_USER_PROFILE                @"https://api.id.me/api/public/v2/%@.json?access_token=%@"

/// Data Constants
#define IDME_WEB_VERIFY_ACCESS_TOKEN_PARAM              @"access_token"
#define IDME_WEB_VERIFY_EXPIRATION_PARAM              @"expires_in"
#define IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM         @"error_description"

/// Color Constants
#define kIDmeWebVerifyColorGreen                        [UIColor colorWithRed:47.0f/255.0f green:192.0f/255.0f blue:115.0f/255.0f alpha:1.0f]
#define kIDmeWebVerifyColorLightBlue                    [UIColor colorWithRed:56.0f/255.0f green:168.0f/255.0f blue:232.0f/255.0f alpha:1.0f]
#define kIDmeWebVerifyColorDarkBlue                     [UIColor colorWithRed:46.0f/255.0f green:61.0f/255.0f blue:80.0f/255.0f alpha:1.0f]

@interface IDmeWebVerify () <WKNavigationDelegate>

@property (nonatomic, copy) IDmeVerifyWebVerifyResults webVerificationResults;
@property (nonatomic, copy) NSString *clientID;
@property (nonatomic, copy) NSString *redirectURI;
@property (nonatomic, strong) IDmeWebVerifyKeychainData *keychainData;
@property (nonatomic, strong) UIViewController *presentingViewController;
@property (nonatomic, strong) IDmeWebVerifyNavigationController *webNavigationController;
@property (nonatomic, strong) WKWebView *webView;
@property Boolean loadUser;

@end

@implementation IDmeWebVerify

#pragma mark - Initialization Methods
+ (IDmeWebVerify *)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [self new];
    });

    return sharedInstance;
}

- (id)init{
    self = [super init];
    if (self) {
        self.keychainData = [[IDmeWebVerifyKeychainData alloc] init];
        [self clearWebViewCacheAndCookies];
    }
    
    return self;
}

+ (void)initializeWithClientID:(NSString *)clientID redirectURI:(NSString *)redirectURI {
    [[IDmeWebVerify sharedInstance] setClientID:clientID];
    [[IDmeWebVerify sharedInstance] setRedirectURI:redirectURI];
}

#pragma mark - Authorization Methods (Public)
- (void)verifyUserInViewController:(UIViewController *)externalViewController
                            scope:(NSString *)scope
                      withResults:(IDmeVerifyWebVerifyResults)webVerificationResults {
     [self verifyUserInViewController: externalViewController
                                scope: scope
                             loadUser: YES
                           withResult: webVerificationResults];
}

- (void)verifyUserInViewController:(UIViewController *)externalViewController
                             scope:(NSString *)scope
                   withTokenResult:(IDmeVerifyWebVerifyResults)webVerificationResults {

    [self verifyUserInViewController: externalViewController
                               scope: scope
                            loadUser: NO
                          withResult: webVerificationResults];
}

#pragma mark - Authorization Methods (Private)
- (void)verifyUserInViewController:(UIViewController *)externalViewController
                             scope:(NSString *)scope
                          loadUser:(Boolean)loadUser
                         withResult:(IDmeVerifyWebVerifyResults)webVerificationResults {
    NSAssert(self.clientID != nil, @"You should initialize the SDK before making requests. Call IDmeWebVerify.initializeWithClientID:redirectURI");
    _loadUser = loadUser;
    [self clearWebViewCacheAndCookies];
    self.keychainData.scope = scope;
    [self setPresentingViewController:externalViewController];
    [self setWebVerificationResults:webVerificationResults];
    [self launchWebNavigationController];
}

#pragma mark - Other public functions
- (void)getUserProfileWithResult:(IDmeVerifyWebVerifyResults _Nonnull)webVerificationResults; {
    [self getAccessTokenWithScope:self.keychainData.scope
                  forceRefreshing:NO
                           result:^(NSDictionary * _Nullable userProfile, NSError * _Nullable error, NSString * _Nullable accessToken) {
        NSString *requestString = [NSString stringWithFormat:IDME_WEB_VERIFY_GET_USER_PROFILE, self.keychainData.scope, accessToken];

        requestString = [requestString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSURL *requestURL = [NSURL URLWithString:requestString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
        [request setValue:@"IDmeWebVerify-SDK-iOS" forHTTPHeaderField:@"X-API-ORIGIN"];

        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
                NSUInteger statusCode = [httpResponse statusCode];
                if ([data length]) {
                    NSDictionary *results = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                    NSDictionary *userProfile = [self testResultsForNull:results];
                    if (statusCode == 200) {
                        webVerificationResults(userProfile, nil, nil);
                    } else if (statusCode == 401) {
                        //TODO: refresh token
                    }
                } else {
                    NSError *modifiedError = [[NSError alloc] initWithDomain:IDME_WEB_VERIFY_ERROR_DOMAIN
                                                                        code:IDmeWebVerifyErrorCodeVerificationDidFailToFetchUserProfile
                                                                    userInfo:error.userInfo];
                    webVerificationResults(nil, modifiedError, nil);
                }

                // Dismiss _webViewController and clear _webView cache
                if (self.webNavigationController) {
                    [self destroyWebNavigationController:self];
                }
            });
            
        }];
        [task resume];
    }];
}

-(void)logout {
    [self.keychainData clean];
}

- (void)getAccessTokenWithScope:(NSString*)scope forceRefreshing:(BOOL)force result:(IDmeVerifyWebVerifyResults)callback{
    if (force) {
        // TODO: refresh token
        callback(nil, nil, nil);
        return;
    } else if (![scope isEqualToString:self.keychainData.scope]) {
        [self logout];
        [self verifyUserInViewController:[self topMostController] scope:scope withTokenResult:callback];
    }
    NSString* token = self.keychainData.accessToken;
    if (token) {
        NSDate* expiration = self.keychainData.expirationDate;
        NSDate* now = [[NSDate alloc] init];
        if ([now compare:expiration] != NSOrderedAscending) {
            // TODO: refresh token
            callback(nil, nil, nil);
            return;
        }
    }

    callback(nil, nil, token);
}

#pragma mark - Web view Methods
- (void)launchWebNavigationController {

    // Initialize _webView
    _webView = [self createWebView];

    // Initialize _webNavigationController
    _webNavigationController = [self createWebNavigationController];

    // Present _webNavigationController
    [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationPortrait animated:YES];
    [_presentingViewController presentViewController:_webNavigationController animated:YES completion:^{

        // GET Access Token via UIWebView flow
        [self loadWebViewWithAccessTokenRequestPage];

    }];

}

- (void)loadWebViewWithAccessTokenRequestPage {
    NSString *requestString = [NSString stringWithFormat:IDME_WEB_VERIFY_GET_AUTH_URI, _clientID, _redirectURI, self.keychainData.scope];

    requestString = [requestString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *requestURL = [NSURL URLWithString:requestString];
    NSURLRequest *request = [NSURLRequest requestWithURL:requestURL];
    [_webView loadRequest:request];
}

#pragma mark - WebView Persistance Methods (Private)
- (WKWebView * _Nonnull)createWebView {
    CGRect parentViewControllerViewFrame = [_presentingViewController.view frame];
    CGRect webViewFrame = CGRectMake(0.0f,
                                     0.0f,
                                     parentViewControllerViewFrame.size.width,
                                     parentViewControllerViewFrame.size.height);
    WKWebView *webView = [[WKWebView alloc] initWithFrame:webViewFrame];
    webView.navigationDelegate = self;
    webView.allowsBackForwardNavigationGestures = YES;

    return webView;
}

- (void)destroyWebView
{
    if (_webView) {
        [_webView loadHTMLString:@"" baseURL:nil];
        [_webView stopLoading];
        [_webView setNavigationDelegate:nil];
        [_webView removeFromSuperview];
        [self setWebView:nil];
    }

}

- (void)clearWebViewCacheAndCookies {
    // Clear Cache
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [[NSURLCache sharedURLCache] setDiskCapacity:0];
    [[NSURLCache sharedURLCache] setMemoryCapacity:0];
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"WebKitCacheModelPreferenceKey"];
    
    // Clear Cookies
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
}

- (IDmeWebVerifyNavigationController * _Nonnull)createWebNavigationController {
    // Initialize webViewController
    UIViewController *webViewController = [[UIViewController alloc] init];
    [webViewController.view setFrame:[_webView frame]];
    [webViewController setTitle:@"Verify with ID.me"];
    [webViewController.view addSubview:[self webView]];
    
    // Initialize 'Cancel' UIBarButtonItem
    UIBarButtonItem *cancelBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                                            style:UIBarButtonItemStyleDone
                                                                           target:self
                                                                           action:@selector(destroyWebNavigationController:)];
    NSDictionary *buttonAttributes = @{NSForegroundColorAttributeName : kIDmeWebVerifyColorLightBlue};
    [cancelBarButtonItem setTitleTextAttributes:buttonAttributes forState:UIControlStateNormal];
    [cancelBarButtonItem setTintColor:kIDmeWebVerifyColorGreen];
    [webViewController.navigationItem setLeftBarButtonItem:cancelBarButtonItem];
    
    // Initialize and customize UINavigationController with webViewController
    IDmeWebVerifyNavigationController *navigationController = [[IDmeWebVerifyNavigationController alloc] initWithRootViewController:webViewController];
    NSDictionary *titleAttributes = @{NSForegroundColorAttributeName : kIDmeWebVerifyColorGreen};
    [navigationController.navigationBar setTitleTextAttributes:titleAttributes];
    [navigationController.navigationBar setTintColor:kIDmeWebVerifyColorLightBlue];
    [navigationController.navigationBar setBarTintColor:kIDmeWebVerifyColorDarkBlue];
    
    return navigationController;
}

- (void)destroyWebNavigationController:(id)sender{
    if ([sender isMemberOfClass:[UIBarButtonItem class]]) {
        NSDictionary *details = @{ NSLocalizedDescriptionKey : IDME_WEB_VERIFY_VERIFICATION_WAS_CANCELED };
        NSError *error = [[NSError alloc] initWithDomain:IDME_WEB_VERIFY_ERROR_DOMAIN
                                                    code:IDmeWebVerifyErrorCodeVerificationWasCanceledByUser
                                                userInfo:details];
        _webVerificationResults(nil, error, nil);
    }

    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [_webNavigationController dismissViewControllerAnimated:YES completion:^{
        [self destroyWebView];
        [self clearWebViewCacheAndCookies];
        [self setWebNavigationController:nil];
    }];
}

#pragma mark - Parsing Methods (Private)
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

- (NSDictionary * _Nonnull)testResultsForNull:(NSDictionary * _Nonnull)results{
    NSMutableDictionary *testDictionary = [NSMutableDictionary dictionaryWithDictionary:results];
    NSArray *keys = [testDictionary allKeys];
    for (id key in keys) {
        if ([testDictionary valueForKey:key] == [NSNull null]) {
            [testDictionary setValue:@"Unknown" forKey:key];
        }
    }
    
    return [NSDictionary dictionaryWithDictionary:testDictionary];
}

#pragma mark - UIWebViewDelegate Methods
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

        /*
         Ideally, we should use '[[webView.request.mainDocumentURL query] copy]',
         but that doesn't work well with '#', which is what the ID.me API result returns.

         This is why we've opted to use '[[webView.request.mainDocumentURL absoluteString] copy]',
         since it allows us to split the return string by components separated by '&'.
         */
        query = [query stringByReplacingOccurrencesOfString:@"#" withString:@"&"];

    }

    NSDictionary *parameters = [self parseQueryParametersFromURL:query];

    if ([parameters objectForKey:IDME_WEB_VERIFY_ACCESS_TOKEN_PARAM]) {

        // Extract 'access_token' from URL query parameters that are separated by '&'
        NSLog(@"%@", query);
        NSString *accessToken = [parameters objectForKey:IDME_WEB_VERIFY_ACCESS_TOKEN_PARAM];
        NSString *expiresIn = [parameters objectForKey:IDME_WEB_VERIFY_EXPIRATION_PARAM];


        self.keychainData.accessToken = accessToken;
        [self setExpirationDateWith:[NSNumber numberWithInt:[expiresIn intValue]]];
        //TODO: save refresh token
        [self.keychainData persist];
        if (_loadUser == YES)
            [self getUserProfileWithResult:_webVerificationResults];
        else {
            _webVerificationResults(nil, nil, accessToken);
            [self destroyWebNavigationController:self];
        }

        decisionHandler(WKNavigationActionPolicyCancel);
        return;

    } else if ([parameters objectForKey:IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM]) {

        // Extract 'error_description' from URL query parameters that are separated by '&'
        NSString *errorDescription = [parameters objectForKey:IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM];
        errorDescription = [errorDescription stringByReplacingOccurrencesOfString:@"+" withString:@" "];
        NSDictionary *details = @{ NSLocalizedDescriptionKey : errorDescription };
        NSError *error = [[NSError alloc] initWithDomain:IDME_WEB_VERIFY_ERROR_DOMAIN code:IDmeWebVerifyErrorCodeVerificationWasDeniedByUser userInfo:details];
        _webVerificationResults(nil, error, nil);
        [self destroyWebNavigationController:self];

        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - Accessor Methods
- (NSString * _Nullable)clientID{
    if ( !_clientID ) {
        NSLog(@"You have not set your 'clientID'! Please set it using the startWithClientID: method.");
    }
    
    return (_clientID) ? _clientID : nil;
}

#pragma mark - Helpers
- (void)setExpirationDateWith:(NSNumber*)seconds{
    self.keychainData.expirationDate = [NSDate dateWithTimeIntervalSinceNow:[seconds doubleValue]];
}

- (UIViewController*) topMostController
{
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

@end
