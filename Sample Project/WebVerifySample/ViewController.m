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
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self setupSubviews];
}

#pragma mark - View Creation
- (void)setupSubviews
{
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
    
    NSNumber *horizontalButtonPadding = @80;
    NSNumber *verticalButtonSeparator = @20;
    NSNumber *buttonHeight = @44;
    NSNumber *textViewHeight = @250;
    NSDictionary *metrics = NSDictionaryOfVariableBindings(horizontalButtonPadding, verticalButtonSeparator, buttonHeight, textViewHeight);
    NSDictionary *views = NSDictionaryOfVariableBindings(textView, button);
    
    
    // constraints
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-horizontalButtonPadding-[button]-horizontalButtonPadding-|"
                                                                      options:NSLayoutFormatAlignAllBaseline
                                                                      metrics:metrics
                                                                        views:views]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[textView]-|"
                                                                      options:NSLayoutFormatAlignAllBaseline
                                                                      metrics:metrics
                                                                        views:views]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-verticalButtonSeparator-[textView(textViewHeight)]-verticalButtonSeparator-[button(buttonHeight)]"
                                                                      options:0
                                                                      metrics:metrics
                                                                        views:views]];
}

#pragma mark - Actions
- (void)verifyAction:(id)sender
{
    // clear _textView
    [_textView setText:nil];
    
    // Show AlertView
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Verify Affiliation"
                                                        message:@"Which affiliation would you like to verify?"
                                                       delegate:self cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Military", @"Student", @"Teacher", @"First Responder", nil];
    [alertView setDelegate:self];
    [alertView setTag:1000];
    [alertView show];
}

- (void)resultsWithUserProfile:(NSDictionary *)userProfile andError:(NSError *)error
{
    if (error) { // Error
        NSLog(@"Verification Error %ld: %@", error.code, error.localizedDescription);
        _textView.text = [NSString stringWithFormat:@"Error code: %ld\n\n%@", error.code, error.localizedDescription];
    } else { // Verification was successful
        NSLog(@"\nVerification Results:\n %@", userProfile);
        _textView.text = [NSString stringWithFormat:@"%@", userProfile];
    }
}

#pragma mark - UIAlertViewDelegate Methods
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
    IDmeWebVerifyAffiliationType affiliationType = IDmeWebVerifyAffiliationTypeMilitary;
    switch (buttonIndex) {
        case 1: // Military
            affiliationType = IDmeWebVerifyAffiliationTypeMilitary;
            break;
            
        case 2: // Student
            affiliationType = IDmeWebVerifyAffiliationTypeStudent;
            break;
            
        case 3: // Student
            affiliationType = IDmeWebVerifyAffiliationTypeTeacher;
            break;
            
        case 4: // First Responder
            affiliationType = IDmeWebVerifyAffiliationTypeResponder;
            break;
       }
    
    if (buttonIndex > 0) {
        
        #warning The clientID and redirectURI in the method below should only be used in this sample project. Please obtain your own clientID at http://developer.id.me before shipping your project
        [[IDmeWebVerify sharedInstance] verifyUserInViewController:self
                                                      withClientID:@"3d12ae3c4c426ed1148bdd0ded57b7e3"
                                                       redirectURI:@"https://www.id.me"
                                                   affiliationType:affiliationType
                                                       withResults:^(NSDictionary *userProfile, NSError *error) {
                                                           [self resultsWithUserProfile:userProfile andError:error];
                                                       }];
    }
}


@end
