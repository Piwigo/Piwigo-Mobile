//
//  TaggedImagesViewController.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TaggedImagesViewController : UIViewController

-(instancetype)initWithTagId:(NSInteger)tagId andTagName:(NSString *)tagName;
-(void)removeImageWithId:(NSInteger)imageId;

@end
