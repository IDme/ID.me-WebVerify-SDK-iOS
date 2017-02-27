//
//  IDmeWebVerify.m,
//  ID.me WebVerify
//
//  Created by Arthur Sabintsev on 9/24/13.
//  Copyright (c) 2013 ID.me, Inc. All rights reserved.
//

#import "IDmeWebVerify.h"

#import "IDmeAuthenticationDelegate.h"
#import "IDmeConnectionDelegate.h"
#import "IDmeReachability.h"
#import "IDmeWebVerifyNavigationController.h"
#import "IDmeWebVerifyKeychainData.h"
#import "IDmeWebView.h"

#import <WebKit/WebKit.h>

/// API Constants (Production)
#define IDME_WEB_VERIFY_BASE_URL                        @"https://api.idmelabs.com/"
#define IDME_WEB_VERIFY_GET_AUTH_URI                    IDME_WEB_VERIFY_BASE_URL @"oauth/authorize?client_id=%@&redirect_uri=%@&response_type=code&scope=%@"
#define IDME_WEB_VERIFY_GET_USER_PROFILE                IDME_WEB_VERIFY_BASE_URL @"api/public/v2/data.json?access_token=%@"
#define IDME_WEB_VERIFY_REFRESH_CODE_URL                IDME_WEB_VERIFY_BASE_URL @"oauth/token"
#define IDME_WEB_VERIFY_REGISTER_CONNECTION_URI         IDME_WEB_VERIFY_BASE_URL @"oauth/authorize?client_id=%@&redirect_uri=%@&response_type=code&op=signin&scope=%@&connect=%@&access_token=%@"
#define IDME_WEB_VERIFY_REGISTER_AFFILIATION_URI        IDME_WEB_VERIFY_BASE_URL @"oauth/authorize?client_id=%@&redirect_uri=%@&response_type=code&scope=%@&access_token=%@"
#define IDME_WEB_VERIFY_SIGN_UP_OR_LOGIN                IDME_WEB_VERIFY_BASE_URL @"oauth/authorize?client_id=%@&redirect_uri=%@&response_type=code&scope=%@&op=%@"

/// Data Constants
#define IDME_WEB_VERIFY_ACCESS_TOKEN_PARAM              @"access_token"
#define IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM         @"error_description"
#define IDME_WEB_VERIFY_EXPIRATION_PARAM                @"expires_in"
#define IDME_WEB_VERIFY_REFRESH_EXPIRATION_PARAM        @"refresh_expires_in"
#define IDME_WEB_VERIFY_REFRESH_TOKEN_PARAM             @"refresh_token"

// HTTP methods
#define POST_METHOD        @"POST"

/// Color Constants
#define kIDmeWebVerifyColorBlue                     [UIColor colorWithRed:48.0f/255.0f green:160.0f/255.0f blue:224.0f/255.0f alpha:1.0f]

@interface IDmeWebVerify () <WKNavigationDelegate, WKUIDelegate>

typedef void (^RequestCompletion)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

@property (nonatomic, copy) NSString *clientID;
@property (nonatomic, copy) NSString *clientSecret;
@property (nonatomic, copy) NSString *redirectURI;
@property (nonatomic, strong) IDmeWebVerifyKeychainData *keychainData;
@property (nonatomic, strong) UIViewController *presentingViewController;
@property (nonatomic, strong) IDmeWebVerifyNavigationController *webNavigationController;
@property (nonatomic, strong) IDmeWebView *webView;
@property (nonatomic, strong) IDmeReachability *reachability;
@property (nonatomic, strong) UIBarButtonItem *backButton;

@end

