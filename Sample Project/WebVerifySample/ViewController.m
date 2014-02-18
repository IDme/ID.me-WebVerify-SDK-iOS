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

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // textView
    UITextView *textView = [UITextView new];
    self.textView = textView;
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
    
    // constraints
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-80-[button]-80-|"
                                                                      options:NSLayoutFormatAlignAllBaseline
                                                                      metrics:nil
                                                                        views:NSDictionaryOfVariableBindings(button)]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[textView]-|"
                                                                      options:NSLayoutFormatAlignAllBaseline
                                                                      metrics:nil
                                                                        views:NSDictionaryOfVariableBindings(textView)]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-20-[textView(250)]-20-[button(44)]"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:NSDictionaryOfVariableBindings(textView, button)]];
}

- (void)verifyAction:(id)sender
{
    // clear _textView
    [self.textView setText:nil];
    
    // Show AlertView
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Verify Affiliation"
                                                        message:@"Which affiliation would you like to verify?"
                                                       delegate:self cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Military", @"Student", @"First Responder", nil];
    [alertView setDelegate:self];
    [alertView setTag:1000];
    [alertView show];
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
            
        case 3: // First Responder
            affiliationType = IDmeWebVerifyAffiliationTypeResponder;
            break;
       }
    
    if (buttonIndex > 0) {
        
        #warning The clientID and redirectURI should only be used in this sample project. Please obtain your own clientID and redirectURI from http://developer.sandbox.id.me
        [[IDmeWebVerify sharedInstance] verifyUserInViewController:self
                                                      withClientID:@"be4da8f971329f362"
                                                       redirectURI:@"https://developer.sandbox.id.me"
                                                   affiliationType:affiliationType
                                                     inSandboxMode:YES
                                                       withResults:^(NSDictionary *userProfile, NSError *error) {
                                                           if (error) { // Error
                                                               NSLog(@"Verification Error %d: %@", error.code, error.localizedDescription);
                                                               self.textView.text = [NSString stringWithFormat:@"Error code: %d\n\n%@", error.code, error.localizedDescription];
                                                           } else { // Verification was successful
                                                               NSLog(@"\nVerification Results:\n %@", userProfile);
                                                               self.textView.text = [NSString stringWithFormat:@"%@", userProfile];
                                                           }
                                                       }];
    }
}


@end
