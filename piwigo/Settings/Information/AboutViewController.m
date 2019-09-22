//
//  AboutViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/19/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "AboutViewController.h"
#import "Model.h"

@interface AboutViewController () <UITextViewDelegate>

@property (nonatomic, strong) UILabel *piwigoTitle;
@property (nonatomic, strong) UILabel *byLabel1;
@property (nonatomic, strong) UILabel *byLabel2;
@property (nonatomic, strong) UILabel *versionLabel;

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIBarButtonItem *doneBarButton;

@end

@implementation AboutViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.title = NSLocalizedString(@"settings_acknowledgements", @"Acknowledgements");
		
		self.piwigoTitle = [UILabel new];
		self.piwigoTitle.translatesAutoresizingMaskIntoConstraints = NO;
		self.piwigoTitle.font = [UIFont piwigoFontLarge];
		self.piwigoTitle.textColor = [UIColor piwigoOrange];
		self.piwigoTitle.text = NSLocalizedString(@"settings_appName", @"Piwigo Mobile");
		[self.view addSubview:self.piwigoTitle];
		
		self.byLabel1 = [UILabel new];
		self.byLabel1.translatesAutoresizingMaskIntoConstraints = NO;
		self.byLabel1.font = [UIFont piwigoFontSmall];
		self.byLabel1.text = NSLocalizedStringFromTableInBundle(@"authors1", @"About", [NSBundle mainBundle], @"By Spencer Baker, Olaf Greck,");
		[self.view addSubview:self.byLabel1];
		
        self.byLabel2 = [UILabel new];
        self.byLabel2.translatesAutoresizingMaskIntoConstraints = NO;
        self.byLabel2.font = [UIFont piwigoFontSmall];
        self.byLabel2.text = NSLocalizedStringFromTableInBundle(@"authors2", @"About", [NSBundle mainBundle], @"and Eddy Lelièvre-Berna");
        [self.view addSubview:self.byLabel2];

        self.versionLabel = [UILabel new];
		self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.versionLabel.font = [UIFont piwigoFontTiny];
		NSString * appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		NSString * appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
        self.versionLabel.text = [NSString stringWithFormat:@"— %@ %@ (%@) —", NSLocalizedStringFromTableInBundle(@"version", @"About", [NSBundle mainBundle], @"Version:"), appVersionString, appBuildString];
        [self.view addSubview:self.versionLabel];

		self.textView = [UITextView new];
        self.textView.restorationIdentifier = @"thanks+licenses";
		self.textView.translatesAutoresizingMaskIntoConstraints = NO;
		
        // Release notes attributed string
        NSMutableAttributedString *aboutAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
        NSMutableAttributedString *spacerAttributedString = [[NSMutableAttributedString alloc] initWithString:@"\n\n\n"];
        NSRange spacerRange = NSMakeRange(0, [spacerAttributedString length]);
        [spacerAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:spacerRange];

        // Translators — Bundle string
        NSString *translatorsString = NSLocalizedStringFromTableInBundle(@"translators_text", @"About", [NSBundle mainBundle], @"Translators text");
        NSMutableAttributedString *translatorsAttributedString = [[NSMutableAttributedString alloc] initWithString:translatorsString];
        NSRange translatorsRange = NSMakeRange(0, [translatorsString length]);
        [translatorsAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:translatorsRange];
        [aboutAttributedString appendAttributedString:translatorsAttributedString];
        [aboutAttributedString appendAttributedString:spacerAttributedString];

        // Introduction string — Bundle string
        NSString *introString = NSLocalizedStringFromTableInBundle(@"about_text", @"About", [NSBundle mainBundle], @"Introduction text");
        NSMutableAttributedString *introAttributedString = [[NSMutableAttributedString alloc] initWithString:introString];
        NSRange introRange = NSMakeRange(0, [introString length]);
        [introAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:introRange];
        [aboutAttributedString appendAttributedString:introAttributedString];

        // AFNetworking Licence — Bundle string
        NSString *afnString = NSLocalizedStringFromTableInBundle(@"licenceAFN_text", @"About", [NSBundle mainBundle], @"AFNetworking licence text");
        NSMutableAttributedString *afnAttributedString = [[NSMutableAttributedString alloc] initWithString:afnString];
        NSRange afnTitleRange = NSMakeRange(0, [afnString length]);
        [afnAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:afnTitleRange];
        afnTitleRange = NSMakeRange(0, [afnString rangeOfString:@"\n"].location);
        [afnAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:afnTitleRange];
        [aboutAttributedString appendAttributedString:afnAttributedString];
        [aboutAttributedString appendAttributedString:spacerAttributedString];

        // IQKeyboardManager Licence — Bundle string
        NSString *iqkmString = NSLocalizedStringFromTableInBundle(@"licenceIQkeyboard_text", @"About", [NSBundle mainBundle], @"IQKeyboardManager licence text");
        NSMutableAttributedString *iqkmAttributedString = [[NSMutableAttributedString alloc] initWithString:iqkmString];
        NSRange iqkmTitleRange = NSMakeRange(0, [iqkmString length]);
        [iqkmAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:iqkmTitleRange];
        iqkmTitleRange = NSMakeRange(0, [iqkmString rangeOfString:@"\n"].location);
        [iqkmAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:iqkmTitleRange];
        [aboutAttributedString appendAttributedString:iqkmAttributedString];
        [aboutAttributedString appendAttributedString:spacerAttributedString];

        // MBProgressHUD Licence — Bundle string
        NSString *mbpHudString = NSLocalizedStringFromTableInBundle(@"licenceMBProgHUD_text", @"About", [NSBundle mainBundle], @"MBProgressHUD licence text");
        NSMutableAttributedString *mbpHudAttributedString = [[NSMutableAttributedString alloc] initWithString:mbpHudString];
        NSRange mbpHudRange = NSMakeRange(0, [mbpHudString length]);
        [mbpHudAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:mbpHudRange];
        mbpHudRange = NSMakeRange(0, [mbpHudString rangeOfString:@"\n"].location);
        [mbpHudAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:mbpHudRange];
        [aboutAttributedString appendAttributedString:mbpHudAttributedString];
        [aboutAttributedString appendAttributedString:spacerAttributedString];

        // MGSwipeTableCell Licence — Bundle string
        NSString *mgstcString = NSLocalizedStringFromTableInBundle(@"licenceMGSTC_text", @"About", [NSBundle mainBundle], @"MGSwipeTableCell licence text");
        NSMutableAttributedString *mgstcAttributedString = [[NSMutableAttributedString alloc] initWithString:mgstcString];
        NSRange mgstcRange = NSMakeRange(0, [mgstcString length]);
        [mgstcAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:mgstcRange];
        mgstcRange = NSMakeRange(0, [mgstcString rangeOfString:@"\n"].location);
        [mgstcAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:mgstcRange];
        [aboutAttributedString appendAttributedString:mgstcAttributedString];
        [aboutAttributedString appendAttributedString:spacerAttributedString];

        // SAMKeychain Licence — Bundle string
        NSString *samString = NSLocalizedStringFromTableInBundle(@"licenceSAM_text", @"About", [NSBundle mainBundle], @"SAMKeychain licence text");
        NSMutableAttributedString *samAttributedString = [[NSMutableAttributedString alloc] initWithString:samString];
        NSRange samRange = NSMakeRange(0, [samString length]);
        [samAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:samRange];
        samRange = NSMakeRange(0, [samString rangeOfString:@"\n"].location);
        [samAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:samRange];
        [aboutAttributedString appendAttributedString:samAttributedString];
        [aboutAttributedString appendAttributedString:spacerAttributedString];

        // UICountingLabel Licence — Bundle string
        NSString *uiclString = NSLocalizedStringFromTableInBundle(@"licenceUICL_text", @"About", [NSBundle mainBundle], @"UICountingLabel licence text");
        NSMutableAttributedString *uiclAttributedString = [[NSMutableAttributedString alloc] initWithString:uiclString];
        NSRange uiclRange = NSMakeRange(0, [uiclString length]);
        [uiclAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:uiclRange];
        uiclRange = NSMakeRange(0, [uiclString rangeOfString:@"\n"].location);
        [uiclAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:uiclRange];
        [aboutAttributedString appendAttributedString:uiclAttributedString];
        [aboutAttributedString appendAttributedString:spacerAttributedString];

        // MIT Licence — Bundle string
        NSString *mitString = NSLocalizedStringFromTableInBundle(@"licenceMIT_text", @"About", [NSBundle mainBundle], @"AFNetworking licence text");
        NSMutableAttributedString *mitAttributedString = [[NSMutableAttributedString alloc] initWithString:mitString];
        NSRange mitTitleRange = NSMakeRange(0, [mitString length]);
        [mitAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:mitTitleRange];
        mitTitleRange = NSMakeRange(0, [mitString rangeOfString:@"\n"].location);
        [mitAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:mitTitleRange];
        [aboutAttributedString appendAttributedString:mitAttributedString];
        
        self.textView.attributedText = aboutAttributedString;
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoNotificationPaletteChanged object:nil];
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
    self.byLabel1.textColor = [UIColor piwigoTextColor];
    self.byLabel2.textColor = [UIColor piwigoTextColor];
    self.versionLabel.textColor = [UIColor piwigoTextColor];
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
							@"title" : self.piwigoTitle,
							@"by1" : self.byLabel1,
                            @"by2" : self.byLabel2,
							@"usu" : self.versionLabel,
							@"textView" : self.textView
							};
	
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.piwigoTitle]];
	[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel1]];
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel2]];
	[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.versionLabel]];

    if (@available(iOS 11, *)) {
        [self.view addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"V:|-[title][by1][by2]-3-[usu]-10-[textView]-|"
                                   options:kNilOptions metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[textView]-|"
                                                                          options:kNilOptions
                                                                          metrics:nil
                                                                            views:views]];
    } else {
        [self.view addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"V:|-64-[title][by1][by2]-3-[usu]-10-[textView]-|"
                                   options:kNilOptions metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[textView]-15-|"
                                                                          options:kNilOptions
                                                                          metrics:nil
                                                                            views:views]];
    }
}

@end
