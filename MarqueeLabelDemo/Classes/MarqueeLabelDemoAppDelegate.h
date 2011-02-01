//
//  MarqueeLabelDemoAppDelegate.h
//  MarqueeLabelDemo
//
//  Created by Charles Powell on 1/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MarqueeLabelDemoViewController;

@interface MarqueeLabelDemoAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    MarqueeLabelDemoViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet MarqueeLabelDemoViewController *viewController;

@end

