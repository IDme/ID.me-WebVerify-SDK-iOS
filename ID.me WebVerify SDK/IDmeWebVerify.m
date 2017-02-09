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
#import "ConnectionDelegate.h"

/// API Constants (Production)
#define IDME_WEB_VERIFY_BASE_URL                        @"https://api.idmelabs.com/"
#define IDME_WEB_VERIFY_GET_AUTH_URI                    IDME_WEB_VERIFY_BASE_URL @"oauth/authorize?client_id=%@&redirect_uri=%@&response_type=token&scope=%@"
#define IDME_WEB_VERIFY_GET_USER_PROFILE                IDME_WEB_VERIFY_BASE_URL @"api/public/v2/data.json?access_token=%@"
#define IDME_WEB_VERIFY_REGISTER_CONNECTION_URI         IDME_WEB_VERIFY_BASE_URL @"oauth/authorize?client_id=%@&redirect_uri=%@&response_type=code&op=signin&scope=%@&connect=%@&access_token=%@"
#define IDME_WEB_VERIFY_REGISTER_AFFILIATION_URI        IDME_WEB_VERIFY_BASE_URL @"oauth/authorize?client_id=%@&redirect_uri=%@&response_type=code&scope=%@&access_token=%@"

/// Data Constants
#define IDME_WEB_VERIFY_ACCESS_TOKEN_PARAM              @"access_token"
#define IDME_WEB_VERIFY_EXPIRATION_PARAM                @"expires_in"
#define IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM         @"error_description"

/// Color Constants
#define kIDmeWebVerifyColorGreen                        [UIColor colorWithRed:47.0f/255.0f green:192.0f/255.0f blue:115.0f/255.0f alpha:1.0f]
#define kIDmeWebVerifyColorLightBlue                    [UIColor colorWithRed:56.0f/255.0f green:168.0f/255.0f blue:232.0f/255.0f alpha:1.0f]
#define kIDmeWebVerifyColorDarkBlue                     [UIColor colorWithRed:46.0f/255.0f green:61.0f/255.0f blue:80.0f/255.0f alpha:1.0f]

@interface IDmeWebVerify () <WKNavigationDelegate>

@property (nonatomic, copy) IDmeVerifyWebVerifyProfileResults webVerificationProfileResults;
@property (nonatomic, copy) IDmeVerifyWebVerifyTokenResults webVerificationTokenResults;
@property (nonatomic, copy) NSString *clientID;
@property (nonatomic, copy) NSString *redirectURI;
@property (nonatomic, strong) IDmeWebVerifyKeychainData *keychainData;
@property (nonatomic, strong) UIViewController *presentingViewController;
@property (nonatomic, strong) IDmeWebVerifyNavigationController *webNavigationController;
@property (nonatomic, strong) WKWebView *webView;
@property Boolean loadUser;

@end

@implementation IDmeWebVerify {
    NSString* requestScope;
    IDmeWebVerifyConnection connectionType;
    IDmeWebVerifyAffiliation affiliationType;
    ConnectionDelegate* connectionDelegate;
}

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
        _keychainData = [[IDmeWebVerifyKeychainData alloc] init];
        connectionDelegate = [[ConnectionDelegate alloc] init];
        [self clearWebViewCacheAndCookies];
    }
    
    return self;
}

+ (void)initializeWithClientID:(NSString * _Nonnull)clientID redirectURI:(NSString * _Nonnull)redirectURI {
    NSAssert([IDmeWebVerify sharedInstance].clientID == nil, @"You cannot initialize IDmeWebVerify more than once.");
    [[IDmeWebVerify sharedInstance] setClientID:clientID];
    [[IDmeWebVerify sharedInstance] setRedirectURI:redirectURI];
}

#pragma mark - Authorization Methods (Public)
- (void)verifyUserInViewController:(UIViewController *)externalViewController
                            scope:(NSString *)scope
                      withResults:(IDmeVerifyWebVerifyProfileResults)webVerificationResults {
    [self setWebVerificationProfileResults:webVerificationResults];
    [self verifyUserInViewController: externalViewController
                               scope: scope
                            loadUser: YES];
}