@implementation IDmeWebVerify {
    IDmeConnectionDelegate* connectionDelegate;
    IDmeAuthenticationDelegate* authenticationDelegate;
    NSMutableDictionary* pendingRefreshes;
    BOOL isRefreshing;
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

- (id)init {
    self = [super init];
    if (self) {
        _keychainData = [[IDmeWebVerifyKeychainData alloc] init];
        _showCancelButton = YES;
        isRefreshing = NO;
        pendingRefreshes = [[NSMutableDictionary alloc] init];
        self.errorPageTitle = NSLocalizedString(@"Unavailable", @"IDme WebVerify SDK disconnected page title");
        self.errorPageDescription = NSLocalizedString(@"ID.me requires a connection to the internet.", @"IDme WebVerify SDK disconnected page description");
        self.reachability = [IDmeReachability reachabilityForInternetConnection];
        [self clearWebViewCacheAndCookies];
    }
    
    return self;
}

+ (void)initializeWithClientID:(NSString * _Nonnull)clientID clientSecret:(NSString * _Nonnull)clientSecret redirectURI:(NSString * _Nonnull)redirectURI {
    NSAssert([IDmeWebVerify sharedInstance].clientID == nil, @"You cannot initialize IDmeWebVerify more than once.");
    [[IDmeWebVerify sharedInstance] setClientID:clientID];
    [[IDmeWebVerify sharedInstance] setClientSecret:clientSecret];
    [[IDmeWebVerify sharedInstance] setRedirectURI:redirectURI];
}

#pragma mark - Authorization Methods (Public)
- (void)verifyUserInViewController:(UIViewController *)externalViewController
                            scope:(NSString *)scope
                      withResults:(IDmeVerifyWebVerifyProfileResults)webVerificationResults {
    [self verifyUserInViewController:externalViewController
                               scope:scope
                            loadUser:YES
                            callback:^(id _Nullable result, NSError * _Nullable error) {
                                webVerificationResults(result, error);
                            }];
}

- (void)verifyUserInViewController:(UIViewController *)externalViewController
                             scope:(NSString *)scope
                   withTokenResult:(IDmeVerifyWebVerifyTokenResults)webVerificationResults {
    [self verifyUserInViewController:externalViewController
                               scope:scope
                            loadUser:NO
                            callback:^(id _Nullable result, NSError * _Nullable error) {
                                webVerificationResults(result, error);
                            }];
}

#pragma mark - Authorization Methods (Private)
- (void)verifyUserInViewController:(UIViewController *)externalViewController
                             scope:(NSString *)scope
                          loadUser:(BOOL)loadUser
                          callback:(void (^ _Nonnull)(id _Nullable result, NSError * _Nullable error))callback {
    NSAssert(self.clientID != nil, @"You should initialize the SDK before making requests. Call IDmeWebVerify.initializeWithClientID:redirectURI");
    [self clearWebViewCacheAndCookies];
    [self setPresentingViewController:externalViewController];

    __weak IDmeWebVerify *weakSelf = self;
    authenticationDelegate = [[IDmeAuthenticationDelegate alloc] init];
    authenticationDelegate.callback = ^(_Nullable id authCode, NSError* _Nullable error) {
        if (!authCode || error) {
            callback(nil, error);
            [weakSelf destroyWebNavigationController];
            return;
        }

        NSString *params = [NSString stringWithFormat:@"client_id=%@&client_secret=%@&redirect_uri=%@&code=%@&grant_type=authorization_code",
                            weakSelf.clientID, weakSelf.clientSecret, weakSelf.redirectURI, authCode];
        [weakSelf makePostRequestWithUrl:IDME_WEB_VERIFY_REFRESH_CODE_URL
                              parameters:params
                              completion:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                  NSError *jsonError;
                                  NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                                       options:NSJSONReadingMutableContainers
                                                                                         error:&jsonError];
                                  if (json) {
                                      [weakSelf saveTokenDataFromJson:json scope:scope];
                                      if (loadUser == YES) {
                                          [weakSelf getUserProfileWithScope:scope result:^(NSDictionary * _Nullable userProfile, NSError * _Nullable error) {
                                              callback(userProfile, error);
                                              [weakSelf destroyWebNavigationController];
                                          }];
                                      } else {
                                          callback([json objectForKey:IDME_WEB_VERIFY_ACCESS_TOKEN_PARAM], nil);
                                          [weakSelf destroyWebNavigationController];
                                      }
                                  } else {
                                      callback(nil, [weakSelf notAuthorizedErrorWithUserInfo:@{ NSLocalizedDescriptionKey: IDME_WEB_VERIFY_VERIFICATION_FAILED }]);
                                      [weakSelf destroyWebNavigationController];
                                  }
                              }];
    };
    authenticationDelegate.onNavigationUpdate = ^() {
        [weakSelf updateBackButton];
    };
    authenticationDelegate.redirectUri = self.redirectURI;

    [self launchWebNavigationControllerWithDelegate:authenticationDelegate completion:^{
        // GET Access Token via UIWebView flow
        [weakSelf loadWebViewWithRequest:[NSString stringWithFormat:IDME_WEB_VERIFY_GET_AUTH_URI, weakSelf.clientID, weakSelf.redirectURI, scope]];
    }];
}

