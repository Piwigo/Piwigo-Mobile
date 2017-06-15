//
//  ServerField.h
//  piwigo
//
//  Created by Spencer Baker on 3/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
	ProtocolTypeHttp = 0,
	ProtocolTypeHttps = 1
} ProtocolType;

@class PiwigoTextField;

@interface ServerField : UIView

@property (nonatomic, strong) PiwigoTextField *textField;
@property (nonatomic, assign) ProtocolType protocolType;

-(NSString*)getProtocolString;

@end
