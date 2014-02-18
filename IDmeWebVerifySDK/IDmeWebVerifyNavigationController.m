//
//  IDmeWebVerifyNavigationController.m
//  ID.me WebVerify
//
//  Created by Arthur Sabintsev on 9/25/13.
//  Copyright (c) 2013 ID.me, Inc. All rights reserved.
//

#import "IDmeWebVerifyNavigationController.h"

@interface IDmeWebVerifyNavigationController ()

@end

@implementation IDmeWebVerifyNavigationController

#pragma mark - Orientation Methods
- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

@end
