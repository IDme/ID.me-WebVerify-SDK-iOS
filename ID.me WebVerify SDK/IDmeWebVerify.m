//
//  IDmeWebVerify.m,
//  ID.me WebVerify
//
//  Created by Arthur Sabintsev on 9/24/13.
//  Copyright (c) 2013 ID.me, Inc. All rights reserved.
//

#import "IDmeWebVerify.h"

#import "IDmePKCEUtils.h"
#import "IDmeReachability.h"
#import "IDmeWebVerifyNavigationController.h"
#import "IDmeWebVerifyKeychainData.h"

#import <SafariServices/SafariServices.h>

/// API Constants (Production)
#define IDME_WEB_VERIFY_GET_AUTH_URI                    @"oauth/authorize?client_id=%@&redirect_uri=%@&response_type=code&scope=%@"
#define IDME_WEB_VERIFY_GET_USER_PROFILE                @"api/public/v2/data.json?access_token=%@"
#define IDME_WEB_VERIFY_REFRESH_CODE_URL                @"oauth/token"
#define IDME_WEB_VERIFY_REGISTER_CONNECTION_URI         @"oauth/authorize?client_id=%@&redirect_uri=%@&response_type=code&op=signin&scope=%@&connect=%@"
#define IDME_WEB_VERIFY_REGISTER_AFFILIATION_URI        @"oauth/authorize?client_id=%@&redirect_uri=%@&response_type=code&scope=%@"
#define IDME_WEB_VERIFY_SIGN_UP_OR_LOGIN                @"oauth/authorize?client_id=%@&redirect_uri=%@&response_type=code&scope=%@&op=%@"

/// Data Constants
#define IDME_WEB_VERIFY_ACCESS_TOKEN_PARAM              @"access_token"
#define IDME_WEB_VERIFY_EXPIRATION_PARAM                @"expires_in"
#define IDME_WEB_VERIFY_REFRESH_EXPIRATION_PARAM        @"refresh_expires_in"
#define IDME_WEB_VERIFY_REFRESH_TOKEN_PARAM             @"refresh_token"
#define IDME_WEB_VERIFY_ACCESS_DENIED_ERROR             @"access_denied"
#define IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM         @"error_description"
#define IDME_WEB_VERIFY_ERROR_PARAM                     @"error"

// HTTP methods
#define POST_METHOD        @"POST"

/// Color Constants
#define kIDmeWebVerifyColorBlue                     [UIColor colorWithRed:48.0f/255.0f green:160.0f/255.0f blue:224.0f/255.0f alpha:1.0f]

// PKCE constants
#define CODE_VERIFIER_SIZE    64
#define CODE_CHALLENGE_METHOD @"S256"

@interface IDmeWebVerify () <SFSafariViewControllerDelegate>

typedef void (^RequestCompletion)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

@property (nonatomic, copy) NSString *clientID;
@property (nonatomic, copy) NSString *clientSecret;
@property (nonatomic, copy) NSString *redirectURI;

@property (nonatomic, strong) IDmeWebVerifyKeychainData *keychainData;
@property (nonatomic, strong) SFSafariViewController *safariViewController;
@property (nonatomic, strong) IDmeReachability *reachability;

@property (copy, nonatomic, nullable) IDmeVerifyWebVerifyTokenResults webVerificationResults;

@property (nonatomic, nullable, strong) NSString *codeVerifier;
@property (nonatomic, nullable, strong) NSString *codeChallenge;
@property (nonatomic, nullable, strong) NSString *codeChallengeMethod;

@end

@implementation IDmeWebVerify {
    NSMutableDictionary* pendingRefreshes;
    NSString* BASE_URL;
    NSString* requestScope;
}

@synthesize codeVerifier = _codeVerifier;
@synthesize codeChallenge = _codeChallenge;
@synthesize codeChallengeMethod = _codeChallengeMethod;

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
        pendingRefreshes = [[NSMutableDictionary alloc] init];
        self.errorPageTitle = NSLocalizedString(@"Unavailable", @"IDme WebVerify SDK disconnected page title");
        self.errorPageDescription = NSLocalizedString(@"ID.me Wallet requires an internet connection.", @"IDme WebVerify SDK disconnected page description");
        self.errorPageRetryAction = NSLocalizedString(@"Retry", @"IDme WebVerify SDK disconnected page retry action");
        self.reachability = [IDmeReachability reachabilityForInternetConnection];
        BASE_URL = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"IDmeWebVerifyAPIDomainURL"] ?: @"https://api.id.me/";
    }
    
    return self;
}

