# ID.me WebVerify SDK (iOS)
The ID.me WebVerify SDK for iOS is a library that allows you to verify a user's group affiliation status using ID.me's platform. A sample project has been provided to delineate the integration process.

## Release Information

- **SDK Version:** 4.0.1 (April 04, 2017)
- **Maintained By:** [ID.me](http://github.com/IDme)

For more information please email us at mobile@id.me or visit us at http://developer.id.me.

## Changelog
The changelog can be found in [CHANGELOG.md](CHANGELOG.md)

## Installation

### Using Cocoapods
Simply add this line to your Podfile:

```
pod 'IDmeWebVerify'
```

### Manual installation

* Download it from Github and drag the downloaded files to your Xcode project.
* If you are working with Swift you will have to import `IDmeWebVerify.h` in your ObjC Bridging Header.
* Import [SAMKeychain](https://github.com/soffes/SAMKeychain) as this SDK depends on it. You can also drag it to your project or use a dependency manager to import it.

## Setup

### Step 1
You must call `IDmeWebVerify.initialize(withClientID: String, clientSecret: String, redirectURI: String)` before using the SDK. You can do it in `application(didFinishLaunchingWithOptions:)` for example.

```swift
import IDmeWebVerify

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
      IDmeWebVerify.initialize(withClientID: "<client_id>", clientSecret: "<client_secret>", redirectURI: "<custom_scheme://callback>")
    }
}
```

You should get the parameters `<client_id>`, `<client_secret>`, `<custom_scheme://callback>` at http://developer.id.me.

### Step 2
You must handle the redirect calls from the SDK. For this you have to register your `redirectURI's` URL scheme for your app. Go to *Project Navigator* -> *Select your target* -> *Info* -> *URL Types* -> *New* and add your redirectURI's scheme in *URL Schemes*.
Example: if your redirectURI is `my_custom_scheme://callback`, enter `my_custom_scheme` in *URL Schemes*.

### Step 3
In your `AppDelegate` you must handle the redirectURL when it gets called. You do this by defining the corresponding delegate functions and then calling `IDmeWebVerifySDK` to handle the URL.

If your app supports iOS 9 and above add: 

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
    let handled = IDmeWebVerify.sharedInstance().application(app, open: url, options: options)

    if !handled {
        // do something else
    }
    return handled
}
```

If your app supports a lower iOS version than 9.0 then you must also add these methods:
```swift
func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
    let handled = IDmeWebVerify.sharedInstance().application(application, open: url, sourceApplication: sourceApplication, annotation: annotation)

    if !handled {
        // do something else
    }
    return handled
}

func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
    let handled = IDmeWebVerify.sharedInstance().application(app, open: url, options: [:])

    if !handled {
        // do something else
    }
    return handled
}
```

## Migrating from 3.2 to 4.0

There were several changes introduced in version 4.0.
These are some of the major changes you need to take into account when migrating:
* You must now call `IDmeWebVerify.initialize` before using the SDK.
* `verifyUserInViewController:withClientID:redirectURI:scope:withResults` has been removed. You should now call `verifyUser(in: UIViewController, scope: String, withTokenResult: IDmeVerifyWebVerifyTokenResults)` and then `getUserProfile(withScope: String?, result: IDmeVerifyWebVerifyProfileResults)` in the result callback.
* The SDK handles the access and refresh tokens by storing them in the Keychain. As the access tokens are short-lived it can happen quite frequently that the stored access token has expired and needs to be refreshed. That is why you have to call `IDmeWebVerify.sharedInstance().getAccessToken(withScope: String, forceRefreshing: Bool, results: IDmeVerifyWebVerifyTokenResults)` which includes a callback with the token (refreshed if it had expired) or an error. You should call this method before each of your requests to the ID.me backend.
The most common errors are that the token could not be refreshed and that there is no access token stored for the specified `scope` (happens before login).
* There are also some new functions you can see in `IDmeWebVerify.h`

## Examples
To see a working example you can:
- Download this repository
- Open `WebVerifySample.xcodeproj`
- Set your `clientID`, `clientSecret`, `redirectURI` and `scope` in `ViewController.m`
- Replace `your_custom_scheme` with your `redirectURI` in `WebVerifySample-Info.plist` -> `URL Types` (or through *Project Navigator*)

## Execution
Verification occurs through a SFSafariViewController to comply with the [best practices for OAuth in iOS](https://tools.ietf.org/html/draft-ietf-oauth-native-apps-03).
This means the SDK will open Safari for the user to log in. 
You must call `verifyUser(in: UIViewController, scope: String, withTokenResult: IDmeVerifyWebVerifyTokenResults)` to launch a SFSafariViewController for the user to authenticate. Take care not to call this method while another instance of that verification process is still under way as it will throw an exception.

<!--
Verification occurs through a modal view controller. The modal view controller is a navigation controller initialized with a web-view. The entire OAuth flow occurs through the web-view. Upon successful completion, the modal will automatically be dismissed, and a JSON object in the form of an NSDictionary object containing your user's verificaiton information will be returned to you.

To launch the modal, the following method can be called in the view controller class that will be presenting the modal:

```
- (void)verifyUserInViewController:(UIViewController *)externalViewController
                      withClientID:(NSString *)clientID
                       redirectURI:(NSString *)redirectURI
                             scope:(NSString *)scope
                       withResults:(IDmeVerifyWebVerifyResults)webVerificationResults;
