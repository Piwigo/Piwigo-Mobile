//
//  TagImagesViewController.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TagImagesViewController : UIViewController

-(instancetype)initWithTagId:(NSInteger)tagId andTagName:(NSString *)tagName;

@end