- (void)verifyUserInViewController:(UIViewController *)externalViewController
                             scope:(NSString *)scope
                   withTokenResult:(IDmeVerifyWebVerifyTokenResults)webVerificationResults {
    [self setWebVerificationTokenResults:webVerificationResults];
    [self verifyUserInViewController: externalViewController
                               scope: scope
                            loadUser: NO];
}

#pragma mark - Authorization Methods (Private)
- (void)verifyUserInViewController:(UIViewController *)externalViewController
                             scope:(NSString *)scope
                          loadUser:(Boolean)loadUser {
    NSAssert(self.clientID != nil, @"You should initialize the SDK before making requests. Call IDmeWebVerify.initializeWithClientID:redirectURI");
    _loadUser = loadUser;
    [self clearWebViewCacheAndCookies];
    requestScope = scope;
    [self setPresentingViewController:externalViewController];
    __weak IDmeWebVerify *weakself = self;
    [self launchWebNavigationControllerWithDelegate:self completion:^{

        // GET Access Token via UIWebView flow
        [weakself loadWebViewWithRequest:[NSString stringWithFormat:IDME_WEB_VERIFY_GET_AUTH_URI, _clientID, _redirectURI, requestScope]];
        
    }];
}

-(void)registerConnectionInViewController:(UIViewController *)viewController
                                    scope:(NSString *)scope
                                     type:(IDmeWebVerifyConnection)type
                                   result:(IDmeVerifyWebVerifyConnectionResults)callback {
    NSAssert(self.clientID != nil, @"You should initialize the SDK before making requests. Call IDmeWebVerify.initializeWithClientID:redirectURI");
    __weak IDmeWebVerify *weakself = self;
    connectionDelegate.callback = ^(NSError* error){
        callback(error);
        [weakself destroyWebNavigationController];
    };
    connectionDelegate.redirectUri = self.redirectURI;
    [self clearWebViewCacheAndCookies];
    requestScope = scope;
    connectionType = type;
    [self setPresentingViewController:viewController];
    [self launchWebNavigationControllerWithDelegate:connectionDelegate completion:^{

        // Register Connection via UIWebView flow
        [weakself getAccessTokenWithScope:requestScope
                          forceRefreshing:NO
                                   result:^(NSString * _Nullable accessToken, NSError * _Nullable error) {

                                       NSString *requestString = [NSString stringWithFormat:IDME_WEB_VERIFY_REGISTER_CONNECTION_URI,
                                                                  _clientID, _redirectURI, requestScope,
                                                                  [weakself stringForConnection:connectionType], accessToken ?: @""];
                                       [weakself loadWebViewWithRequest:requestString];
                               }];
    }];
}

-(void)registerAffiliationInViewController:(UIViewController *)viewController
                            scope:(NSString *)scope
                             type:(IDmeWebVerifyAffiliation)type
                           result:(IDmeVerifyWebVerifyConnectionResults)callback {
    NSAssert(self.clientID != nil, @"You should initialize the SDK before making requests. Call IDmeWebVerify.initializeWithClientID:redirectURI");
    __weak IDmeWebVerify *weakself = self;
    connectionDelegate.callback = ^(NSError* error){
        callback(error);
        [weakself destroyWebNavigationController];
    };
    connectionDelegate.redirectUri = self.redirectURI;
    [self clearWebViewCacheAndCookies];
    requestScope = scope;
    affiliationType = type;
    [self setPresentingViewController:viewController];
    [self launchWebNavigationControllerWithDelegate:connectionDelegate completion:^{

        // Register Affiliation via UIWebView flow
        [weakself getAccessTokenWithScope:requestScope
                          forceRefreshing:NO
                                   result:^(NSString * _Nullable accessToken, NSError * _Nullable error) {

                                       NSString *requestString = [NSString stringWithFormat:IDME_WEB_VERIFY_REGISTER_AFFILIATION_URI,
                                                                  _clientID, _redirectURI, [weakself stringForAffiliation:affiliationType], accessToken ?: @""];
                                       [weakself loadWebViewWithRequest:requestString];
                               }];
    }];
}