-(void)registerOrLoginInViewController:(UIViewController *)externalViewController
                                 scope:(NSString *)scope
                             loginType:(IDmeWebVerifyLoginType)loginType
                       withTokenResult:(IDmeVerifyWebVerifyTokenResults)webVerificationResults {
    NSAssert(self.clientID != nil, @"You should initialize the SDK before making requests. Call IDmeWebVerify.initializeWithClientID:redirectURI");
    [self clearWebViewCacheAndCookies];
    [self setPresentingViewController:externalViewController];

    __weak IDmeWebVerify *weakSelf = self;

    authenticationDelegate = [[IDmeAuthenticationDelegate alloc] init];
    authenticationDelegate.callback = ^(_Nullable id authCode, NSError* _Nullable error) {
        if (!authCode || error) {
            webVerificationResults(nil, error);
            [weakSelf destroyWebNavigationController];
            return;
        }

        NSString *params = [NSString stringWithFormat:@"client_id=%@&client_secret=%@&redirect_uri=%@&code=%@&grant_type=authorization_code",
                            weakSelf.clientID, weakSelf.clientSecret, weakSelf.redirectURI, authCode];
        [weakSelf makePostRequestWithUrl:IDME_WEB_VERIFY_REFRESH_CODE_URL
                              parameters:params
                              completion:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                  NSError *jsonError;
                                  NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                                       options:NSJSONReadingMutableContainers
                                                                                         error:&jsonError];
                                  if (json) {
                                      [weakSelf saveTokenDataFromJson:json scope:scope];
                                      webVerificationResults([json objectForKey:IDME_WEB_VERIFY_ACCESS_TOKEN_PARAM], nil);
                                  } else {
                                      webVerificationResults(nil, [weakSelf notAuthorizedErrorWithUserInfo:@{NSLocalizedDescriptionKey: IDME_WEB_VERIFY_VERIFICATION_FAILED}]);
                                  }
                                  [weakSelf destroyWebNavigationController];
                              }];
    };
    authenticationDelegate.onNavigationUpdate = ^() {
        [weakSelf updateBackButton];
    };
    authenticationDelegate.redirectUri = self.redirectURI;

    [self launchWebNavigationControllerWithDelegate:authenticationDelegate completion:^{
        // GET Access Token via UIWebView flow
        [weakSelf loadWebViewWithRequest:[NSString stringWithFormat:IDME_WEB_VERIFY_SIGN_UP_OR_LOGIN,
                                          _clientID, _redirectURI, scope, [self stringForLoginType:loginType]]];
    }];
}

