//
//  PrivacyPolicyViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/10/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

#import "AppDelegate.h"
#import "PrivacyPolicyViewController.h"
#import "Model.h"

@interface PrivacyPolicyViewController () <UITextViewDelegate>

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIBarButtonItem *doneBarButton;

@end

@implementation PrivacyPolicyViewController

-(instancetype)init
{
    self = [super init];
    if(self)
    {
        self.title = NSLocalizedString(@"settings_privacy", @"Policy Privacy");
        
        self.textView = [UITextView new];
        self.textView.restorationIdentifier = @"thanks+licenses";
        self.textView.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Privacy policy attributed string
        NSMutableAttributedString *privacyAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
        NSMutableAttributedString *spacerAttributedString = [[NSMutableAttributedString alloc] initWithString:@"\n\n" attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        
        // Privcy policy string — Bundle string
        NSString *firstString = NSLocalizedStringFromTableInBundle(@"privacy_text", @"PrivacyPolicy", [NSBundle mainBundle], @"Privacy policy text");
        NSMutableAttributedString *firstAttributedString = [[NSMutableAttributedString alloc] initWithString:firstString attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:firstAttributedString];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        // Introduction — Bundle string
        NSString *introTitle = NSLocalizedStringFromTableInBundle(@"intro_title", @"PrivacyPolicy", [NSBundle mainBundle], @"Introduction title");
        NSMutableAttributedString *introAttributedTitle = [[NSMutableAttributedString alloc] initWithString:introTitle attributes:@{NSFontAttributeName:[UIFont piwigoFontBold]}];
        [privacyAttributedString appendAttributedString:introAttributedTitle];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        NSString *introString1 = NSLocalizedStringFromTableInBundle(@"intro_text1", @"PrivacyPolicy", [NSBundle mainBundle], @"Introduction text1");
        NSMutableAttributedString *introAttributedString1 = [[NSMutableAttributedString alloc] initWithString:introString1 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:introAttributedString1];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        NSString *introString2 = NSLocalizedStringFromTableInBundle(@"intro_text2", @"PrivacyPolicy", [NSBundle mainBundle], @"Introduction text2");
        NSMutableAttributedString *introAttributedString2 = [[NSMutableAttributedString alloc] initWithString:introString2 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:introAttributedString2];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        NSString *introString3 = NSLocalizedStringFromTableInBundle(@"intro_text3", @"PrivacyPolicy", [NSBundle mainBundle], @"Introduction text3");
        NSMutableAttributedString *introAttributedString3 = [[NSMutableAttributedString alloc] initWithString:introString3 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:introAttributedString3];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        NSString *introString4 = NSLocalizedStringFromTableInBundle(@"intro_text4", @"PrivacyPolicy", [NSBundle mainBundle], @"Introduction text4");
        NSMutableAttributedString *introAttributedString4 = [[NSMutableAttributedString alloc] initWithString:introString4 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:introAttributedString4];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        NSString *introString5 = NSLocalizedStringFromTableInBundle(@"intro_text5", @"PrivacyPolicy", [NSBundle mainBundle], @"Introduction text5");
        NSMutableAttributedString *introAttributedString5 = [[NSMutableAttributedString alloc] initWithString:introString5 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:introAttributedString5];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        // What data is processed and stored? — Bundle string
        NSString *whatTitle = NSLocalizedStringFromTableInBundle(@"what_title", @"PrivacyPolicy", [NSBundle mainBundle], @"What title");
        NSMutableAttributedString *whatAttributedTitle = [[NSMutableAttributedString alloc] initWithString:whatTitle attributes:@{NSFontAttributeName:[UIFont piwigoFontBold]}];
        [privacyAttributedString appendAttributedString:whatAttributedTitle];
        [privacyAttributedString appendAttributedString:spacerAttributedString];
        
        NSString *whatSubtitle1 = NSLocalizedStringFromTableInBundle(@"what_subTitle1", @"PrivacyPolicy", [NSBundle mainBundle], @"What sub-title1");
        NSMutableAttributedString *whatAttributedSubtitle1 = [[NSMutableAttributedString alloc] initWithString:whatSubtitle1 attributes:@{NSFontAttributeName:[UIFont piwigoFontLight]}];
        [privacyAttributedString appendAttributedString:whatAttributedSubtitle1];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        NSString *whatString1a = NSLocalizedStringFromTableInBundle(@"what_subText1a", @"PrivacyPolicy", [NSBundle mainBundle], @"what sub-text1a");
        NSMutableAttributedString *whatAttributedString1a = [[NSMutableAttributedString alloc] initWithString:whatString1a attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:whatAttributedString1a];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        NSString *whatSubtitle2 = NSLocalizedStringFromTableInBundle(@"what_subTitle2", @"PrivacyPolicy", [NSBundle mainBundle], @"What sub-title2");
        NSMutableAttributedString *whatAttributedSubtitle2 = [[NSMutableAttributedString alloc] initWithString:whatSubtitle2 attributes:@{NSFontAttributeName:[UIFont piwigoFontLight]}];
        [privacyAttributedString appendAttributedString:whatAttributedSubtitle2];
        [privacyAttributedString appendAttributedString:spacerAttributedString];
        
        NSString *whatString2a = NSLocalizedStringFromTableInBundle(@"what_subText2a", @"PrivacyPolicy", [NSBundle mainBundle], @"what sub-text2a");
        NSMutableAttributedString *whatAttributedString2a = [[NSMutableAttributedString alloc] initWithString:whatString2a attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:whatAttributedString2a];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        NSString *whatSubtitle3 = NSLocalizedStringFromTableInBundle(@"what_subTitle3", @"PrivacyPolicy", [NSBundle mainBundle], @"What sub-title3");
        NSMutableAttributedString *whatAttributedSubtitle3 = [[NSMutableAttributedString alloc] initWithString:whatSubtitle3 attributes:@{NSFontAttributeName:[UIFont piwigoFontLight]}];
        [privacyAttributedString appendAttributedString:whatAttributedSubtitle3];
        [privacyAttributedString appendAttributedString:spacerAttributedString];
        
        NSString *whatString3a = NSLocalizedStringFromTableInBundle(@"what_subText3a", @"PrivacyPolicy", [NSBundle mainBundle], @"what sub-text3a");
        NSMutableAttributedString *whatAttributedString3a = [[NSMutableAttributedString alloc] initWithString:whatString3a attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:whatAttributedString3a];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        NSString *whatSubtitle4 = NSLocalizedStringFromTableInBundle(@"what_subTitle4", @"PrivacyPolicy", [NSBundle mainBundle], @"What sub-title4");
        NSMutableAttributedString *whatAttributedSubtitle4 = [[NSMutableAttributedString alloc] initWithString:whatSubtitle4 attributes:@{NSFontAttributeName:[UIFont piwigoFontLight]}];
        [privacyAttributedString appendAttributedString:whatAttributedSubtitle4];
        [privacyAttributedString appendAttributedString:spacerAttributedString];
        
        NSString *whatString4a = NSLocalizedStringFromTableInBundle(@"what_subText4a", @"PrivacyPolicy", [NSBundle mainBundle], @"what sub-text4a");
        NSMutableAttributedString *whatAttributedString4a = [[NSMutableAttributedString alloc] initWithString:whatString4a attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:whatAttributedString4a];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        // Why does the mobile app store data? — Bundle string
        NSString *whyTitle = NSLocalizedStringFromTableInBundle(@"why_title", @"PrivacyPolicy", [NSBundle mainBundle], @"Why title");
        NSMutableAttributedString *whyAttributedTitle = [[NSMutableAttributedString alloc] initWithString:whyTitle attributes:@{NSFontAttributeName:[UIFont piwigoFontBold]}];
        [privacyAttributedString appendAttributedString:whyAttributedTitle];
        [privacyAttributedString appendAttributedString:spacerAttributedString];
        
        NSString *whyString1 = NSLocalizedStringFromTableInBundle(@"why_text1", @"PrivacyPolicy", [NSBundle mainBundle], @"Why text1");
        NSMutableAttributedString *whyAttributedString1 = [[NSMutableAttributedString alloc] initWithString:whyString1 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:whyAttributedString1];
        [privacyAttributedString appendAttributedString:spacerAttributedString];
    
        NSString *whyString2 = NSLocalizedStringFromTableInBundle(@"why_text2", @"PrivacyPolicy", [NSBundle mainBundle], @"Why text2");
        NSMutableAttributedString *whyAttributedString2 = [[NSMutableAttributedString alloc] initWithString:whyString2 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:whyAttributedString2];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        // How is the data protected? — Bundle string
        NSString *howTitle = NSLocalizedStringFromTableInBundle(@"how_title", @"PrivacyPolicy", [NSBundle mainBundle], @"How title");
        NSMutableAttributedString *howAttributedTitle = [[NSMutableAttributedString alloc] initWithString:howTitle attributes:@{NSFontAttributeName:[UIFont piwigoFontBold]}];
        [privacyAttributedString appendAttributedString:howAttributedTitle];
        [privacyAttributedString appendAttributedString:spacerAttributedString];
        
        NSString *howString1 = NSLocalizedStringFromTableInBundle(@"how_text1", @"PrivacyPolicy", [NSBundle mainBundle], @"How text1");
        NSMutableAttributedString *howAttributedString1 = [[NSMutableAttributedString alloc] initWithString:howString1 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:howAttributedString1];
        [privacyAttributedString appendAttributedString:spacerAttributedString];
        
        NSString *howString2 = NSLocalizedStringFromTableInBundle(@"how_text2", @"PrivacyPolicy", [NSBundle mainBundle], @"How text2");
        NSMutableAttributedString *howAttributedString2 = [[NSMutableAttributedString alloc] initWithString:howString2 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:howAttributedString2];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        // Security of your information — Bundle string
        NSString *securityTitle = NSLocalizedStringFromTableInBundle(@"security_title", @"PrivacyPolicy", [NSBundle mainBundle], @"Security title");
        NSMutableAttributedString *securityAttributedTitle = [[NSMutableAttributedString alloc] initWithString:securityTitle attributes:@{NSFontAttributeName:[UIFont piwigoFontBold]}];
        [privacyAttributedString appendAttributedString:securityAttributedTitle];
        [privacyAttributedString appendAttributedString:spacerAttributedString];
        
        NSString *securityString1 = NSLocalizedStringFromTableInBundle(@"security_text", @"PrivacyPolicy", [NSBundle mainBundle], @"Security text");
        NSMutableAttributedString *securityAttributedString1 = [[NSMutableAttributedString alloc] initWithString:securityString1 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:securityAttributedString1];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        // Contact Us — Bundle string
        NSString *contactTitle = NSLocalizedStringFromTableInBundle(@"contact_title", @"PrivacyPolicy", [NSBundle mainBundle], @"Contact title");
        NSMutableAttributedString *contactAttributedTitle = [[NSMutableAttributedString alloc] initWithString:contactTitle attributes:@{NSFontAttributeName:[UIFont piwigoFontBold]}];
        [privacyAttributedString appendAttributedString:contactAttributedTitle];
        [privacyAttributedString appendAttributedString:spacerAttributedString];
        
        NSString *contactString1 = NSLocalizedStringFromTableInBundle(@"contact_text", @"PrivacyPolicy", [NSBundle mainBundle], @"Contact text");
        NSMutableAttributedString *contactAttributedString1 = [[NSMutableAttributedString alloc] initWithString:contactString1 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:contactAttributedString1];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        NSString *contactString2 = NSLocalizedStringFromTableInBundle(@"contact_address", @"PrivacyPolicy", [NSBundle mainBundle], @"Contact address");
        NSMutableAttributedString *contactAttributedString2 = [[NSMutableAttributedString alloc] initWithString:contactString2 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall]}];
        [privacyAttributedString appendAttributedString:contactAttributedString2];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        NSString *contactString3 = NSLocalizedStringFromTableInBundle(@"contact_email", @"PrivacyPolicy", [NSBundle mainBundle], @"Contact email");
        NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
        NSString *subject = [[NSString stringWithFormat:@"%@ %@ (%@) — %@", NSLocalizedString(@"settings_appName", @"Piwigo Mobile"), appVersionString, appBuildString, NSLocalizedString(@"settings_privacy", @"Policy Privacy")] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
        NSString *mailTo = [NSString stringWithFormat:@"mailto:%@?subject=%@", contactString3, subject];
        NSMutableAttributedString *contactAttributedString3 = [[NSMutableAttributedString alloc] initWithString:contactString3 attributes:@{NSFontAttributeName:[UIFont piwigoFontSmall],
            NSLinkAttributeName:[NSURL URLWithString:mailTo]}];
        [privacyAttributedString appendAttributedString:contactAttributedString3];
        [privacyAttributedString appendAttributedString:spacerAttributedString];

        // Piwigo-Mobile URLs
        NSRange noRange = {NSNotFound, 0};
        NSURL *iOS_URL = [NSURL URLWithString:@"https://github.com/Piwigo/Piwigo-Mobile"];
        NSRange iOS_Range = [privacyAttributedString.string rangeOfString:@"Piwigo-Mobile"];
        while (!NSEqualRanges(iOS_Range, noRange)) {
            [privacyAttributedString addAttribute:NSLinkAttributeName value:iOS_URL range:iOS_Range];
            NSInteger nextCharPos = iOS_Range.location + iOS_Range.length;
            if (nextCharPos >= [privacyAttributedString.string length]) break;
            iOS_Range = [privacyAttributedString.string rangeOfString:@"Piwigo-Mobile" options:NSLiteralSearch range:NSMakeRange(nextCharPos, [privacyAttributedString.string length] - nextCharPos)];
        }
        
        // Piwigo-Android URLs
        NSURL *Android_URL = [NSURL URLWithString:@"https://github.com/Piwigo/Piwigo-Android"];
        NSRange Android_Range = [privacyAttributedString.string rangeOfString:@"Piwigo-Android"];
        while (!NSEqualRanges(Android_Range, noRange)) {
            [privacyAttributedString addAttribute:NSLinkAttributeName value:Android_URL range:Android_Range];
            NSInteger nextCharPos = Android_Range.location + Android_Range.length;
            if (nextCharPos >= [privacyAttributedString.string length]) break;
            Android_Range = [privacyAttributedString.string rangeOfString:@"Piwigo-Android" options:NSLiteralSearch range:NSMakeRange(nextCharPos, [privacyAttributedString.string length] - nextCharPos)];
        }
        
        self.textView.attributedText = privacyAttributedString;
        self.textView.editable = NO;
        self.textView.allowsEditingTextAttributes = NO;
        self.textView.selectable = YES;
        self.textView.scrollsToTop = YES;
        if (@available(iOS 11.0, *)) {
            self.textView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        } else {
            // Fallback on earlier versions
            self.automaticallyAdjustsScrollViewInsets = NO;
        }
        [self.view addSubview:self.textView];
        
        [self addConstraints];
        
        // Button for returning to albums/images
        self.doneBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(quitSettings)];
        [self.doneBarButton setAccessibilityIdentifier:@"Done"];
        
        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoPaletteChangedNotification object:nil];
    }
    return self;
}

#pragma mark - View Lifecycle

-(void)applyColorPalette
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];

    // Navigation bar
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.navigationBar.tintColor = [UIColor piwigoOrange];
    self.navigationController.navigationBar.barTintColor = [UIColor piwigoBackgroundColor];
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoBackgroundColor];

    // Text color depdending on background color
    self.textView.textColor = [UIColor piwigoTextColor];
    self.textView.backgroundColor = [UIColor piwigoBackgroundColor];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set colors, fonts, etc.
    [self applyColorPalette];

    // Set navigation buttons
    [self.navigationItem setRightBarButtonItems:@[self.doneBarButton] animated:YES];
}

-(void)quitSettings
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)addConstraints
{
    NSDictionary *views = @{
                            @"textView" : self.textView
                            };
    
    if (@available(iOS 11, *)) {
        [self.view addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"V:|-[textView]-|"
                                   options:kNilOptions metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[textView]-|"
                                   options:kNilOptions metrics:nil views:views]];
    } else {
        [self.view addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"V:|-64-[textView]-|"
                                   options:kNilOptions metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[textView]-15-|"
                                   options:kNilOptions metrics:nil views:views]];
    }
}

@end