#pragma mark - Other public functions
- (void)getUserProfileWithScope:(NSString* _Nullable)scope result:(IDmeVerifyWebVerifyProfileResults _Nonnull)webVerificationResults {
    __weak IDmeWebVerify *weakself = self;
    [self getAccessTokenWithScope:scope
                  forceRefreshing:NO
                           result:^(NSString * _Nullable accessToken, NSError * _Nullable error) {

                                if (!accessToken) {
                                    webVerificationResults(nil, error);
                                    // Dismiss _webViewController and clear _webView cache
                                    if (weakself.webNavigationController) {
                                        [weakself destroyWebNavigationController];
                                    }
                                    return;
                                }
                                NSString *requestString = [NSString stringWithFormat:IDME_WEB_VERIFY_GET_USER_PROFILE, accessToken];

                                requestString = [requestString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                                NSURL *requestURL = [NSURL URLWithString:requestString];
                                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
                                [request setValue:@"IDmeWebVerify-SDK-iOS" forHTTPHeaderField:@"X-API-ORIGIN"];

                                NSURLSession *session = [NSURLSession sharedSession];
                                NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
                                        NSUInteger statusCode = [httpResponse statusCode];
                                        if ([data length] && error == nil && statusCode == 200) {
                                            NSError* serializingError;
                                            NSMutableDictionary *results = (NSMutableDictionary *)[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments | NSJSONReadingMutableContainers error:&serializingError];
                                            [weakself removeNull:results];
                                            if (serializingError == nil) {
                                                    webVerificationResults(results, nil);
                                            } else {
                                                webVerificationResults(nil, [weakself failedFetchingProfileErrorWithUserInfo:error.userInfo]);
                                            }
                                        } else if (statusCode == 401) {
                                            // TODO: refresh token
                                            webVerificationResults(nil, [weakself notAuthorizedErrorWithUserInfo:nil]);
                                        } else {
                                            webVerificationResults(nil, [weakself failedFetchingProfileErrorWithUserInfo:error.userInfo]);
                                        }

                                        // Dismiss _webViewController and clear _webView cache
                                        if (weakself.webNavigationController) {
                                            [weakself destroyWebNavigationController];
                                        }
                                    });
                                    
                                }];
                                [task resume];
    }];
}

-(void)logout {
    [self.keychainData clean];
}

- (void)getAccessTokenWithScope:(NSString* _Nullable)scope forceRefreshing:(BOOL)force result:(IDmeVerifyWebVerifyTokenResults _Nonnull)callback{

    if (force) {
        // TODO: refresh token
        callback(nil, [self notImplementedErrorWithUserInfo:nil]);
        return;
    }

    NSString* token;
    NSDate* expiration;
    if (scope) {
        // get the token for the specified scope
        token = [self.keychainData accessTokenForScope:scope];
        expiration = [self.keychainData expirationDateForScope:scope];

    } else {
        // get last used token
        NSString* latestScope = [self.keychainData getLatestUsedScope];

        if (!latestScope) {
            // no token has been requested yet
            callback(nil, [self noSuchScopeErrorWithUserInfo:nil]);
            return;
        }

        token = [self.keychainData accessTokenForScope:latestScope];
        expiration = [self.keychainData expirationDateForScope:latestScope];
    }

    if (token) {
        // check if token has expired
        NSDate* now = [[NSDate alloc] init];
        if ([now compare:expiration] != NSOrderedAscending) {
            // TODO: refresh token
            callback(nil, [self notAuthorizedErrorWithUserInfo:nil]);
        } else {
            callback(token, nil);
        }
    } else {
        // invalid scope passed as argument. There is no token for this scope
        callback(nil, [self noSuchScopeErrorWithUserInfo:nil]);
    }

}

#pragma mark - Web view Methods
- (void)launchWebNavigationControllerWithDelegate:(id<WKNavigationDelegate>)delegate completion:(void (^ __nullable)(void))completion {

    // Initialize _webView
    _webView = [self createWebViewWithDelegate:delegate];

    // Initialize _webNavigationController
    _webNavigationController = [self createWebNavigationController: delegate];

    // Present _webNavigationController
    [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationPortrait animated:YES];
    [_presentingViewController presentViewController:_webNavigationController animated:YES completion:completion];

}

