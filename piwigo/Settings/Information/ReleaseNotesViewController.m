//
//  ReleaseNotesViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

#import "AppDelegate.h"
#import "ReleaseNotesViewController.h"
#import "Model.h"

@interface ReleaseNotesViewController ()

@property (nonatomic, strong) UILabel *piwigoTitle;
@property (nonatomic, strong) UILabel *byLabel1;
@property (nonatomic, strong) UILabel *byLabel2;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UILabel *releaseNotes;

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIBarButtonItem *doneBarButton;

@end

@implementation ReleaseNotesViewController

-(instancetype)init
{
    self = [super init];
    if(self)
    {
        self.title = NSLocalizedString(@"settings_releaseNotes", @"Release Notes");
        
        self.piwigoTitle = [UILabel new];
        self.piwigoTitle.translatesAutoresizingMaskIntoConstraints = NO;
        self.piwigoTitle.font = [UIFont piwigoFontLarge];
        self.piwigoTitle.textColor = [UIColor piwigoColorOrange];
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
        self.textView.restorationIdentifier = @"release+notes";
        self.textView.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Release notes attributed string
        NSMutableAttributedString *notesAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
        NSMutableAttributedString *spacerAttributedString = [[NSMutableAttributedString alloc] initWithString:@"\n\n\n"];
        NSRange spacerRange = NSMakeRange(0, [spacerAttributedString length]);
        [spacerAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:spacerRange];

        // Release 2.4.7 — Bundle string
        NSString *v247String = NSLocalizedStringFromTableInBundle(@"v2.4.7_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.4.7 Release Notes text");
        NSMutableAttributedString *v247AttributedString = [[NSMutableAttributedString alloc] initWithString:v247String];
        NSRange v247Range = NSMakeRange(0, [v247String length]);
        [v247AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v247Range];
        v247Range = NSMakeRange(0, [v247String rangeOfString:@"\n"].location);
        [v247AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v247Range];
        [notesAttributedString appendAttributedString:v247AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.4.6 — Bundle string
        NSString *v246String = NSLocalizedStringFromTableInBundle(@"v2.4.6_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.4.6 Release Notes text");
        NSMutableAttributedString *v246AttributedString = [[NSMutableAttributedString alloc] initWithString:v246String];
        NSRange v246Range = NSMakeRange(0, [v246String length]);
        [v246AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v246Range];
        v246Range = NSMakeRange(0, [v246String rangeOfString:@"\n"].location);
        [v246AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v246Range];
        [notesAttributedString appendAttributedString:v246AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.4.5 — Bundle string
        NSString *v245String = NSLocalizedStringFromTableInBundle(@"v2.4.5_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.4.5 Release Notes text");
        NSMutableAttributedString *v245AttributedString = [[NSMutableAttributedString alloc] initWithString:v245String];
        NSRange v245Range = NSMakeRange(0, [v245String length]);
        [v245AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v245Range];
        v245Range = NSMakeRange(0, [v245String rangeOfString:@"\n"].location);
        [v245AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v245Range];
        [notesAttributedString appendAttributedString:v245AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.4.4 — Bundle string
        NSString *v244String = NSLocalizedStringFromTableInBundle(@"v2.4.4_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.4.4 Release Notes text");
        NSMutableAttributedString *v244AttributedString = [[NSMutableAttributedString alloc] initWithString:v244String];
        NSRange v244Range = NSMakeRange(0, [v244String length]);
        [v244AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v244Range];
        v244Range = NSMakeRange(0, [v244String rangeOfString:@"\n"].location);
        [v244AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v244Range];
        [notesAttributedString appendAttributedString:v244AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.4.3 — Bundle string
        NSString *v243String = NSLocalizedStringFromTableInBundle(@"v2.4.3_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.4.3 Release Notes text");
        NSMutableAttributedString *v243AttributedString = [[NSMutableAttributedString alloc] initWithString:v243String];
        NSRange v243Range = NSMakeRange(0, [v243String length]);
        [v243AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v243Range];
        v243Range = NSMakeRange(0, [v243String rangeOfString:@"\n"].location);
        [v243AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v243Range];
        [notesAttributedString appendAttributedString:v243AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.4.2 — Bundle string
        NSString *v242String = NSLocalizedStringFromTableInBundle(@"v2.4.2_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.4.2 Release Notes text");
        NSMutableAttributedString *v242AttributedString = [[NSMutableAttributedString alloc] initWithString:v242String];
        NSRange v242Range = NSMakeRange(0, [v242String length]);
        [v242AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v242Range];
        v242Range = NSMakeRange(0, [v242String rangeOfString:@"\n"].location);
        [v242AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v242Range];
        [notesAttributedString appendAttributedString:v242AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.4.1 — Bundle string
        NSString *v241String = NSLocalizedStringFromTableInBundle(@"v2.4.1_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.4.1 Release Notes text");
        NSMutableAttributedString *v241AttributedString = [[NSMutableAttributedString alloc] initWithString:v241String];
        NSRange v241Range = NSMakeRange(0, [v241String length]);
        [v241AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v241Range];
        v241Range = NSMakeRange(0, [v241String rangeOfString:@"\n"].location);
        [v241AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v241Range];
        [notesAttributedString appendAttributedString:v241AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.4 — Bundle string
        NSString *v240String = NSLocalizedStringFromTableInBundle(@"v2.4.0_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.4.0 Release Notes text");
        NSMutableAttributedString *v240AttributedString = [[NSMutableAttributedString alloc] initWithString:v240String];
        NSRange v240Range = NSMakeRange(0, [v240String length]);
        [v240AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v240Range];
        v240Range = NSMakeRange(0, [v240String rangeOfString:@"\n"].location);
        [v240AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v240Range];
        [notesAttributedString appendAttributedString:v240AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.3.5 — Bundle string
        NSString *v235String = NSLocalizedStringFromTableInBundle(@"v2.3.5_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.3.5 Release Notes text");
        NSMutableAttributedString *v235AttributedString = [[NSMutableAttributedString alloc] initWithString:v235String];
        NSRange v235Range = NSMakeRange(0, [v235String length]);
        [v235AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v235Range];
        v235Range = NSMakeRange(0, [v235String rangeOfString:@"\n"].location);
        [v235AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v235Range];
        [notesAttributedString appendAttributedString:v235AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.3.4 — Bundle string
        NSString *v234String = NSLocalizedStringFromTableInBundle(@"v2.3.4_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.3.4 Release Notes text");
        NSMutableAttributedString *v234AttributedString = [[NSMutableAttributedString alloc] initWithString:v234String];
        NSRange v234Range = NSMakeRange(0, [v234String length]);
        [v234AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v234Range];
        v234Range = NSMakeRange(0, [v234String rangeOfString:@"\n"].location);
        [v234AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v234Range];
        [notesAttributedString appendAttributedString:v234AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.3.3 — Bundle string
        NSString *v233String = NSLocalizedStringFromTableInBundle(@"v2.3.3_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.3.3 Release Notes text");
        NSMutableAttributedString *v233AttributedString = [[NSMutableAttributedString alloc] initWithString:v233String];
        NSRange v233Range = NSMakeRange(0, [v233String length]);
        [v233AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v233Range];
        v233Range = NSMakeRange(0, [v233String rangeOfString:@"\n"].location);
        [v233AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v233Range];
        [notesAttributedString appendAttributedString:v233AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.3.2 — Bundle string
        NSString *v232String = NSLocalizedStringFromTableInBundle(@"v2.3.2_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.3.2 Release Notes text");
        NSMutableAttributedString *v232AttributedString = [[NSMutableAttributedString alloc] initWithString:v232String];
        NSRange v232Range = NSMakeRange(0, [v232String length]);
        [v232AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v232Range];
        v232Range = NSMakeRange(0, [v232String rangeOfString:@"\n"].location);
        [v232AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v232Range];
        [notesAttributedString appendAttributedString:v232AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.3.1 — Bundle string
        NSString *v231String = NSLocalizedStringFromTableInBundle(@"v2.3.1_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.3.1 Release Notes text");
        NSMutableAttributedString *v231AttributedString = [[NSMutableAttributedString alloc] initWithString:v231String];
        NSRange v231Range = NSMakeRange(0, [v231String length]);
        [v231AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v231Range];
        v231Range = NSMakeRange(0, [v231String rangeOfString:@"\n"].location);
        [v231AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v231Range];
        [notesAttributedString appendAttributedString:v231AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.3 — Bundle string
        NSString *v230String = NSLocalizedStringFromTableInBundle(@"v2.3.0_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.3.0 Release Notes text");
        NSMutableAttributedString *v230AttributedString = [[NSMutableAttributedString alloc] initWithString:v230String];
        NSRange v230Range = NSMakeRange(0, [v230String length]);
        [v230AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v230Range];
        v230Range = NSMakeRange(0, [v230String rangeOfString:@"\n"].location);
        [v230AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v230Range];
        [notesAttributedString appendAttributedString:v230AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.2.7 — Bundle string
        NSString *v227String = NSLocalizedStringFromTableInBundle(@"v2.2.7_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.2.7 Release Notes text");
        NSMutableAttributedString *v227AttributedString = [[NSMutableAttributedString alloc] initWithString:v227String];
        NSRange v227Range = NSMakeRange(0, [v227String length]);
        [v227AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v227Range];
        v227Range = NSMakeRange(0, [v227String rangeOfString:@"\n"].location);
        [v227AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v227Range];
        [notesAttributedString appendAttributedString:v227AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.2.6 — Bundle string
        NSString *v226String = NSLocalizedStringFromTableInBundle(@"v2.2.6_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.2.6 Release Notes text");
        NSMutableAttributedString *v226AttributedString = [[NSMutableAttributedString alloc] initWithString:v226String];
        NSRange v226Range = NSMakeRange(0, [v226String length]);
        [v226AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v226Range];
        v226Range = NSMakeRange(0, [v226String rangeOfString:@"\n"].location);
        [v226AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v226Range];
        [notesAttributedString appendAttributedString:v226AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.2.5 — Bundle string
        NSString *v225String = NSLocalizedStringFromTableInBundle(@"v2.2.5_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.2.5 Release Notes text");
        NSMutableAttributedString *v225AttributedString = [[NSMutableAttributedString alloc] initWithString:v225String];
        NSRange v225Range = NSMakeRange(0, [v225String length]);
        [v225AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v225Range];
        v225Range = NSMakeRange(0, [v225String rangeOfString:@"\n"].location);
        [v225AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v225Range];
        [notesAttributedString appendAttributedString:v225AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.2.4 — Bundle string
        NSString *v224String = NSLocalizedStringFromTableInBundle(@"v2.2.4_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.2.4 Release Notes text");
        NSMutableAttributedString *v224AttributedString = [[NSMutableAttributedString alloc] initWithString:v224String];
        NSRange v224Range = NSMakeRange(0, [v224String length]);
        [v224AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v224Range];
        v224Range = NSMakeRange(0, [v224String rangeOfString:@"\n"].location);
        [v224AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v224Range];
        [notesAttributedString appendAttributedString:v224AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.2.3 — Bundle string
        NSString *v223String = NSLocalizedStringFromTableInBundle(@"v2.2.3_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.2.3 Release Notes text");
        NSMutableAttributedString *v223AttributedString = [[NSMutableAttributedString alloc] initWithString:v223String];
        NSRange v223Range = NSMakeRange(0, [v223String length]);
        [v223AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v223Range];
        v223Range = NSMakeRange(0, [v223String rangeOfString:@"\n"].location);
        [v223AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v223Range];
        [notesAttributedString appendAttributedString:v223AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.2.2 — Bundle string
        NSString *v222String = NSLocalizedStringFromTableInBundle(@"v2.2.2_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.2.2 Release Notes text");
        NSMutableAttributedString *v222AttributedString = [[NSMutableAttributedString alloc] initWithString:v222String];
        NSRange v222Range = NSMakeRange(0, [v222String length]);
        [v222AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v222Range];
        v222Range = NSMakeRange(0, [v222String rangeOfString:@"\n"].location);
        [v222AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v222Range];
        [notesAttributedString appendAttributedString:v222AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.2.1 — Bundle string
        NSString *v221String = NSLocalizedStringFromTableInBundle(@"v2.2.1_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.2.1 Release Notes text");
        NSMutableAttributedString *v221AttributedString = [[NSMutableAttributedString alloc] initWithString:v221String];
        NSRange v221Range = NSMakeRange(0, [v221String length]);
        [v221AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v221Range];
        v221Range = NSMakeRange(0, [v221String rangeOfString:@"\n"].location);
        [v221AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v221Range];
        [notesAttributedString appendAttributedString:v221AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];
        
        // Release 2.2.0 — Bundle string
        NSString *v220String = NSLocalizedStringFromTableInBundle(@"v2.2.0_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.2.0 Release Notes text");
        NSMutableAttributedString *v220AttributedString = [[NSMutableAttributedString alloc] initWithString:v220String];
        NSRange v220Range = NSMakeRange(0, [v220String length]);
        [v220AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v220Range];
        v220Range = NSMakeRange(0, [v220String rangeOfString:@"\n"].location);
        [v220AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v220Range];
        [notesAttributedString appendAttributedString:v220AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.1.9 — Bundle string
        NSString *v219String = NSLocalizedStringFromTableInBundle(@"v2.1.9_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.9 Release Notes text");
        NSMutableAttributedString *v219AttributedString = [[NSMutableAttributedString alloc] initWithString:v219String];
        NSRange v219Range = NSMakeRange(0, [v219String length]);
        [v219AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v219Range];
        v219Range = NSMakeRange(0, [v219String rangeOfString:@"\n"].location);
        [v219AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v219Range];
        [notesAttributedString appendAttributedString:v219AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.1.8 — Bundle string
        NSString *v218String = NSLocalizedStringFromTableInBundle(@"v2.1.8_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.8 Release Notes text");
        NSMutableAttributedString *v218AttributedString = [[NSMutableAttributedString alloc] initWithString:v218String];
        NSRange v218Range = NSMakeRange(0, [v218String length]);
        [v218AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v218Range];
        v218Range = NSMakeRange(0, [v218String rangeOfString:@"\n"].location);
        [v218AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v218Range];
        [notesAttributedString appendAttributedString:v218AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.1.7 — Bundle string
        NSString *v217String = NSLocalizedStringFromTableInBundle(@"v2.1.7_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.7 Release Notes text");
        NSMutableAttributedString *v217AttributedString = [[NSMutableAttributedString alloc] initWithString:v217String];
        NSRange v217Range = NSMakeRange(0, [v217String length]);
        [v217AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v217Range];
        v217Range = NSMakeRange(0, [v217String rangeOfString:@"\n"].location);
        [v217AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v217Range];
        [notesAttributedString appendAttributedString:v217AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.1.6 — Bundle string
        NSString *v216String = NSLocalizedStringFromTableInBundle(@"v2.1.6_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.6 Release Notes text");
        NSMutableAttributedString *v216AttributedString = [[NSMutableAttributedString alloc] initWithString:v216String];
        NSRange v216Range = NSMakeRange(0, [v216String length]);
        [v216AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v216Range];
        v216Range = NSMakeRange(0, [v216String rangeOfString:@"\n"].location);
        [v216AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v216Range];
        [notesAttributedString appendAttributedString:v216AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.1.5 — Bundle string
        NSString *v215String = NSLocalizedStringFromTableInBundle(@"v2.1.5_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.5 Release Notes text");
        NSMutableAttributedString *v215AttributedString = [[NSMutableAttributedString alloc] initWithString:v215String];
        NSRange v215Range = NSMakeRange(0, [v215String length]);
        [v215AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v215Range];
        v215Range = NSMakeRange(0, [v215String rangeOfString:@"\n"].location);
        [v215AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v215Range];
        [notesAttributedString appendAttributedString:v215AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.1.4 — Bundle string
        NSString *v214String = NSLocalizedStringFromTableInBundle(@"v2.1.4_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.4 Release Notes text");
        NSMutableAttributedString *v214AttributedString = [[NSMutableAttributedString alloc] initWithString:v214String];
        NSRange v214Range = NSMakeRange(0, [v214String length]);
        [v214AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v214Range];
        v214Range = NSMakeRange(0, [v214String rangeOfString:@"\n"].location);
        [v214AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v214Range];
        [notesAttributedString appendAttributedString:v214AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.1.3 — Bundle string
        NSString *v213String = NSLocalizedStringFromTableInBundle(@"v2.1.3_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.3 Release Notes text");
        NSMutableAttributedString *v213AttributedString = [[NSMutableAttributedString alloc] initWithString:v213String];
        NSRange v213Range = NSMakeRange(0, [v213String length]);
        [v213AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v213Range];
        v213Range = NSMakeRange(0, [v213String rangeOfString:@"\n"].location);
        [v213AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v213Range];
        [notesAttributedString appendAttributedString:v213AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.1.2 — Bundle string
        NSString *v212String = NSLocalizedStringFromTableInBundle(@"v2.1.2_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.2 Release Notes text");
        NSMutableAttributedString *v212AttributedString = [[NSMutableAttributedString alloc] initWithString:v212String];
        NSRange v212Range = NSMakeRange(0, [v212String length]);
        [v212AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v212Range];
        v212Range = NSMakeRange(0, [v212String rangeOfString:@"\n"].location);
        [v212AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v212Range];
        [notesAttributedString appendAttributedString:v212AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.1.1 — Bundle string
        NSString *v211String = NSLocalizedStringFromTableInBundle(@"v2.1.1_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.1 Release Notes text");
        NSMutableAttributedString *v211AttributedString = [[NSMutableAttributedString alloc] initWithString:v211String];
        NSRange v211Range = NSMakeRange(0, [v211String length]);
        [v211AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v211Range];
        v211Range = NSMakeRange(0, [v211String rangeOfString:@"\n"].location);
        [v211AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v211Range];
        [notesAttributedString appendAttributedString:v211AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.1.0 — Bundle string
        NSString *v210String = NSLocalizedStringFromTableInBundle(@"v2.1.0_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.0 Release Notes text");
        NSMutableAttributedString *v210AttributedString = [[NSMutableAttributedString alloc] initWithString:v210String];
        NSRange v210Range = NSMakeRange(0, [v210String length]);
        [v210AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v210Range];
        v210Range = NSMakeRange(0, [v210String rangeOfString:@"\n"].location);
        [v210AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v210Range];
        [notesAttributedString appendAttributedString:v210AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.0.4 — Bundle string
        NSString *v204String = NSLocalizedStringFromTableInBundle(@"v2.0.4_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.4 Release Notes text");
        NSMutableAttributedString *v204AttributedString = [[NSMutableAttributedString alloc] initWithString:v204String];
        NSRange v204Range = NSMakeRange(0, [v204String length]);
        [v204AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v204Range];
        v204Range = NSMakeRange(0, [v204String rangeOfString:@"\n"].location);
        [v204AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v204Range];
        [notesAttributedString appendAttributedString:v204AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.0.3 — Bundle string
        NSString *v203String = NSLocalizedStringFromTableInBundle(@"v2.0.3_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.3 Release Notes text");
        NSMutableAttributedString *v203AttributedString = [[NSMutableAttributedString alloc] initWithString:v203String];
        NSRange v203Range = NSMakeRange(0, [v203String length]);
        [v203AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v203Range];
        v203Range = NSMakeRange(0, [v203String rangeOfString:@"\n"].location);
        [v203AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v203Range];
        [notesAttributedString appendAttributedString:v203AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.0.2 — Bundle string
        NSString *v202String = NSLocalizedStringFromTableInBundle(@"v2.0.2_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.2 Release Notes text");
        NSMutableAttributedString *v202AttributedString = [[NSMutableAttributedString alloc] initWithString:v202String];
        NSRange v202Range = NSMakeRange(0, [v202String length]);
        [v202AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v202Range];
        v202Range = NSMakeRange(0, [v202String rangeOfString:@"\n"].location);
        [v202AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v202Range];
        [notesAttributedString appendAttributedString:v202AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.0.1 — Bundle string
        NSString *v201String = NSLocalizedStringFromTableInBundle(@"v2.0.1_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.1 Release Notes text");
        NSMutableAttributedString *v201AttributedString = [[NSMutableAttributedString alloc] initWithString:v201String];
        NSRange v201Range = NSMakeRange(0, [v201String length]);
        [v201AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v201Range];
        v201Range = NSMakeRange(0, [v201String rangeOfString:@"\n"].location);
        [v201AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v201Range];
        [notesAttributedString appendAttributedString:v201AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 2.0.0 — Bundle string
        NSString *v200String = NSLocalizedStringFromTableInBundle(@"v2.0.0_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.0 Release Notes text");
        NSMutableAttributedString *v200AttributedString = [[NSMutableAttributedString alloc] initWithString:v200String];
        NSRange v200Range = NSMakeRange(0, [v200String length]);
        [v200AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v200Range];
        v200Range = NSMakeRange(0, [v200String rangeOfString:@"\n"].location);
        [v200AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v200Range];
        [notesAttributedString appendAttributedString:v200AttributedString];
        [notesAttributedString appendAttributedString:spacerAttributedString];

        // Release 1.0.0 — Bundle string
        NSString *v100String = NSLocalizedStringFromTableInBundle(@"v1.0.0_text", @"ReleaseNotes", [NSBundle mainBundle], @"v1.0.0 Release Notes text");
        NSMutableAttributedString *v100AttributedString = [[NSMutableAttributedString alloc] initWithString:v100String];
        NSRange v100Range = NSMakeRange(0, [v100String length]);
        [v100AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall] range:v100Range];
        v100Range = NSMakeRange(0, [v100String rangeOfString:@"\n"].location);
        [v100AttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold] range:v100Range];
        [notesAttributedString appendAttributedString:v100AttributedString];
        
        self.textView.attributedText = notesAttributedString;
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
    self.view.backgroundColor = [UIColor piwigoColorBackground];

    // Navigation bar
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoColorWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.navigationBar.tintColor = [UIColor piwigoColorOrange];
    self.navigationController.navigationBar.barTintColor = [UIColor piwigoColorBackground];
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoColorBackground];

    // Text color depdending on background color
    self.byLabel1.textColor = [UIColor piwigoColorText];
    self.byLabel2.textColor = [UIColor piwigoColorText];
    self.versionLabel.textColor = [UIColor piwigoColorText];
    self.textView.textColor = [UIColor piwigoColorText];
    self.textView.backgroundColor = [UIColor piwigoColorBackground];
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
