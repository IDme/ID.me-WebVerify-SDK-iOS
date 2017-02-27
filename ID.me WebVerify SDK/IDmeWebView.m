//
//  IDWebView.m
//  WebVerifySample
//
//  Created by Miguel Revetria on 27/2/17.
//  Copyright © 2017 ID.me, Inc. All rights reserved.
//

#import "IDmeWebView.h"

#import "IDmeWebVerify.h"

@interface IDmeWebView()

@property (nonatomic, nonnull, readonly, strong) UIView *disconnectedView;
@property (nonatomic, nonnull, readonly, strong) UIView *loadingIndicatorView;

@end

@implementation IDmeWebView

@synthesize disconnectedView = _disconnectedView;
@synthesize loadingIndicatorView = _loadingIndicatorView;

- (UIView *)disconnectedView {
    if (_disconnectedView) {
        return _disconnectedView;
    }

    NSBundle *bundle = [NSBundle bundleForClass:IDmeWebView.class];
    UIImageView *disconnectedImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"IDmeWebVerify.bundle/disconnected.png"
                                                                                       inBundle:bundle
                                                                  compatibleWithTraitCollection:nil]];
    disconnectedImageView.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 25, 120)];
    titleLabel.font = [UIFont systemFontOfSize:20];
    titleLabel.numberOfLines = 0;
    titleLabel.text = [[IDmeWebVerify sharedInstance] errorPageTitle];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor colorWithRed:45.0f / 255.0f green:62.0f / 255.0f blue:81.0f / 255.0f alpha:1.0f];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *descriptionLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 25, 120)];
    descriptionLabel.numberOfLines = 0;
    descriptionLabel.text = [[IDmeWebVerify sharedInstance] errorPageDescription];
    descriptionLabel.textAlignment = NSTextAlignmentCenter;
    descriptionLabel.textColor = [UIColor colorWithRed:45.0f / 255.0f green:62.0f / 255.0f blue:81.0f / 255.0f alpha:1.0f];
    descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _disconnectedView = [[UIView alloc] initWithFrame:self.frame];
    _disconnectedView.backgroundColor = [UIColor whiteColor];
    _disconnectedView.translatesAutoresizingMaskIntoConstraints = NO;

    [_disconnectedView addSubview:disconnectedImageView];
    [_disconnectedView addSubview:titleLabel];
    [_disconnectedView addSubview:descriptionLabel];

    NSDictionary *views = @{
        @"image": disconnectedImageView,
        @"title": titleLabel,
        @"desc": descriptionLabel
    };

    [_disconnectedView addConstraint:[NSLayoutConstraint constraintWithItem:disconnectedImageView
                                                                  attribute:NSLayoutAttributeCenterX
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:_disconnectedView
                                                                  attribute:NSLayoutAttributeCenterX
                                                                 multiplier:1.0f
                                                                   constant:0.0f]];

    [_disconnectedView addConstraint:[NSLayoutConstraint constraintWithItem:disconnectedImageView
                                                                  attribute:NSLayoutAttributeCenterY
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:_disconnectedView
                                                                  attribute:NSLayoutAttributeCenterY
                                                                 multiplier:1.0f
                                                                   constant:-40.0f]];

    [_disconnectedView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[image]-15-[title]-15-[desc]" options:0 metrics:nil views:views]];
    [_disconnectedView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-15-[title]-15-|" options:0 metrics:nil views:views]];
    [_disconnectedView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-15-[desc]-15-|" options:0 metrics:nil views:views]];

    return _disconnectedView;
}

- (UIView *)loadingIndicatorView {
    if (_loadingIndicatorView) {
        return _loadingIndicatorView;
    }

    NSBundle *bundle = [NSBundle bundleForClass:IDmeWebView.class];
    bundle = [NSBundle bundleWithURL:[bundle URLForResource:@"IDmeWebVerify" withExtension:@"bundle"]];
    NSURL *spinnerUrl = [bundle URLForResource:@"spinner" withExtension:@"gif"];
    NSData *spinnerData = [NSData dataWithContentsOfURL:spinnerUrl];

    UIWebView *webView = [[UIWebView alloc] initWithFrame:self.frame];
    webView.backgroundColor = [UIColor redColor];
    webView.translatesAutoresizingMaskIntoConstraints = NO;
    webView.scalesPageToFit = YES;
    webView.contentMode = UIViewContentModeScaleAspectFit;

    [webView loadData:spinnerData MIMEType:@"image/gif" textEncodingName:@"UTF-8" baseURL:[NSURL new]];

    _loadingIndicatorView = [[UIView alloc] initWithFrame:self.frame];
    _loadingIndicatorView.backgroundColor = [UIColor whiteColor];
    _loadingIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;

    [_loadingIndicatorView addSubview:webView];

    [_loadingIndicatorView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[webView(64)]" options:0 metrics:nil views:@{ @"webView": webView }]];
    [_loadingIndicatorView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[webView(64)]" options:0 metrics:nil views:@{ @"webView": webView }]];
    [_loadingIndicatorView addConstraint:[NSLayoutConstraint constraintWithItem:webView
                                                                      attribute:NSLayoutAttributeCenterX
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:_loadingIndicatorView
                                                                      attribute:NSLayoutAttributeCenterX
                                                                     multiplier:1.0f
                                                                       constant:0.0f]];

    [_loadingIndicatorView addConstraint:[NSLayoutConstraint constraintWithItem:webView
                                                                      attribute:NSLayoutAttributeCenterY
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:_loadingIndicatorView
                                                                      attribute:NSLayoutAttributeCenterY
                                                                     multiplier:1.0f
                                                                       constant:0.0f]];

    return _loadingIndicatorView;
}

- (void)setErrorPageHidden:(Boolean)hidden animated:(BOOL)animated {
    [self setLoadingIndicatorHidden:YES];

    if (self.disconnectedView.hidden && hidden) {
        return;
    }

    __typeof__(self) __weak weakSelf = self;
    [UIView animateWithDuration:0.35 animations:^{
        weakSelf.disconnectedView.alpha = hidden ? 0.0f : 1.0f;
    } completion:^(BOOL finished) {
        if (finished) {
            weakSelf.disconnectedView.hidden = hidden;
        }
    }];
}

- (void)setLoadingIndicatorHidden:(Boolean)hidden {
    self.loadingIndicatorView.hidden = hidden;
}

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    self = [super initWithFrame:frame configuration:configuration];
    if (self) {
        [self initialize];
    }
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)initialize {
    self.disconnectedView.alpha = 0.0f;
    self.disconnectedView.hidden = YES;
    [self addSubview:self.disconnectedView];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:@{ @"view": self.disconnectedView }]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:@{ @"view": self.disconnectedView }]];

    self.loadingIndicatorView.hidden = YES;
    [self addSubview:self.loadingIndicatorView];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:@{ @"view": self.loadingIndicatorView }]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:@{ @"view": self.loadingIndicatorView }]];
}

@end