- (void)loadWebViewWithRequest:(NSString* _Nonnull)requestString {

    requestString = [requestString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *requestURL = [NSURL URLWithString:requestString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
    // Sends an empty cookie to prevent the server of auto loging in the user. This is a workaround in iOS 8
    // to avoid sending stored cookies when loading the request in the WKWebView. On iOS9+ use a non-persistent
    // datastore which won't save any cookie (it's intended to implement "private browsing" in a webview).
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [request setValue:@"" forHTTPHeaderField:@"Cookie"];
    [_webView loadRequest:[request copy]];
}

#pragma mark - WebView Persistance Methods (Private)
- (WKWebView * _Nonnull)createWebViewWithDelegate:(id<WKNavigationDelegate>)delegate {
    CGRect parentViewControllerViewFrame = [_presentingViewController.view frame];
    CGRect webViewFrame = CGRectMake(0.0f,
                                     0.0f,
                                     parentViewControllerViewFrame.size.width,
                                     parentViewControllerViewFrame.size.height);

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];

    if ([configuration respondsToSelector:@selector(setWebsiteDataStore:)]) {
        configuration.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    }

    WKWebView *webView = [[WKWebView alloc] initWithFrame:webViewFrame configuration:configuration];

    webView.navigationDelegate = delegate;
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
    // Clear Cookies
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];

    NSURL *url = [[NSURL alloc] initWithString:[NSString stringWithFormat:IDME_WEB_VERIFY_GET_AUTH_URI, @"", @"", @""]];
    NSString *domain = [url.host stringByReplacingOccurrencesOfString:@"api" withString:@""];
    for (cookie in [storage cookies]) {
        if ([cookie.domain isEqualToString:domain]) {
            // Delete ID.me cookies for security
            [storage deleteCookie:cookie];
        }
    }
}

- (IDmeWebVerifyNavigationController * _Nonnull)createWebNavigationController:(id)cancelTarget {
    // Initialize webViewController
    UIViewController *webViewController = [[UIViewController alloc] init];
    [webViewController.view setFrame:[_webView frame]];
    [webViewController setTitle:@"Verify with ID.me"];
    [webViewController.view addSubview:[self webView]];
    
    // Initialize 'Cancel' UIBarButtonItem
    UIBarButtonItem *cancelBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                                            style:UIBarButtonItemStyleDone
                                                                           target:cancelTarget
                                                                           action:@selector(cancelTapped:)];
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

- (void)cancelTapped:(id)sender{
    if ([sender isMemberOfClass:[UIBarButtonItem class]]) {
        NSDictionary *details = @{ NSLocalizedDescriptionKey : IDME_WEB_VERIFY_VERIFICATION_WAS_CANCELED };
        NSError *error = [[NSError alloc] initWithDomain:IDME_WEB_VERIFY_ERROR_DOMAIN
                                                    code:IDmeWebVerifyErrorCodeVerificationWasCanceledByUser
                                                userInfo:details];
        if (_webVerificationTokenResults) {
            _webVerificationTokenResults(nil, error);
        } else {
            _webVerificationProfileResults(nil, error);
        }
    }

    [self destroyWebNavigationController];
}

