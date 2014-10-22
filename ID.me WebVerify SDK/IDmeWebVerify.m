//
//  IDmeWebVerify.m,
//  ID.me WebVerify
//
//  Created by Arthur Sabintsev on 9/24/13.
//  Copyright (c) 2013 ID.me, Inc. All rights reserved.
//

#import "IDmeWebVerify.h"
#import "IDmeWebVerifyNavigationController.h"

/// API Constants (Production)
#define IDME_VERIFY_GET_AUTH_URI                        @"https://api.id.me/oauth/authorize?client_id=%@&redirect_uri=%@&response_type=token&scope=%@"
#define IDME_VERIFY_GET_USER_PROFILE                    @"https://api.id.me/api/public/v2/%@.json?access_token=%@"

/// Data Constants
#define IDME_VERIFY_ACCESS_TOKEN_PARAM                  @"access_token"
#define IDME_VERIFY_ERROR_DESCRIPTION_PARAM             @"error_description"

/// Color Constants
#define kIDmeVerifyColorGreen                           [UIColor colorWithRed:46.0f/255.0f green:147.0f/255.0f blue:125.0f/255.0f alpha:1.0f]
#define kIDmeVerifyColorBlack                           [UIColor colorWithRed:234.0f/255.0f green:235.0f/255.0f blue:235.0f/255.0f alpha:1.0f]

/// Affiliation Scope Constants
NSString *const kIDmeVerifyScopeMilitary                = @"military";
NSString *const kIDmeVerifyScopeStudent                 = @"student";
NSString *const kIDmeVerifyScopeTeacher                 = @"teacher";
NSString *const kIDmeVerifyScopeResponder               = @"responder";

@interface IDmeWebVerify () <UIWebViewDelegate>
@property (nonatomic, copy) IDmeVerifyWebVerifyResults webVerificationResults;
@property (nonatomic, copy) NSString *clientID;
@property (nonatomic, copy) NSString *redirectURI;
@property (nonatomic, copy) NSString *affiliationScope;
@property (nonatomic, assign) IDmeWebVerifyAffiliationType affiliationType;
@property (nonatomic, strong) UIViewController *presentingViewController;
@property (nonatomic, strong) IDmeWebVerifyNavigationController *webNavigationController;
@property (nonatomic, strong) UIWebView *webView;

@end

@implementation IDmeWebVerify

#pragma mark - Initialization Methods
+ (IDmeWebVerify *)sharedInstance
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self clearWebViewCacheAndCookies];
    }
    
    return self;
}

#pragma mark - Authorization Methods (Public)
- (void)verifyUserInViewController:(UIViewController *)externalViewController
                     withClientID:(NSString *)clientID
                      redirectURI:(NSString *)redirectURI
                  affiliationType:(IDmeWebVerifyAffiliationType)affiliationType
                       withResults:(IDmeVerifyWebVerifyResults)webVerificationResults
{
    [self clearWebViewCacheAndCookies];
    [self setClientID:clientID];
    [self setRedirectURI:redirectURI];
    [self setAffiliationType:affiliationType];
    [self setScopeWithAffiliationType:affiliationType];
    [self setPresentingViewController:externalViewController];
    [self setWebVerificationResults:webVerificationResults];
    [self launchWebNavigationController];
}

#pragma mark - Authorization Methods (Private)
- (void)launchWebNavigationController
{
    // Initialize _webView
    _webView = [self createWebView];
    
    // Initialize _webNavigationController
    self.webNavigationController = [self createWebNavigationController];
    
    // Present _webNavigationController
    [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationPortrait animated:YES];
    [self.presentingViewController presentViewController:_webNavigationController animated:YES completion:^{
        
        // GET Access Token via UIWebView flow
        [self loadWebViewWithAccessTokenRequestPage];
        
    }];
}

- (void)loadWebViewWithAccessTokenRequestPage
{
    NSString *requestString = [NSString stringWithFormat:IDME_VERIFY_GET_AUTH_URI, _clientID, _redirectURI, _affiliationScope];
    requestString = [requestString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *requestURL = [NSURL URLWithString:requestString];
    NSURLRequest *request = [NSURLRequest requestWithURL:requestURL];
    [_webView loadRequest:request];
}

- (void)getUserProfile:(NSString *)accessToken
{
    NSString *requestString = [NSString stringWithFormat:IDME_VERIFY_GET_USER_PROFILE, _affiliationScope, accessToken];
    
    requestString = [requestString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *requestURL = [NSURL URLWithString:requestString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
    [request setValue:@"iOSVerifySDK" forHTTPHeaderField:@"X-API-ORIGIN"];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    // Perform asynchronous API request to fetch user profile data
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
            NSUInteger statusCode = [httpResponse statusCode];
            if ([data length]) {
                NSDictionary *results = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                NSDictionary *userProfile = [self testResultsForNull:results];
                if (statusCode == 200) {
                    _webVerificationResults(userProfile, nil);
                }
            } else {
                NSError *modifiedError = [[NSError alloc] initWithDomain:IDME_WEBVERIFY_ERROR_DOMAIN
                                                                    code:IDmeWebVerifyErrorCodeVerificationDidFailToFetchUserProfile
                                                                userInfo:error.userInfo];
                _webVerificationResults(nil, modifiedError);
            }
            
            // Dismiss _webViewController and clear _webView cache
            [self destroyWebNavigationController:self];
        });
    }];
}

