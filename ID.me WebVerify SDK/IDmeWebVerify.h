//
//  IDmeWebVerify.h
//  ID.me WebVerify
//
//  Created by Arthur Sabintsev on 9/24/13.
//  Copyright (c) 2013 ID.me, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define IDME_WEB_VERIFY_VERIFICATION_WAS_CANCELED    @"The user exited the modal navigationController before being verified."
#define IDME_WEB_VERIFY_ERROR_DOMAIN                 @"ID.me Web Verify Error Domain"

@interface IDmeWebVerify : NSObject

typedef void (^IDmeVerifyWebVerifyResults)(NSDictionary *userProfile, NSError *error);

/// This typedef differentiates the different type of affiliation types that can be verified
typedef NS_ENUM(NSUInteger, IDmeWebVerifyAffiliationType)
{
    /// @b Military Verification
    IDmeWebVerifyAffiliationTypeMilitary = 1,
    
    /// @b Student Verification
    IDmeWebVerifyAffiliationTypeStudent,
    
    /// @b Teacher Verification
    IDmeWebVerifyAffiliationTypeTeacher,
    
    /// @b First Respoder Verification
    IDmeWebVerifyAffiliationTypeResponder
};

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
+ (IDmeWebVerify *)sharedInstance;

/**
 @param externalViewController The viewController which will present the modal navigationController
 @param clientID The clientID provided by ID.me when registering the app at @b http://developer.id.me
 @param redierectURI The redirectURI provided to ID.me when registering your app at @b http://developer.id.me
 @param affiliationType The type of group verficiation that should be presented. Check the @c IDmeVerifyAffiliationType typedef for more details
 @param webVerificationResults A block that returns an NSDictionary object and an NSError object. The verified user's profile is stored in an @c NSDictionary object as @c JSON data. If no data was returned, or an error occured, @c NSDictionary is @c nil and @c NSError returns an error code and localized description of the specific error that occured.
 */
- (void)verifyUserInViewController:(UIViewController *)externalViewController
                      withClientID:(NSString *)clientID
                       redirectURI:(NSString *)redirectURI
                   affiliationType:(IDmeWebVerifyAffiliationType)affiliationType
                       withResults:(IDmeVerifyWebVerifyResults)webVerificationResults;

@end
