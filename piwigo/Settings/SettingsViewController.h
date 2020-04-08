//
//  SettingsViewController.h
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ChangedSettingsDelegate <NSObject>

-(void)didChangeDefaultAlbum;

@end

@interface SettingsViewController : UIViewController

@property (nonatomic, weak) id<ChangedSettingsDelegate> settingsDelegate;

@end