#pragma mark - WebView Persistance Methods (Private)
- (UIWebView *)createWebView
{
    CGRect parentViewControllerViewFrame = [self.presentingViewController.view frame];
    CGRect webViewFrame = CGRectMake(0.0f,
                                     0.0f,
                                     parentViewControllerViewFrame.size.width,
                                     parentViewControllerViewFrame.size.height);
    UIWebView *webView = [[UIWebView alloc] initWithFrame:webViewFrame];
    webView.delegate = self;
    webView.scalesPageToFit = YES;
    
    return webView;
}

- (void)destroyWebView
{
    if ( [self webView] ) {
        [_webView loadHTMLString:@"" baseURL:nil];
        [_webView stopLoading];
        [_webView setDelegate:nil];
        [_webView removeFromSuperview];
        [self setWebView:nil];
    }
}

- (void)clearWebViewCacheAndCookies
{
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

- (IDmeWebVerifyNavigationController *)createWebNavigationController
{
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
    NSDictionary *buttonAttributes = @{NSForegroundColorAttributeName : [UIColor blackColor]};
    [cancelBarButtonItem setTitleTextAttributes:buttonAttributes forState:UIControlStateNormal];
    [cancelBarButtonItem setTintColor:kIDmeVerifyColorGreen];
    [webViewController.navigationItem setLeftBarButtonItem:cancelBarButtonItem];
    
    // Initialize and customize UINavigationController with webViewController
    IDmeWebVerifyNavigationController *navigationController = [[IDmeWebVerifyNavigationController alloc] initWithRootViewController:webViewController];
    NSDictionary *titleAttributes = @{NSForegroundColorAttributeName : kIDmeVerifyColorGreen};
    [navigationController.navigationBar setTitleTextAttributes:titleAttributes];
    [navigationController.navigationBar setTintColor:kIDmeVerifyColorBlack];
    
    return navigationController;
}

- (void)destroyWebNavigationController:(id)sender
{
    if ([sender isMemberOfClass:[UIBarButtonItem class]]) {
        NSDictionary *details = @{ NSLocalizedDescriptionKey : IDME_WEBVERIFY_VERIFICATION_WAS_CANCELED };
        NSError *error = [[NSError alloc] initWithDomain:IDME_WEBVERIFY_ERROR_DOMAIN
                                                    code:IDmeWebVerifyErrorCodeVerificationWasCanceledByUser
                                                userInfo:details];
        _webVerificationResults(nil, error);
    }
    
    [self.webNavigationController dismissViewControllerAnimated:YES completion:^{
        [self destroyWebView];
        [self clearWebViewCacheAndCookies];
        [self setWebNavigationController:nil];
    }];
}

#pragma mark - Parsing Methods (Private)
- (NSMutableDictionary *)parseQueryParametersFromURL:(NSString *)query;
{
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

- (NSDictionary *)testResultsForNull:(NSDictionary *)results
{
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
- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    // Get string of current visible webpage
    NSString *query = [[webView.request.mainDocumentURL absoluteString] copy];
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
    if ([parameters objectForKey:IDME_VERIFY_ACCESS_TOKEN_PARAM]) {
        
        // Extract 'access_token' from URL query parameters that are separated by '&'
        NSString *accessToken = [parameters objectForKey:IDME_VERIFY_ACCESS_TOKEN_PARAM];
        [self getUserProfile:accessToken];
        
    } else if ([parameters objectForKey:IDME_VERIFY_ERROR_DESCRIPTION_PARAM]) {
        
        // Extract 'error_description' from URL query parameters that are separated by '&'
        NSString *errorDescription = [parameters objectForKey:IDME_VERIFY_ERROR_DESCRIPTION_PARAM];
        errorDescription = [errorDescription stringByReplacingOccurrencesOfString:@"+" withString:@" "];
        NSDictionary *details = @{ NSLocalizedDescriptionKey : errorDescription };
        NSError *error = [[NSError alloc] initWithDomain:IDME_WEBVERIFY_ERROR_DOMAIN code:IDmeWebVerifyErrorCodeVerificationWasDeniedByUser userInfo:details];
        _webVerificationResults(nil, error);
        [self destroyWebNavigationController:self];
        
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSLog(@"%@", request.URL.absoluteURL.absoluteString);
    return YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"webView:didFailLoadWithError : %@", error);
}

#pragma mark - Accessor Methods
- (NSString *)clientID
{
    if ( !_clientID ) {
        NSLog(@"You have not set your 'clientID'! Please set it using the startWithClientID: method.");
    }
    
    return (_clientID) ? _clientID : nil;
}

- (void)setScopeWithAffiliationType:(IDmeWebVerifyAffiliationType)affiliationType
{
    switch ([self affiliationType]) {
        case IDmeWebVerifyAffiliationTypeMilitary: {
            _affiliationScope = kIDmeVerifyScopeMilitary;
        } break;
            
        case IDmeWebVerifyAffiliationTypeStudent: {
            _affiliationScope = kIDmeVerifyScopeStudent;
        } break;
            
        case IDmeWebVerifyAffiliationTypeTeacher: {
            _affiliationScope = kIDmeVerifyScopeTeacher;
        } break;
            
        case IDmeWebVerifyAffiliationTypeResponder: {
            _affiliationScope = kIDmeVerifyScopeResponder;
        } break;
    }
}

@end
