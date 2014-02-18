//
//  IDmeWebVerify.h
//  ID.me WebVerify
//
//  Created by Arthur Sabintsev on 9/24/13.
//  Copyright (c) 2013 ID.me, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define IDME_WEBVERIFY_VERIFICATION_WAS_CANCELED    @"The user exited the modal navigationController before being verified."
#define IDME_WEBVERIFY_ERROR_DOMAIN                 @"ID.me Web Verify Error Domain"

@interface IDmeWebVerify : NSObject

typedef void (^IDmeVerifyWebVerifyResults)(NSDictionary *userProfile, NSError *error);

/// This typedef differentiates the different type of affiliation types that can be verified
typedef NS_ENUM(NSUInteger, IDmeWebVerifyAffiliationType)
{
    /// @b Military Verification
    IDmeWebVerifyAffiliationTypeMilitary = 1,
    
    /// @b Student Verification
    IDmeWebVerifyAffiliationTypeStudent,
    
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

+ (instancetype)sharedInstance;
- (void)verifyUserInViewController:(UIViewController *)externalViewController
                      withClientID:(NSString *)clientID
                       redirectURI:(NSString *)redirectURI
                   affiliationType:(IDmeWebVerifyAffiliationType)affiliationType
                     inSandboxMode:(BOOL)sandboxMode
                       withResults:(IDmeVerifyWebVerifyResults)webVerificationResults;

@end
