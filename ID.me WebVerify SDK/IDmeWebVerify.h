//
//  IDmeWebVerify.h
//  ID.me WebVerify
//
//  Created by Arthur Sabintsev on 9/24/13.
//  Copyright (c) 2013 ID.me, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#define IDME_WEB_VERIFY_VERIFICATION_WAS_CANCELED    @"The user exited the modal navigationController before being verified."
#define IDME_WEB_VERIFY_VERIFICATION_FAILED          @"Authorization process failed."
#define IDME_WEB_VERIFY_REFRESH_TOKEN_FAILED         @"Refreshing the access token failed."
#define IDME_WEB_VERIFY_REFRESH_TOKEN_EXPIRED        @"The refresh token has expired."
#define IDME_WEB_VERIFY_ERROR_DOMAIN                 @"ID.me Web Verify Error Domain"


@interface IDmeWebVerify : NSObject

typedef void (^IDmeVerifyWebVerifyProfileResults)(NSDictionary  * _Nullable userProfile, NSError  * _Nullable error);
typedef void (^IDmeVerifyWebVerifyTokenResults)(NSString *  _Nullable accessToken, NSError  * _Nullable error);

/// This typedef differentiates errors that may occur when authentication a user
typedef NS_ENUM(NSUInteger, IDmeWebVerifyErrorCode)
{
    /*!
     * Error occurs if user succesfully verified their group affiliation, but there was a problem with the user's profile being returned.
     * This should never occur, but this error was added to handle a rare situation involving the inability to reach ID.me's server.
     */
    IDmeWebVerifyErrorCodeVerificationDidFailToFetchUserProfile = 1001,
    
    /// Erorr occurs if user succesfully verified their group affiliation, but decided to deny access to your app at the end of the OAuth flow.
    IDmeWebVerifyErrorCodeVerificationWasDeniedByUser,
    
    /// Error occurs if user exits modal navigation controller before OAuth flow could complete.
    IDmeWebVerifyErrorCodeVerificationWasCanceledByUser,

    /// Error occurs if user authentication fails without the user cancelling the process.
    IDmeWebVerifyErrorCodeAuthenticationFailed,

    /// Error occurs if getUserProfileWithScope:result: or getAccessTokenWithScope:forceRefreshing:result: are called with a scope that has no access token associated.
    IDmeWebVerifyErrorCodeNoSuchScope,

    /// Error thrown when there is no valid token or when a response status code is 401.
    IDmeWebVerifyErrorCodeNotAuthorized,

    /// Error thrown when there is an error refreshing the requested access token
    IDmeWebVerifyErrorCodeRefreshTokenFailed,

    /// Error thrown when the refresh token has expired
    IDmeWebVerifyErrorCodeRefreshTokenExpired,

    /// Error thrown for not implemented features like token refreshing.
    IDmeWebVerifyErrorCodeNotImplemented
};

/// This enum defines the different connections that a user can connect to. Used to login to the different platforms
typedef NS_ENUM(NSUInteger, IDmeWebVerifyConnection)
{
    IDWebVerifyConnectionFacebook,
    IDWebVerifyConnectionGooglePlus,
    IDWebVerifyConnectionLinkedin,
    IDWebVerifyConnectionPaypal
};

/// This enum defines the different IDs that a user can connect to his account.
typedef NS_ENUM(NSUInteger, IDmeWebVerifyAffiliation)
{
    IDmeWebVerifyAffiliationGovernment,
    IDmeWebVerifyAffiliationMilitary,
    IDmeWebVerifyAffiliationResponder,
    IDmeWebVerifyAffiliationStudent,
    IDmeWebVerifyAffiliationTeacher
};

/// This enum defines the desired action, either sign-in or sign-up
typedef NS_ENUM(NSUInteger, IDmeWebVerifyLoginType)
{
    IDmeWebVerifyLoginTypeSignUp,
    IDmeWebVerifyLoginTypeSignIn
};

/// The ID.me WebVerify Singleton method
+ (IDmeWebVerify * _Nonnull)sharedInstance;

/// Specifies if cancel button will be shown in the webView or not. Default is YES.
@property (nonatomic) Boolean showCancelButton;
@property (nonatomic, strong, nullable) NSString *errorPageTitle;
@property (nonatomic, strong, nullable) NSString *errorPageDescription;
@property (nonatomic, strong, nullable) NSString *errorPageRetryAction;

/**
 @param clientID The clientID provided by ID.me when registering the app at @b http://developer.id.me
 @param redierectURI The redirectURI provided to ID.me when registering your app at @b http://developer.id.me
 */
+ (void)initializeWithClientID:(NSString * _Nonnull)clientID clientSecret:(NSString * _Nonnull)clientSecret redirectURI:(NSString * _Nonnull)redirectURI;