+ (void)initializeWithClientID:(NSString * _Nonnull)clientID clientSecret:(NSString * _Nonnull)clientSecret redirectURI:(NSString * _Nonnull)redirectURI {
    NSAssert([IDmeWebVerify sharedInstance].clientID == nil, @"You cannot initialize IDmeWebVerify more than once.");
    [[IDmeWebVerify sharedInstance] setClientID:clientID];
    [[IDmeWebVerify sharedInstance] setClientSecret:clientSecret];
    [[IDmeWebVerify sharedInstance] setRedirectURI:redirectURI];
}

#pragma mark - Verificaton public methods

- (void)verifyUserInViewController:(UIViewController *)externalViewController
                             scope:(NSString *)scope
                   withTokenResult:(IDmeVerifyWebVerifyTokenResults)webVerificationResults {
    NSAssert(self.clientID != nil, @"You should initialize the SDK before making requests. Call IDmeWebVerify.initializeWithClientID:redirectURI");
    NSAssert(![self isAuthenticationFlowInProgress], @"There is an authentication flow in progress. You should not call IDmeWebVerify.verifyUserInViewController:scope:withTokenResult until the previous has finished");

    NSString *stringUrl = [NSString stringWithFormat:[self urlStringWithQueryString:IDME_WEB_VERIFY_GET_AUTH_URI],
                           self.clientID,
                           self.redirectURI,
                           scope];
    stringUrl = [self createAndAddPKCEParametersToQuery:stringUrl];
    NSURL* url = [NSURL URLWithString:stringUrl];

    [self launchSafariFromPresenting:externalViewController url:url];
    requestScope = scope;
    self.webVerificationResults = webVerificationResults;
}

- (void)registerOrLoginInViewController:(UIViewController *)externalViewController
                                 scope:(NSString *)scope
                             loginType:(IDmeWebVerifyLoginType)loginType
                       withTokenResult:(IDmeVerifyWebVerifyTokenResults)webVerificationResults {
    NSAssert(self.clientID != nil, @"You should initialize the SDK before making requests. Call IDmeWebVerify.initializeWithClientID:redirectURI");
    NSAssert(![self isAuthenticationFlowInProgress], @"There is an authentication flow in progress. You should not call IDmeWebVerify.verifyUserInViewController:scope:withTokenResult until the previous has finished");

    NSString *stringUrl = [NSString stringWithFormat:[self urlStringWithQueryString:IDME_WEB_VERIFY_SIGN_UP_OR_LOGIN],
                           self.clientID,
                           self.redirectURI,
                           scope,
                           [self stringForLoginType:loginType]];
    stringUrl = [self createAndAddPKCEParametersToQuery:stringUrl];
    NSURL* url = [NSURL URLWithString:stringUrl];

    [self launchSafariFromPresenting:externalViewController url:url];
    requestScope = scope;
    self.webVerificationResults = webVerificationResults;

}

- (void)registerConnectionInViewController:(UIViewController *)viewController
                                    scope:(NSString *)scope
                                     type:(IDmeWebVerifyConnection)type
                                   result:(IDmeVerifyWebVerifyTokenResults)callback {
    NSAssert(self.clientID != nil, @"You should initialize the SDK before making requests. Call IDmeWebVerify.initializeWithClientID:redirectURI");
    NSAssert(![self isAuthenticationFlowInProgress], @"There is an authentication flow in progress. You should not call IDmeWebVerify.verifyUserInViewController:scope:withTokenResult until the previous has finished");

    NSString *stringUrl = [NSString stringWithFormat:[self urlStringWithQueryString:IDME_WEB_VERIFY_REGISTER_CONNECTION_URI],
                           self.clientID,
                           self.redirectURI,
                           scope,
                           [self stringForConnection:type]];
    stringUrl = [self createAndAddPKCEParametersToQuery:stringUrl];
    NSURL* url = [NSURL URLWithString:stringUrl];

    [self launchSafariFromPresenting:viewController url:url];
    requestScope = scope;
    self.webVerificationResults = callback;
}

- (void)registerAffiliationInViewController:(UIViewController *)viewController
                            scope:(NSString *)scope
                             type:(IDmeWebVerifyAffiliation)type
                           result:(IDmeVerifyWebVerifyTokenResults)callback {
    NSAssert(self.clientID != nil, @"You should initialize the SDK before making requests. Call IDmeWebVerify.initializeWithClientID:redirectURI");
    NSAssert(![self isAuthenticationFlowInProgress], @"There is an authentication flow in progress. You should not call IDmeWebVerify.verifyUserInViewController:scope:withTokenResult until the previous has finished");

    NSString *stringUrl = [NSString stringWithFormat:[self urlStringWithQueryString:IDME_WEB_VERIFY_REGISTER_AFFILIATION_URI],
                           self.clientID,
                           self.redirectURI,
                           [self stringForAffiliation:type]];
    stringUrl = [self createAndAddPKCEParametersToQuery:stringUrl];
    NSURL* url =  [NSURL URLWithString:stringUrl];

    [self launchSafariFromPresenting:viewController url:url];
    requestScope = scope;
    self.webVerificationResults = callback;
}

