//
//  MarqueeLabelDemoViewController.h
//  MarqueeLabelDemo
//
//  Created by Charles Powell on 1/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MarqueeLabel.h"

@interface MarqueeLabelDemoViewController : UIViewController {
    
    MarqueeLabel *artistLabel;

}

@property (nonatomic, retain) MarqueeLabel *artistLabel;

-(void) addNewLabel;

@end

