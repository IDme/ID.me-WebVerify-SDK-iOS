# ID.me WebVerify SDK (iOS)
The ID.me WebVerify SDK for iOS is a library that allows you to verify a user's group affiliation status using ID.me's platform. A sample project has been provided to delineate the integration process.

## Release Information

- **SDK Version:** 3.0.0 (October 22, 2014)
- **Maintained By:** [Arthur Sabintsev](http://github.com/ArtSabintsev)

For more information please email us at mobile@id.me or visit us at http://developer.id.me.

## Changelog
- Works with ID.me's new API
- Added support for teachers


## Download

Get it using CocoaPods

```
pod 'IDmeWebVerify'
```

or download it on Github.

## Setup
1. Drag the **ID.me WebVerify SDK** folder into your project. This will add the following files:
	- `IDmeWebVerify.h`
	- `IDmeWebVerifyNavigationController.h`
2. Import `IDmeWebVerify.h` into one of your projects, preferably an instance or subclassed instance of `UIViewController`.

## Execution
Verification occurs through a modal view controller. The modal view controller is a navigation controller initialized with a web-view. The entire OAuth flow occurs through the web-view. Upon successful completion, the modal will automatically be dismissed, and a JSON object in the form of an NSDictionary object containing your user's verificaiton information will be returned to you.

To launch the modal, the following method must be called in the view controller class that will be presenting the modal:

```
- (void)verifyUserInViewController:(UIViewController *)externalViewController
                      withClientID:(NSString *)clientID
                       redirectURI:(NSString *)redirectURI
                   affiliationType:(IDmeWebVerifyAffiliationType)affiliationType
                       withResults:(IDmeVerifyWebVerifyResults)webVerificationResults;
```

The params in that method are as follows:

- `externalViewController`: The viewController which will present the modal navigationController.
- `clientID`: The clientID provided by ID.me when registering the app at [http://developer.id.me](http://developer.id.me).
- `redirectURI`: The redirectURI provided to ID.me when registering your app at [http://developer.id.me](http://developer.id.me)
- `affiliationType`: The type of group verficiation that should be presented. Check the `IDmeVerifyAffiliationType` typedef for more details.
- `webVerificationResults`: A block that returns an NSDictionary object and an NSError object. The verified user's profile is stored in an NSDictionary object as JSON data. If no data was returned, or an error occured, NSDictionary is nil and NSError returns an error code and localized description of the specific error that occured.

In your code, the implementation of this method should yield an expanded form of the `webVerificationResults` block. It is our recommendation that the full implementation of this method look as follows:

```
[[IDmeWebVerify sharedInstance] verifyUserInViewController:<your_presenting_view_controller>
                                              withClientID:<your_clientID>
                                               redirectURI:<your_redirectURI>
                                           affiliationType:<your_affiliationType>
                                               withResults:^(NSDictionary *userProfile, NSError *error) {
                                                
   											 	if (error) { // Error
        
        
    											} else { // Verification was successful
    											
    											}
    											
                                            }];

```

## Results
Each successful request returns the following information:

- Group Affiliation (Military Veteran, Student, Firefighter, etc.)
- Unique user Identifier
- Verification Status

**NOTE:** Other attributes (e.g., email, first name, last name, etc…) can be returned in the JSON results upon special request. Please email [mobile@id.me](mobile@id.me) if your app needs to gain access to more attributes. 

All potential errors that could occur are explained in the next section.

## Error Handling
There are four potential outcomes during the group affiliation verification process, three of which are errors. All of the errors are returned in the `IDmeWebVerifyVerificationResults` block, which is the last parameter in verification method described above. Each error will return a non-nil NSError object, and a nil NSDictionary object. The three verification related errors can be found in the `IDmeWebVerifyErrorCode` typedef, which deals with all errors in the SDK. The three verification related errors are as follows:

- `IDmeWebVerifyErrorCodeVerificationDidFailToFetchUserProfile`
	- Error occurs if user succesfully verified their group affiliation, but there was a problem with the user's profile being returned.
	- This should never occur, but this error was added to handle a rare situation involving the inability to reach ID.me's server. 
- `IDmeWebVerifyErrorCodeVerificationWasDeniedByUser`
	-  Error occurs if user succesfully verified their group affiliation, but decided to deny access to your app at the end of the OAuth flow.
- `IDmeWebVerifyErrorCodeVerificationWasCanceledByUser` 
	- Error occurs if user exits modal navigation controller before OAuth flow could complete.

The following properties of the NSError object should be referenced by your app if you're looking to employ error-specific methods:

- `code`: The error code of the specific issue. The value is defined in the `IDmeWebVerifyErrorCode` typedef, and should be in the 100s.
-  `localizedDescription`: A detailed description of the error.

## Internet Connectivity
Internet connectivity is required, as the verificaiton occurs through a webView.
