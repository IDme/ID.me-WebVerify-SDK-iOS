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

@implementation ViewController

#pragma mark - View Lifecycle
- (void)viewDidLoad {

    NSString *clientID    = @"<you_client_id>";
    NSString *redirectURL = @"<your_url>";

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

    UIButton *tokenButton = [UIButton new];
    [tokenButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [tokenButton setTitle:@"Test token!" forState:UIControlStateNormal];
    [tokenButton setBackgroundColor:[UIColor lightGrayColor]];
    [tokenButton addTarget:self action:@selector(tokenTestAction:) forControlEvents:UIControlEventTouchUpInside];
    [tokenButton.layer setCornerRadius:5.0f];
    [self.view addSubview:tokenButton];

    // constraints
    NSNumber *horizontalButtonPadding = @80;
    NSNumber *verticalButtonSeparator = @20;
    NSNumber *buttonHeight = @44;
    NSNumber *textViewHeight = @250;
    NSDictionary *metrics = NSDictionaryOfVariableBindings(horizontalButtonPadding, verticalButtonSeparator, buttonHeight, textViewHeight);
    NSDictionary *views = NSDictionaryOfVariableBindings(textView, button, tokenButton);

    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-horizontalButtonPadding-[button]-horizontalButtonPadding-|"
                                                                      options:NSLayoutFormatAlignAllBaseline
                                                                      metrics:metrics
                                                                        views:views]];

    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-horizontalButtonPadding-[tokenButton]-horizontalButtonPadding-|"
                                                                      options:NSLayoutFormatAlignAllBaseline
                                                                      metrics:metrics
                                                                        views:views]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[textView]-|"
                                                                      options:NSLayoutFormatAlignAllBaseline
                                                                      metrics:metrics
                                                                        views:views]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-verticalButtonSeparator-[textView(textViewHeight)]-verticalButtonSeparator-[button(buttonHeight)]-verticalButtonSeparator-[tokenButton(buttonHeight)]"
                                                                      options:0
                                                                      metrics:metrics
                                                                        views:views]];
}

#pragma mark - Actions
- (void)verifyAction:(id)sender {

    // clear _textView
    [_textView setText:nil];

    NSString *scope       = @"<your_handle>";

    [[IDmeWebVerify sharedInstance] verifyUserInViewController:self
                                    scope:scope
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

- (void)tokenTestAction:(id)sender {
    [[IDmeWebVerify sharedInstance] getUserProfileWithScope: @"wallet" result:^(NSDictionary *userProfile, NSError *error) {
        [self resultsWithUserProfile:userProfile andError:error];
        _textView.text = [_textView.text stringByAppendingString:@"\nUpdated with saved token"];
    }];
    [[IDmeWebVerify sharedInstance] getAccessTokenWithScope:@"wallet" forceRefreshing:NO result:^(NSString * _Nullable accessToken, NSError * _Nullable error) {
        NSLog(@"token: %@", accessToken);
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