/**
 @param externalViewController The viewController which will present the modal navigationController
 @param scope The type of group verification that should be presented.
 @param webVerificationResults A block that returns an NSString object representing a valid access token or an NSError object.
 */
- (void)verifyUserInViewController:(UIViewController * _Nonnull)externalViewController
                             scope:(NSString * _Nonnull)scope
                   withTokenResult:(IDmeVerifyWebVerifyTokenResults _Nonnull)webVerificationResults;

/**
 This function should be used if it is known if the user wants to sign in or sign up. Otherwise works the same as verifyUserInViewController:scope:webVerificationResults
 @param externalViewController The viewController which will present the modal navigationController
 @param scope The type of group verification that should be presented.
 @param loginType The type of operation desired (sign in or sign up)
 @param webVerificationResults A block that returns an NSString object representing a valid access token or an NSError object.
 */
- (void)registerOrLoginInViewController:(UIViewController * _Nonnull)externalViewController
                                  scope:(NSString * _Nonnull)scope
                              loginType:(IDmeWebVerifyLoginType)loginType
                        withTokenResult:(IDmeVerifyWebVerifyTokenResults _Nonnull)webVerificationResults;

/**
 Returns the User profile with the stored access token. 
 @param scope The type of token to be used. If nil then the last token will be used
 @param webVerificationResults A block that returns an NSDictionary object and an NSError object. The verified user's profile is stored in an @c NSDictionary object as @c JSON data. If no data was returned, or an error occured, @c NSDictionary is @c nil and @c NSError returns an error code and localized description of the specific error that occured.
 */
- (void)getUserProfileWithScope:(NSString* _Nullable)scope result:(IDmeVerifyWebVerifyProfileResults _Nonnull)webVerificationResults;

/**
 Returns a valid access token. If the currently saved access token is valid it will be returned. If not, then it will be refreshed.
 @param scope The type of token to be used. If nil then the last token will be used
 @param forceRefreshing Force the SDK to refresh the token and do not use the current one.
 @param callback A block that returns an NSString object representing a valid access token or an NSError object.
 */
- (void)getAccessTokenWithScope:(NSString* _Nullable)scope forceRefreshing:(BOOL)force result:(IDmeVerifyWebVerifyTokenResults _Nonnull)callback;

/**
 Invalidates and deletes all tokens stored by the SDK.
 */
- (void)logout;

/**
 Registers a new connection for the user.
 */
- (void)registerConnectionInViewController:(UIViewController * _Nonnull)viewController scope:(NSString * _Nonnull)scope type:(IDmeWebVerifyConnection)type result:(IDmeVerifyWebVerifyTokenResults _Nonnull)callback;

/**
 Registers a new ID for the user.
 */
- (void)registerAffiliationInViewController:(UIViewController * _Nonnull)viewController scope:(NSString * _Nonnull)scope type:(IDmeWebVerifyAffiliation)type result:(IDmeVerifyWebVerifyTokenResults _Nonnull)callback;

/**
 Call this method from the [UIApplicationDelegate application:openURL:sourceApplication:annotation:] method
 of the AppDelegate for your app. It should be invoked for the proper processing of responses during interaction
 with the native Facebook app or Safari as part of SSO authorization flow or Facebook dialogs.
 - Parameter application: The application as passed to [UIApplicationDelegate application:openURL:sourceApplication:annotation:].
 - Parameter url: The URL as passed to [UIApplicationDelegate application:openURL:sourceApplication:annotation:].
 - Parameter sourceApplication: The sourceApplication as passed to [UIApplicationDelegate application:openURL:sourceApplication:annotation:].
 - Parameter annotation: The annotation as passed to [UIApplicationDelegate application:openURL:sourceApplication:annotation:].
 - Returns: YES if the url was intended for the IDmeWebVerify SDK, NO if not.
 */
- (BOOL)application:(UIApplication *_Nonnull)application
            openURL:(NSURL *_Nonnull)url
  sourceApplication:(NSString *_Nonnull)sourceApplication
         annotation:(id _Nonnull)annotation;

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_9_3
/**
 Call this method from the [UIApplicationDelegate application:openURL:options:] method
 of the AppDelegate for your app. It should be invoked for the proper processing of responses during interaction
 with the native Facebook app or Safari as part of SSO authorization flow or Facebook dialogs.
 - Parameter application: The application as passed to [UIApplicationDelegate application:openURL:options:].
 - Parameter url: The URL as passed to [UIApplicationDelegate application:openURL:options:].
 - Parameter options: The options dictionary as passed to [UIApplicationDelegate application:openURL:options:].
 - Returns: YES if the url was intended for the IDmeWebVerify SDK, NO if not.
 */
- (BOOL)application:(UIApplication *_Nonnull)application
            openURL:(NSURL *_Nonnull)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> * _Nonnull)options;
#endif

@end