#pragma mark - Other public functions

- (void)getUserProfileWithScope:(NSString* _Nullable)scope result:(IDmeVerifyWebVerifyProfileResults _Nonnull)webVerificationResults {
    __weak IDmeWebVerify *weakself = self;
    [self getAccessTokenWithScope:scope
                  forceRefreshing:NO
                           result:^(NSString * _Nullable accessToken, NSError * _Nullable error) {
                                if (!accessToken) {
                                    [weakself callWebVerificationResultsWithToken:nil error:error];
                                    return;
                                }

                                NSString *requestString = [NSString stringWithFormat:[weakself urlStringWithQueryString:IDME_WEB_VERIFY_GET_USER_PROFILE], accessToken];
                                requestString = [requestString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                                NSURL *requestURL = [NSURL URLWithString:requestString];
                                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
                                [request setValue:@"IDmeWebVerify-SDK-iOS" forHTTPHeaderField:@"X-API-ORIGIN"];

                                NSURLSession *session = [NSURLSession sharedSession];
                                NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
                                        NSUInteger statusCode = [httpResponse statusCode];

                                        NSMutableDictionary *userProfile = nil;
                                        NSError *verificationError = nil;

                                        if ([data length] && error == nil && statusCode == 200) {
                                            NSError* serializingError;
                                            userProfile = [[NSJSONSerialization JSONObjectWithData:data
                                                                                           options:NSJSONReadingAllowFragments | NSJSONReadingMutableContainers error:&serializingError] mutableCopy];
                                            [weakself removeNull:userProfile];
                                            if (serializingError) {
                                                verificationError = [weakself failedFetchingProfileErrorWithUserInfo:error.userInfo];
                                            }
                                        } else if (statusCode == 401) {
                                            // TODO: refresh token
                                            verificationError = [weakself notAuthorizedErrorWithUserInfo:nil];
                                        } else {
                                            verificationError = [weakself failedFetchingProfileErrorWithUserInfo:error.userInfo];
                                        }
                                        webVerificationResults([userProfile copy], verificationError);
                                    });
                                    
                                }];
                                [task resume];
    }];
}

- (void)logout {
    [self.keychainData clean];
    // can we delete cookies from Safari?
}

