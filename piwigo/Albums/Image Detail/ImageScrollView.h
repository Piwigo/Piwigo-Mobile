//
//  ImageScrollView.h
//  piwigo
//
//  Created by Spencer Baker on 2/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@interface ImageScrollView : UIScrollView

@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, strong) MPMoviePlayerController *player;
-(void)setupPlayerWithURL:(NSString*)videoURL;

@end
