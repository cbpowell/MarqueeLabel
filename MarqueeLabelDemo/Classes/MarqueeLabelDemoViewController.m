//
//  MarqueeLabelDemoViewController.m
//  MarqueeLabelDemo
//
//  Created by Charles Powell on 1/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MarqueeLabelDemoViewController.h"

@implementation MarqueeLabelDemoViewController



/*
// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/



// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    MarqueeLabel *newLabel = [[MarqueeLabel alloc] initWithFrame:CGRectMake(10, 100, self.view.frame.size.width - 20, 20)];
    [self.view addSubview:newLabel];
    [newLabel release];
    
    [newLabel setText:@"This is a test of the label. Look how long this label is! It's so long it stretches off the view!"];
    
    NSLog(@"Creating label");
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 150, self.view.frame.size.width - 20, 20)];
    subLabel.text = @"This is a test of the label";
    [self.view addSubview:subLabel];
    [subLabel release];
    
    [newLabel scrollLeft];

}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}

@end
