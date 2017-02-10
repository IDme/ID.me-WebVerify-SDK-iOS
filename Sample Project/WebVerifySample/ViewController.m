//
//  ViewController.m
//  WebVerifySample
//
//  Created by Arthur Sabintsev on 2/18/14.
//  Copyright (c) 2014 ID.me, Inc. All rights reserved.
//

#import "ViewController.h"
#import "IDmeWebVerify.h"

@interface ViewController ()
@property (nonatomic, strong) UITextView *textView;
@end

@implementation ViewController {
    NSString *clientID;
    NSString *redirectURL;
    NSString *scope;
}

#pragma mark - View Lifecycle
- (void)viewDidLoad {

    clientID    = @"<your_client_id>";
    redirectURL = @"<your_url>";
    scope = @"<your_handle>";

    [super viewDidLoad];
    [IDmeWebVerify initializeWithClientID:clientID redirectURI:redirectURL];
    [self setupSubviews];
}

#pragma mark - View Creation
- (void)setupSubviews {

    // view
    self.view.backgroundColor = [UIColor whiteColor];

    // textView
    UITextView *textView = [UITextView new];
    _textView = textView;
    [textView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [textView setFont:[UIFont systemFontOfSize:15.0f]];
    [textView setEditable:NO];
    [self.view addSubview:textView];

    // button
    UIButton *button = [UIButton new];
    [button setTranslatesAutoresizingMaskIntoConstraints:NO];
    [button setTitle:@"Verify Me!" forState:UIControlStateNormal];
    [button setBackgroundColor:[UIColor lightGrayColor]];
    [button addTarget:self action:@selector(verifyAction:) forControlEvents:UIControlEventTouchUpInside];
    [button.layer setCornerRadius:5.0f];
    [self.view addSubview:button];

    UIButton *loginButton = [UIButton new];
    [loginButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [loginButton setTitle:@"Add connection" forState:UIControlStateNormal];
    [loginButton setBackgroundColor:[UIColor lightGrayColor]];
    [loginButton addTarget:self action:@selector(addConnection:) forControlEvents:UIControlEventTouchUpInside];
    [loginButton.layer setCornerRadius:5.0f];
    [self.view addSubview:loginButton];

    UIButton *idButton = [UIButton new];
    [idButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [idButton setTitle:@"Add ID" forState:UIControlStateNormal];
    [idButton setBackgroundColor:[UIColor lightGrayColor]];
    [idButton addTarget:self action:@selector(addAffiliation:) forControlEvents:UIControlEventTouchUpInside];
    [idButton.layer setCornerRadius:5.0f];
    [self.view addSubview:idButton];

    // constraints
    NSNumber *horizontalButtonPadding = @80;
    NSNumber *verticalButtonSeparator = @10;
    NSNumber *buttonHeight = @40;
    NSNumber *textViewHeight = @250;
    NSDictionary *metrics = NSDictionaryOfVariableBindings(horizontalButtonPadding, verticalButtonSeparator, buttonHeight, textViewHeight);
    NSDictionary *views = NSDictionaryOfVariableBindings(textView, button, loginButton, idButton);

    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-horizontalButtonPadding-[button]-horizontalButtonPadding-|"
                                                                      options:NSLayoutFormatAlignAllBaseline
                                                                      metrics:metrics
                                                                        views:views]];

    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-horizontalButtonPadding-[loginButton]-horizontalButtonPadding-|"
                                                                      options:NSLayoutFormatAlignAllBaseline
                                                                      metrics:metrics
                                                                        views:views]];

    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-horizontalButtonPadding-[idButton]-horizontalButtonPadding-|"
                                                                      options:NSLayoutFormatAlignAllBaseline
                                                                      metrics:metrics
                                                                        views:views]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[textView]-|"
                                                                      options:NSLayoutFormatAlignAllBaseline
                                                                      metrics:metrics
                                                                        views:views]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-verticalButtonSeparator-[textView(textViewHeight)]-verticalButtonSeparator-[button(buttonHeight)]-verticalButtonSeparator-[loginButton(buttonHeight)]-verticalButtonSeparator-[idButton(buttonHeight)]"
                                                                      options:0
                                                                      metrics:metrics
                                                                        views:views]];
}

#pragma mark - Actions
- (void)verifyAction:(id)sender {

    // clear _textView
    [_textView setText:nil];

    [[IDmeWebVerify sharedInstance] verifyUserInViewController:self
                                                         scope:scope
                                                    withCancel:YES
                                                   withResults:^(NSDictionary *userProfile, NSError *error) {
                                                       [self resultsWithUserProfile:userProfile andError:error];
                                                   }];
/*
 OR
    [[IDmeWebVerify sharedInstance] verifyUserInViewController:self
                                                  withClientID:clientID
                                                   redirectURI:redirectURL
                                                         scope:scope
                                                   withTokenResult:^(NSDictionary *userProfile, NSError *error, NSString *accessToken) {
 if (error) { // Error
 NSLog(@"Verification Error %ld: %@", error.code, error.localizedDescription);
 _textView.text = [NSString stringWithFormat:@"Error code: %ld\n\n%@", error.code, error.localizedDescription];
 } else { // Verification was successful
 NSLog(@"\nVerification Token:\n %@", accessToken);
 _textView.text = [NSString stringWithFormat:@"%@", accessToken];
 }
                                                   }];
 */

}


- (void)addConnection:(id)sender {
    [[IDmeWebVerify sharedInstance] registerConnectionInViewController:self scope:scope type:IDWebVerifyConnectionGooglePlus result:^(NSError * _Nullable error) {
        if (error) { // Error
            NSLog(@"Verification Error %ld: %@", error.code, error.localizedDescription);
            _textView.text = [NSString stringWithFormat:@"Error code: %ld\n\n%@", error.code, error.localizedDescription];
        } else { // Verification was successful
            _textView.text = @"Successfully added Google connection";
        }
    }];
}

- (void)addAffiliation:(id)sender {
    [[IDmeWebVerify sharedInstance] registerAffiliationInViewController:self scope:scope type:IDmeWebVerifyAffiliationMilitary result:^(NSError * _Nullable error) {
        if (error) { // Error
            NSLog(@"Verification Error %ld: %@", error.code, error.localizedDescription);
            _textView.text = [NSString stringWithFormat:@"Error code: %ld\n\n%@", error.code, error.localizedDescription];
        } else { // Verification was successful
            _textView.text = @"Successfully added Troop ID";
        }
    }];
}

- (void)resultsWithUserProfile:(NSDictionary *)userProfile andError:(NSError *)error {
    
    if (error) { // Error
        NSLog(@"Verification Error %ld: %@", error.code, error.localizedDescription);
        _textView.text = [NSString stringWithFormat:@"Error code: %ld\n\n%@", error.code, error.localizedDescription];
    } else { // Verification was successful
        NSLog(@"\nVerification Results:\n %@", userProfile);
        _textView.text = [NSString stringWithFormat:@"%@", userProfile];
    }
}

@end
