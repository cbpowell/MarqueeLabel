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

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) IBOutlet MarqueeLabelDemoViewController *viewController;

@end