```

The params in that method are as follows:

- `externalViewController`: The viewController which will present the modal navigationController.
- `clientID`: The clientID provided by ID.me when registering the app at [http://developer.id.me](http://developer.id.me).
- `redirectURI`: The redirectURI provided to ID.me when registering your app at [http://developer.id.me](http://developer.id.me)
- `scope`: The handle of your policy ('military', 'student', 'custom_student, etc') as defined for your app at [http://developer.id.me](http://developer.id.me)
- `webVerificationResults`: A block that returns an NSDictionary object and an NSError object. The verified user's profile is stored in an NSDictionary object as JSON data. If no data was returned, or an error occured, NSDictionary is nil and NSError returns an error code and localized description of the specific error that occured.

In your code, the implementation of this method should yield an expanded form of the `webVerificationResults` block. It is our recommendation that the full implementation of this method look as follows:

```
[[IDmeWebVerify sharedInstance] verifyUserInViewController:<your_presenting_view_controller>
                                              withClientID:<your_clientID>
                                               redirectURI:<your_redirectURI>
                                                      code:<your_scope>
                                               withResults:^(NSDictionary *userProfile, NSError *error, NSString *token) {

   											 	if (error) {
                                                  // Error
    											} else {
    											  // Verification was successful and value will exist for userProfile
    											}

                                            }];

```

Alternatively, in your code, you can request just the access token using

```
- (void)verifyUserInViewController:(UIViewController *)externalViewController
                      withClientID:(NSString *)clientID
                       redirectURI:(NSString *)redirectURI
                             scope:(NSString *)scope
                   withTokenResult:(IDmeVerifyWebVerifyResults)webVerificationResults;
```



```
[[IDmeWebVerify sharedInstance] verifyUserInViewController:<your_presenting_view_controller>
                                              withClientID:<your_clientID>
                                               redirectURI:<your_redirectURI>
                                                      code:<your_scope>
                                           withTokenResult:^(NSDictionary *userProfile, NSError *error, NSString *token) {

   											 	if (error) {
                                                  // Error
    											} else {
    											  // Verification was successful and value will exist for token
    											}

                                            }];

```

## Results
Each successful request for user profile returns the following information:

- Group Affiliation (Military Veteran, Student, Firefighter, etc.)
- Unique user Identifier
- Verification Status

**NOTE:** Other attributes (e.g., email, first name, last name, etc…) can be returned in the JSON results upon special request. Please email [mobile@id.me](mobile@id.me) if your app needs to gain access to more attributes. 

Successful calls for the access token will return a valid token string.

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

-->

## Internet Connectivity
Internet connectivity is required, as the verificaiton occurs through a webView.
