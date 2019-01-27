//
//  LabelImageTableViewCell.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LabelImageTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *leftLabel;
@property (weak, nonatomic) IBOutlet UIImageView *rightAddImage;
@property (weak, nonatomic) IBOutlet UIImageView *rightRemoveImage;

-(void)setupWithActivityName:(NSString *)activity sharingPrivateMetadata:(BOOL)isSharing;

@end