- (void)destroyWebNavigationController {

    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    __weak IDmeWebVerify *weakself = self;
    [_webNavigationController dismissViewControllerAnimated:YES completion:^{
        [weakself destroyWebView];
        [weakself clearWebViewCacheAndCookies];
        [weakself setWebNavigationController:nil];
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

- (void)removeNull:(NSMutableDictionary * _Nonnull)results{
    NSArray *keys = [results allKeys];
    for (id key in keys) {
        if ([results valueForKey:key] == [NSNull null]) {
            [results removeObjectForKey:key];
        }
    }
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
        NSString *accessToken = [parameters objectForKey:IDME_WEB_VERIFY_ACCESS_TOKEN_PARAM];
        NSString *expiresIn = [parameters objectForKey:IDME_WEB_VERIFY_EXPIRATION_PARAM];


        //TODO: save refresh token
        NSDate* expirationDate = [NSDate dateWithTimeIntervalSinceNow:[[NSNumber numberWithInt:[expiresIn intValue]] doubleValue]];
        [self.keychainData setToken:accessToken expirationDate:expirationDate refreshToken:nil forScope:requestScope];

        if (_loadUser == YES)
            [self getUserProfileWithScope:requestScope result:_webVerificationProfileResults];
        else {
            _webVerificationTokenResults(accessToken, nil);
            [self destroyWebNavigationController];
        }

        decisionHandler(WKNavigationActionPolicyCancel);
        return;

    } else if ([parameters objectForKey:IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM]) {

        // Extract 'error_description' from URL query parameters that are separated by '&'
        NSString *errorDescription = [parameters objectForKey:IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM];
        errorDescription = [errorDescription stringByReplacingOccurrencesOfString:@"+" withString:@" "];
        NSDictionary *details = @{ NSLocalizedDescriptionKey : errorDescription };
        NSError *error = [[NSError alloc] initWithDomain:IDME_WEB_VERIFY_ERROR_DOMAIN code:IDmeWebVerifyErrorCodeVerificationWasDeniedByUser userInfo:details];
        if (_webVerificationTokenResults) {
            _webVerificationTokenResults(nil, error);
        } else {
            _webVerificationProfileResults(nil, error);
        }
        [self destroyWebNavigationController];

        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - Accessor Methods
- (NSString * _Nullable)clientID{
    return (_clientID) ? _clientID : nil;
}

#pragma mark - Helpers - Errors
- (NSError * _Nonnull)noSuchScopeErrorWithUserInfo:(NSDictionary* _Nullable)userInfo {
    return [self errorWithCode:IDmeWebVerifyErrorCodeNoSuchScope userInfo:userInfo];
}

- (NSError * _Nonnull)failedFetchingProfileErrorWithUserInfo:(NSDictionary* _Nullable)userInfo {
    return [self errorWithCode:IDmeWebVerifyErrorCodeVerificationDidFailToFetchUserProfile userInfo:userInfo];
}

- (NSError * _Nonnull)notImplementedErrorWithUserInfo:(NSDictionary* _Nullable)userInfo {
    return [self errorWithCode:IDmeWebVerifyErrorCodeNotImplemented userInfo:userInfo];
}

- (NSError * _Nonnull)notAuthorizedErrorWithUserInfo:(NSDictionary* _Nullable)userInfo {
    return [self errorWithCode:IDmeWebVerifyErrorCodeNotAuthorized userInfo:userInfo];
}

- (NSError * _Nonnull)errorWithCode:(IDmeWebVerifyErrorCode)code  userInfo:(NSDictionary* _Nullable)userInfo {
    return [[NSError alloc] initWithDomain:IDME_WEB_VERIFY_ERROR_DOMAIN
                                      code:code
                                  userInfo:userInfo];
}

#pragma mark - Helpers - Enums
- (NSString * _Nonnull)stringForConnection:(IDmeWebVerifyConnection)type {
    switch (type) {
        case IDWebVerifyConnectionFacebook:
            return @"facebook";
            break;
        case IDWebVerifyConnectionGooglePlus:
            return @"google";
            break;
        case IDWebVerifyConnectionLinkedin:
            return @"linkedin";
            break;
        case IDWebVerifyConnectionPaypal:
            return @"paypal";
            break;
    }
}

- (NSString * _Nonnull)stringForAffiliation:(IDmeWebVerifyAffiliation)type {
    switch (type) {
        case IDmeWebVerifyAffiliationGovernment:
            return @"government";
            break;
        case IDmeWebVerifyAffiliationIdentity:
            return @"identity";
            break;
        case IDmeWebVerifyAffiliationMilitary:
            return @"military";
            break;
        case IDmeWebVerifyAffiliationResponder:
            return @"responder";
            break;
        case IDmeWebVerifyAffiliationStudent:
            return @"student";
            break;
        case IDmeWebVerifyAffiliationTeacher:
            return @"teacher";
            break;
    }
}

@end
