//
//  LoginViewController_iPad.m
//  piwigo
//
//  Created by Olaf on 31.03.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "LoginViewController_iPad.h"
#import "Model.h"

@interface LoginViewController_iPad ()

@property (nonatomic, strong) NSArray* portraitConstraints;
@property (nonatomic, strong) NSArray* landscapeConstraints;

@end

@implementation LoginViewController_iPad

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated
{
    // Register for keyboard notifications
    [super viewWillAppear:YES];
    
    // Inform user if the connection is not secure
    self.websiteNotSecure.hidden = ![[Model sharedInstance].serverProtocol isEqualToString:@"https://"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)setupAutoLayout
{
    NSInteger side = 40;
    self.textFieldHeight = 64;
    NSInteger textFieldWidth = 500;
    
    NSDictionary *views = @{
                            @"logo" : self.piwigoLogo,
                            @"login" : self.loginButton,
                            @"server" : self.serverTextField,
                            @"user" : self.userTextField,
                            @"password" : self.passwordTextField,
                            @"notSecure" : self.websiteNotSecure,
                            @"by1" : self.byLabel1,
                            @"by2" : self.byLabel2,
                            @"usu" : self.versionLabel
                            };
    
    NSDictionary *metrics = @{
                              @"side" : @(side),
                              @"width" : @(textFieldWidth),
                              @"logoHeight" : @(self.textFieldHeight + 36),
                              @"height" : @(self.textFieldHeight)
                              };
    
    // ==> Portrait
    NSMutableArray *portrait = [NSMutableArray new];
    
    // Vertically
    [portrait addObject:[NSLayoutConstraint constraintViewFromTop:self.loginButton amount:(fmax([UIScreen mainScreen].bounds.size.height,[UIScreen mainScreen].bounds.size.width) / 2.0 + self.textFieldHeight + 2 * 10.0)]];

    [portrait addObjectsFromArray:[NSLayoutConstraint
          constraintsWithVisualFormat:@"V:|-(>=30,<=100)-[logo(height)]-(>=20)-[server(==logo)]-15-[user(==logo)]-15-[password(==logo)]-15-[login(==logo)]-15-[notSecure]-(>=30)-[by1][by2]-3-[usu]-20-|"
                               options:kNilOptions metrics:metrics views:views]];

    // Horizontally
    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.serverTextField]];
    [portrait addObjectsFromArray:[NSLayoutConstraint
          constraintsWithVisualFormat:@"H:|-(>=side)-[logo]-(>=side)-|"
                              options:kNilOptions metrics:metrics views:views]];

    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.userTextField]];
    [portrait addObjectsFromArray:[NSLayoutConstraint
          constraintsWithVisualFormat:@"H:|-(>=side)-[server(width)]-(>=side)-|"
                              options:kNilOptions metrics:metrics views:views]];

    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.userTextField]];
    [portrait addObjectsFromArray:[NSLayoutConstraint
          constraintsWithVisualFormat:@"H:|-(>=side)-[user(width)]-(>=side)-|"
                              options:kNilOptions metrics:metrics views:views]];

    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.passwordTextField]];
    [portrait addObjectsFromArray:[NSLayoutConstraint
          constraintsWithVisualFormat:@"H:|-(>=side)-[password(width)]-(>=side)-|"
                              options:kNilOptions metrics:metrics views:views]];

    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.loginButton]];
    [portrait addObjectsFromArray:[NSLayoutConstraint
          constraintsWithVisualFormat:@"H:|-(>=side)-[login(width)]-(>=side)-|"
                              options:kNilOptions metrics:metrics views:views]];

    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.websiteNotSecure]];
    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel1]];
    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel2]];
    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.versionLabel]];

    self.portraitConstraints = [NSArray arrayWithArray:portrait];

    
    // ==> Landscape
    NSMutableArray *landscape = [NSMutableArray new];

    // Vertically
    [landscape addObject:[NSLayoutConstraint constraintViewFromTop:self.loginButton amount:(fmin([UIScreen mainScreen].bounds.size.height,[UIScreen mainScreen].bounds.size.width) / 2.0 + self.textFieldHeight + 2 * 10.0)]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
                                    constraintsWithVisualFormat:@"V:[server(height)]-15-[user(height)]-15-[password(height)]-15-[login(height)]-15-[notSecure]"
                                    options:kNilOptions metrics:metrics views:views]];

    [landscape addObject:[NSLayoutConstraint constraintView:self.piwigoLogo toHeight:(self.textFieldHeight + 36.0)]];

    [landscape addObject:[NSLayoutConstraint constraintWithItem:self.byLabel1
                                                      attribute:NSLayoutAttributeTop
                                                      relatedBy:NSLayoutRelationEqual
                                                         toItem:self.loginButton
                                                      attribute:NSLayoutAttributeTop
                                                     multiplier:1.0
                                                       constant:0]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"V:[by1][by2]-3-[usu]"
                               options:kNilOptions metrics:metrics views:views]];

    // Horizontally
    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[logo]-side-[server(width)]-(>=side)-|"
                               options:NSLayoutFormatAlignAllTop metrics:metrics views:views]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[logo]-side-[user(==server)]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[logo]-side-[password(==server)]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[logo]-side-[login(==server)]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[logo]-side-[notSecure(==server)]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[by1]-side-[login]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];
    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[by2]-side-[login]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];
    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[usu]-side-[login]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];

    self.landscapeConstraints = [NSArray arrayWithArray:landscape];
}

-(void)updateViewConstraints {
    [self.view removeConstraints:self.portraitConstraints];
    [self.view removeConstraints:self.landscapeConstraints];
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
    {
        [self.view addConstraints:self.landscapeConstraints];
    }
    else {
        [self.view addConstraints:self.portraitConstraints];
    }
    [super updateViewConstraints];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    
    // Update constraints
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.view removeConstraints:self.portraitConstraints];
        [self.view removeConstraints:self.landscapeConstraints];
        if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        {
            [self.view addConstraints:self.landscapeConstraints];
        }
        else {
            [self.view addConstraints:self.portraitConstraints];
        }
    } completion:nil];

    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

@end