-(void)registerConnectionInViewController:(UIViewController *)viewController
                                    scope:(NSString *)scope
                                     type:(IDmeWebVerifyConnection)type
                                   result:(IDmeVerifyWebVerifyConnectionResults)callback {
    NSAssert(self.clientID != nil, @"You should initialize the SDK before making requests. Call IDmeWebVerify.initializeWithClientID:redirectURI");
    __weak IDmeWebVerify *weakself = self;
    connectionDelegate = [[IDmeConnectionDelegate alloc] init];
    connectionDelegate.callback = ^(_Nullable id result, NSError* _Nullable error) {
        callback(error);
        [weakself destroyWebNavigationController];
    };
    connectionDelegate.onNavigationUpdate = ^() {
        [weakself updateBackButton];
    };
    connectionDelegate.redirectUri = self.redirectURI;
    [self clearWebViewCacheAndCookies];
    [self setPresentingViewController:viewController];
    [self launchWebNavigationControllerWithDelegate:connectionDelegate completion:^{
        // Register Connection via UIWebView flow
        [weakself getAccessTokenWithScope:scope
                          forceRefreshing:NO
                                   result:^(NSString * _Nullable accessToken, NSError * _Nullable error) {
                                       NSString *requestString = [NSString stringWithFormat:IDME_WEB_VERIFY_REGISTER_CONNECTION_URI,
                                                                  _clientID, _redirectURI, scope,
                                                                  [weakself stringForConnection:type], accessToken ?: @""];
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
    connectionDelegate = [[IDmeConnectionDelegate alloc] init];
    connectionDelegate.callback = ^(_Nullable id result, NSError* _Nullable error) {
        callback(error);
        [weakself destroyWebNavigationController];
    };
    connectionDelegate.onNavigationUpdate = ^() {
        [weakself updateBackButton];
    };
    connectionDelegate.redirectUri = self.redirectURI;
    [self clearWebViewCacheAndCookies];
    [self setPresentingViewController:viewController];
    [self launchWebNavigationControllerWithDelegate:connectionDelegate completion:^{

        // Register Affiliation via UIWebView flow
        [weakself getAccessTokenWithScope:scope
                          forceRefreshing:NO
                                   result:^(NSString * _Nullable accessToken, NSError * _Nullable error) {

                                       NSString *requestString = [NSString stringWithFormat:IDME_WEB_VERIFY_REGISTER_AFFILIATION_URI,
                                                                  _clientID, _redirectURI, [weakself stringForAffiliation:type], accessToken ?: @""];
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

- (void)getAccessTokenWithScope:(NSString* _Nullable)scope forceRefreshing:(BOOL)force result:(IDmeVerifyWebVerifyTokenResults _Nonnull)callback {

    NSString* latestScope = scope;
    if (!latestScope) {
        // get last used scope
         latestScope = [self.keychainData getLatestUsedScope];

        if (!latestScope) {
            // no token has been requested yet (and no scope provided)
            callback(nil, [self noSuchScopeErrorWithUserInfo:nil]);
            return;
        }
    }

    NSString* refreshToken = [self.keychainData refreshTokenForScope:scope];

    if (force) {
        [self refreshTokenForScope:latestScope refreshToken:refreshToken callback:callback];
        return;
    }

    NSString* token = [self.keychainData accessTokenForScope:latestScope];
    NSDate* expiration = [self.keychainData expirationDateForScope:latestScope];
    NSDate* refreshExpiration = [self.keychainData refreshExpirationDateForScope:scope];

    if (token) {
        // check if token has expired
        NSDate* now = [[NSDate alloc] init];
        if ([now compare:expiration] != NSOrderedAscending) {
            // token has expired
            if ([now compare:refreshExpiration] != NSOrderedAscending) {
                // refresh token has expired
                callback(nil, [self refreshTokenExpiredErrorWithUserInfo:@{NSLocalizedDescriptionKey: IDME_WEB_VERIFY_REFRESH_TOKEN_EXPIRED}]);
            } else {
                [self refreshTokenForScope:latestScope refreshToken:refreshToken callback:callback];
            }
        } else {
            callback(token, nil);
        }
    } else {
        // invalid scope passed as argument. There is no token for this scope
        callback(nil, [self noSuchScopeErrorWithUserInfo:nil]);
    }
}

- (void)refreshTokenForScope:(NSString* _Nonnull)scope refreshToken:(NSString* _Nonnull)refreshToken callback:(IDmeVerifyWebVerifyTokenResults _Nonnull)callback {

    @synchronized (pendingRefreshes) {
        if (![pendingRefreshes objectForKey:scope]){
            [pendingRefreshes setObject:[[NSMutableArray alloc] init] forKey:scope];
        }

        NSMutableArray* scopeCallbacks = [pendingRefreshes objectForKey:scope];

        if ([scopeCallbacks count] == 0) {
            // first one wanting to refresh
            NSString* currentRefreshToken = [self.keychainData refreshTokenForScope:scope];
            if (![currentRefreshToken isEqualToString:refreshToken]) {
                // somebody just updated the refreshToken
                NSString* accessToken = [self.keychainData accessTokenForScope:scope];
                if (accessToken) {
                    callback(accessToken, nil);
                } else {
                    callback(nil, [self notAuthorizedErrorWithUserInfo:@{NSLocalizedDescriptionKey: IDME_WEB_VERIFY_VERIFICATION_FAILED}]);
                }
                return;
            }

            __weak IDmeWebVerify *weakself = self;
            [self makePostRequestWithUrl:IDME_WEB_VERIFY_REFRESH_CODE_URL
                              parameters:[NSString stringWithFormat:@"client_id=%@&client_secret=%@&redirect_uri=%@&refresh_token=%@&grant_type=refresh_token",
                                          _clientID, _clientSecret, _redirectURI, refreshToken]
                              completion:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                  @synchronized (pendingRefreshes) {
                                      NSError *jsonError;
                                      NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                                           options:NSJSONReadingMutableContainers
                                                                                             error:&jsonError];
                                      NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse *)response;
                                      if (json && !error && httpResponse && httpResponse.statusCode >= 200 &&  httpResponse.statusCode < 300) {
                                          [weakself saveTokenDataFromJson:json scope:scope];
                                          NSString * accessToken = [json objectForKey:IDME_WEB_VERIFY_ACCESS_TOKEN_PARAM];
                                          if (accessToken) {
                                              [[pendingRefreshes objectForKey:scope] enumerateObjectsUsingBlock:^(id  _Nonnull callback, NSUInteger idx, BOOL * _Nonnull stop) {
                                                  ((IDmeVerifyWebVerifyTokenResults) callback)(accessToken, nil);
                                              }];
                                              [[pendingRefreshes objectForKey:scope] removeAllObjects];
                                              return;
                                          }
                                      }
                                      [[pendingRefreshes objectForKey:scope] enumerateObjectsUsingBlock:^(id  _Nonnull callback, NSUInteger idx, BOOL * _Nonnull stop) {
                                          ((IDmeVerifyWebVerifyTokenResults) callback)(nil, [weakself refreshTokenErrorWithUserInfo:@{NSLocalizedDescriptionKey: IDME_WEB_VERIFY_REFRESH_TOKEN_FAILED}]);
                                      }];
                                      [[pendingRefreshes objectForKey:scope] removeAllObjects];
                                  }
                              }];
        }
        [scopeCallbacks addObject:callback];
    }
}

#pragma mark - Web view Methods
- (void)launchWebNavigationControllerWithDelegate:(id<WKNavigationDelegate, WKUIDelegate>)delegate completion:(void (^ __nullable)(void))completion {

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
- (IDmeWebView * _Nonnull)createWebViewWithDelegate:(id<WKNavigationDelegate, WKUIDelegate>)delegate {
    CGRect parentViewControllerViewFrame = [_presentingViewController.view frame];
    CGRect webViewFrame = CGRectMake(0.0f,
                                     0.0f,
                                     parentViewControllerViewFrame.size.width,
                                     parentViewControllerViewFrame.size.height);

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];

    if ([configuration respondsToSelector:@selector(setWebsiteDataStore:)]) {
        configuration.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    }

    IDmeWebView *webView = [[IDmeWebView alloc] initWithFrame:webViewFrame configuration:configuration];

    webView.navigationDelegate = delegate;
    webView.UIDelegate = delegate;
    webView.allowsBackForwardNavigationGestures = YES;

    return webView;
}

- (void)destroyWebView
{
    if (_webView) {
        [_webView loadHTMLString:@"" baseURL:nil];
        [_webView stopLoading];
        [_webView setNavigationDelegate:nil];
        [_webView setUIDelegate:nil];
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
    [webViewController setTitle:@"ID.me Wallet"];
    [webViewController.view addSubview:[self webView]];

    NSBundle *bundle = [NSBundle bundleForClass:IDmeWebVerify.class];

    if (self.showCancelButton) {
        // Initialize 'Cancel' UIBarButtonItem

        UIBarButtonItem *cancelBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"IDmeWebVerify.bundle/cancel.png"
                                                                                                 inBundle:bundle
                                                                            compatibleWithTraitCollection:nil]
                                                                                style:UIBarButtonItemStyleDone
                                                                               target:cancelTarget
                                                                               action:@selector(cancelTapped:)];
        [webViewController.navigationItem setRightBarButtonItem:cancelBarButtonItem];
    }

    //set up back button
    self.backButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"IDmeWebVerify.bundle/back.png"
                                                                        inBundle:bundle
                                                   compatibleWithTraitCollection:nil]
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(backTapped:)];

    // Initialize and customize UINavigationController with webViewController
    IDmeWebVerifyNavigationController *navigationController = [[IDmeWebVerifyNavigationController alloc] initWithRootViewController:webViewController];
    NSDictionary *titleAttributes = @{NSForegroundColorAttributeName : [UIColor whiteColor]};
    [navigationController.navigationBar setTitleTextAttributes:titleAttributes];
    [navigationController.navigationBar setTintColor:[UIColor whiteColor]];
    [navigationController.navigationBar setBarTintColor:kIDmeWebVerifyColorBlue];

    
    return navigationController;
}

- (void)backTapped:(id)sender {
    if ([_webView canGoBack]) {
        [_webView goBack];
    }
}

- (void)updateBackButton {
    if ([_webView canGoBack]) {
        self.webNavigationController.topViewController.navigationItem.leftBarButtonItem = self.backButton;
    } else {
        self.webNavigationController.topViewController.navigationItem.leftBarButtonItem = nil;
    }
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

#pragma mark - Networking
- (void)makePostRequestWithUrl:(NSString *_Nonnull)urlString parameters:(NSString* _Nonnull)parameters completion:(RequestCompletion)completion {

    NSData *parameterData = [parameters dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:urlString];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue: @"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod:POST_METHOD];
    [request setHTTPBody:parameterData];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:completion];
    
    [task resume];
}

#pragma mark - Keychain access
- (void)saveTokenDataFromJson:(NSDictionary* _Nonnull)json scope:(NSString* _Nonnull)scope {
    // Extract 'access_token' from URL query parameters that are separated by '&'
    NSString *accessToken = [json objectForKey:IDME_WEB_VERIFY_ACCESS_TOKEN_PARAM];
    NSString *refreshToken = [json objectForKey:IDME_WEB_VERIFY_REFRESH_TOKEN_PARAM];
    NSString *expiresIn = [json objectForKey:IDME_WEB_VERIFY_EXPIRATION_PARAM];
    NSString *refreshExpiresIn = [json objectForKey:IDME_WEB_VERIFY_REFRESH_EXPIRATION_PARAM];

    NSDate* expirationDate = [NSDate dateWithTimeIntervalSinceNow:[[NSNumber numberWithInt:[expiresIn intValue]] doubleValue]];
    NSDate* refreshExpirationDate = [NSDate dateWithTimeIntervalSinceNow:[[NSNumber numberWithInt:[refreshExpiresIn intValue]] doubleValue]];
    [self.keychainData setToken:accessToken expirationDate:expirationDate refreshToken:refreshToken refreshExpDate:refreshExpirationDate forScope:scope];
}

#pragma mark - Accessor Methods
- (NSString * _Nullable)clientID {
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

- (NSError * _Nonnull)refreshTokenErrorWithUserInfo:(NSDictionary* _Nullable)userInfo {
    return [self errorWithCode:IDmeWebVerifyErrorCodeRefreshTokenFailed userInfo:userInfo];
}

- (NSError * _Nonnull)refreshTokenExpiredErrorWithUserInfo:(NSDictionary* _Nullable)userInfo {
    return [self errorWithCode:IDmeWebVerifyErrorCodeRefreshTokenExpired userInfo:userInfo];
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

- (NSString * _Nonnull)stringForLoginType:(IDmeWebVerifyLoginType)type {
    switch (type) {
        case IDmeWebVerifyLoginTypeSignUp:
            return @"signup";
            break;
        case IDmeWebVerifyLoginTypeSignIn:
            return @"signin";
            break;
    }
}

@end
