//
//  IDmeWebVerify.h
//  ID.me WebVerify
//
//  Created by Arthur Sabintsev on 9/24/13.
//  Copyright (c) 2013 ID.me, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#define IDME_WEB_VERIFY_VERIFICATION_WAS_CANCELED    @"The user exited the modal navigationController before being verified."
#define IDME_WEB_VERIFY_ERROR_DOMAIN                 @"ID.me Web Verify Error Domain"

@interface IDmeWebVerify : NSObject

typedef void (^IDmeVerifyWebVerifyResults)(NSDictionary  * _Nullable userProfile, NSError  * _Nullable error, NSString *  _Nullable accessToken);

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
    IDmeWebVerifyErrorCodeVerificationWasCanceledByUser
};

/// THe ID.me WebVerify Singleton method
+ (IDmeWebVerify * _Nonnull)sharedInstance;

/**
 @param clientID The clientID provided by ID.me when registering the app at @b http://developer.id.me
 @param redierectURI The redirectURI provided to ID.me when registering your app at @b http://developer.id.me
 */
+ (void)initializeWithClientID:(NSString * _Nonnull)clientID
                   redirectURI:(NSString * _Nonnull)redirectURI;

/**
 @param externalViewController The viewController which will present the modal navigationController
 @param scope The type of group verficiation that should be presented.
 @param webVerificationResults A block that returns an NSDictionary object and an NSError object. The verified user's profile is stored in an @c NSDictionary object as @c JSON data. If no data was returned, or an error occured, @c NSDictionary is @c nil and @c NSError returns an error code and localized description of the specific error that occured.
 */
- (void)verifyUserInViewController:(UIViewController * _Nonnull)externalViewController
                             scope:(NSString * _Nonnull)scope
                       withResults:(IDmeVerifyWebVerifyResults _Nonnull)webVerificationResults;

/**
 @param externalViewController The viewController which will present the modal navigationController
 @param scope The type of group verficiation that should be presented.
 @param webVerificationResults A block that returns an NSString object representing a valid access token or an NSError object.
 */

- (void)verifyUserInViewController:(UIViewController * _Nonnull)externalViewController
                             scope:(NSString * _Nonnull)scope
                   withTokenResult:(IDmeVerifyWebVerifyResults _Nonnull)webVerificationResults;

/**
 Returns the User profile with the stored access token. 
 @param webVerificationResults A block that returns an NSDictionary object and an NSError object. The verified user's profile is stored in an @c NSDictionary object as @c JSON data. If no data was returned, or an error occured, @c NSDictionary is @c nil and @c NSError returns an error code and localized description of the specific error that occured.
 */
- (void)getUserProfileWithResult:(IDmeVerifyWebVerifyResults _Nonnull)webVerificationResults;

/**
 Returns a valid access token. If the currently saved access token is valid it will be returned. If not, then it will be refreshed.
 @param scope The type of group verficiation that should be presented.
 @param forceRefreshing Force the SDK to refresh the token and do not use the current one.
 @param callback A block that returns an NSString object representing a valid access token or an NSError object.
 */
- (void)getAccessTokenWithScope:(NSString*)scope forceRefreshing:(BOOL)force result:(IDmeVerifyWebVerifyResults _Nonnull)callback;

/**
 Invalidates and deletes all tokens stored by the SDK.
 */
- (void)logout;

@end