- (BOOL)isLoggedIn {
    return ![self.keychainData isClean];
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
            [self makePostRequestWithUrl:[self urlStringWithQueryString:IDME_WEB_VERIFY_REFRESH_CODE_URL]
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
- (void)launchSafariFromPresenting:(UIViewController* _Nonnull)presenting url:(NSURL* _Nonnull)url {

    // Initialize _webNavigationController
    self.safariViewController = [[SFSafariViewController alloc] initWithURL:url];
    self.safariViewController.delegate = self;

    // Present _webNavigationController
    [presenting presentViewController:self.safariViewController animated:YES completion:nil];

}

#pragma mark - Parsing Methods (Private)
- (NSMutableDictionary * _Nonnull)parseQueryParametersFromURL:(NSString * _Nonnull)query {
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

#pragma mark - UIApplicationDelegate

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_9_3
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return [self application:application
                     openURL:url
           sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                  annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
}
#endif

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{

    [self.safariViewController.presentingViewController dismissViewControllerAnimated:YES
                                                                           completion:nil];
    _safariViewController = nil;

    if (self.codeVerifier == nil) {
        return NO;
    }

    if ([url.absoluteString hasPrefix:self.redirectURI]) {
        NSString *beforeQueryString = [NSString stringWithFormat:@"%@?", self.redirectURI];
        NSDictionary *parameters = [self parseQueryParametersFromURL:[url.absoluteString stringByReplacingOccurrencesOfString:beforeQueryString withString:@""]];
        NSString *code = [parameters objectForKey:@"code"];
        if (code) {
            NSString *codeVerifier = self.codeVerifier;
            self.codeVerifier = nil;
            self.codeChallenge = nil;
            self.codeChallengeMethod = nil;

            NSString *params = [NSString stringWithFormat:@"client_id=%@&client_secret=%@&redirect_uri=%@&code=%@&grant_type=authorization_code&code_verifier=%@",
                                self.clientID, self.clientSecret, self.redirectURI, code, codeVerifier];

            __weak IDmeWebVerify *weakSelf = self;
            [self makePostRequestWithUrl:[self urlStringWithQueryString:IDME_WEB_VERIFY_REFRESH_CODE_URL]
                              parameters:params
                              completion:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                  NSError *jsonError;
                                  NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                                       options:NSJSONReadingMutableContainers
                                                                                         error:&jsonError];

                                  NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
                                  if (error || statusCode < 200 || statusCode >= 300) {
                                      // Error from server, we may have a response in the json
                                      NSError *callbackError = [weakSelf codeAuthenticationErrorWithUserInfo:json];
                                      [weakSelf callWebVerificationResultsWithToken:nil error:callbackError];
                                      return;
                                  }

                                  if (json) {
                                      [weakSelf saveTokenDataFromJson:json scope:requestScope];
                                      [weakSelf callWebVerificationResultsWithToken:[json objectForKey:IDME_WEB_VERIFY_ACCESS_TOKEN_PARAM] error:nil];
                                  } else {
                                      [weakSelf callWebVerificationResultsWithToken:nil
                                                                              error:[weakSelf notAuthorizedErrorWithUserInfo:@{
                                                                                        NSLocalizedDescriptionKey: IDME_WEB_VERIFY_VERIFICATION_FAILED
                                                                                    }]];
                                  }
                              }];
        } else if ([parameters objectForKey:IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM] && [parameters objectForKey:IDME_WEB_VERIFY_ERROR_PARAM]) {
            // Extract 'error_description' from URL query parameters that are separated by '&'
            NSString *errorDescription = [parameters objectForKey:IDME_WEB_VERIFY_ERROR_DESCRIPTION_PARAM];
            errorDescription = [errorDescription stringByReplacingOccurrencesOfString:@"+" withString:@" "];
            NSDictionary *details = @{ NSLocalizedDescriptionKey : errorDescription };
            NSError *error;
            if ([[parameters objectForKey:IDME_WEB_VERIFY_ERROR_PARAM] isEqualToString:IDME_WEB_VERIFY_ACCESS_DENIED_ERROR]) {
                error = [[NSError alloc] initWithDomain:IDME_WEB_VERIFY_ERROR_DOMAIN code:IDmeWebVerifyErrorCodeVerificationWasDeniedByUser userInfo:details];
            } else {
                error = [self codeAuthenticationErrorWithUserInfo:details];
            }
            [self callWebVerificationResultsWithToken:nil error:error];
        }
        return YES;
    }
    
    return NO;
}

- (void)callWebVerificationResultsWithToken:(NSString * _Nullable)token error:(NSError * _Nullable)error {
    if (!self.webVerificationResults) {
        return;
    }

    void (^callback)(NSString * _Nullable token, NSError * _Nullable error) = self.webVerificationResults;
    self.webVerificationResults = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        callback(token, error);
    });
}

#pragma mark - SFSafariViewControllerDelegate

-(void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    _safariViewController = nil;
    [self callWebVerificationResultsWithToken:nil error:[self errorWithCode:IDmeWebVerifyErrorCodeVerificationWasCanceledByUser userInfo:nil]];
}

#pragma mark - Networking

- (NSString *)createAndAddPKCEParametersToQuery:(NSString *)url {
    IDmePKCEUtils *pkceUtils = [IDmePKCEUtils new];
    self.codeVerifier = [pkceUtils generateCodeVerifierWithSize:CODE_VERIFIER_SIZE];
    self.codeChallenge = [pkceUtils encodeBase64:[pkceUtils sha256:self.codeVerifier]];
    self.codeChallengeMethod = CODE_CHALLENGE_METHOD;

    return [NSString stringWithFormat:@"%@&code_challenge=%@&code_challenge_method=%@", url, self.codeChallenge, self.codeChallengeMethod];
}

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

#pragma mark - Other auxiliary functions

- (BOOL)isAuthenticationFlowInProgress {
    return _safariViewController != nil || _webVerificationResults != nil;
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

- (NSError * _Nonnull)codeAuthenticationErrorWithUserInfo:(NSDictionary * _Nullable)userInfo {
    return [self errorWithCode:IDmeWebVerifyErrorCodeAuthenticationFailed userInfo:userInfo];
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

- (NSString * _Nonnull)urlStringWithQueryString:(NSString* _Nonnull)string {
    return [BASE_URL stringByAppendingString:string];
}

@end
