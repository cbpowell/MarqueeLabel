//
//  MarqueeLabelDemoViewController.m
//  MarqueeLabelDemo
//
//  Created by Charles Powell on 1/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MarqueeLabelDemoViewController.h"

@implementation MarqueeLabelDemoViewController

@synthesize artistLabel;

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
    
    self.artistLabel = [[MarqueeLabel alloc] initWithFrame:CGRectMake(10, 100, self.view.frame.size.width - 20, 20)];
    [self.view addSubview:artistLabel];
    [artistLabel release];
    /*
    artistLabel.numberOfLines = 1;
    artistLabel.opaque = NO;
    artistLabel.enabled = YES;
    artistLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    artistLabel.textAlignment = UITextAlignmentLeft;
    artistLabel.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    artistLabel.backgroundColor = [UIColor clearColor];
    artistLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    */
    
    [artistLabel setText:@"This is a test of the label. Look how long this label is! It's so long it stretches off the view!"];
    
    artistLabel.text = @"This is a test of the label! It's still very long and larger than the iPhone can display in a single line across the screen.";
    
    NSLog(@"Creating label");
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 150, self.view.frame.size.width - 20, 20)];
    subLabel.text = @"This is a test of the label";
    [self.view addSubview:subLabel];
    [subLabel release];
    
    [artistLabel scrollWithLoop:YES andSpeed:7];
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(addNewLabel) userInfo:nil repeats:NO];
    NSTimer *timer2 = [NSTimer scheduledTimerWithTimeInterval:20 target:self selector:@selector(addAnotherNewLabel) userInfo:nil repeats:NO];
    
    

}

- (void) addNewLabel {
    UILabel *testLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 320, 20)];
    testLabel.text = @"Adding a new label!";
    [self.view addSubview:testLabel];
    [testLabel release];
    
    [artistLabel setText:@"Testing mid-animation label changes"];
    
}


- (void)addAnotherNewLabel {
    [artistLabel setText:@"a;lsdkjfa;lskdjfa;lsjdf;alsjkdf;lajksdf;lakjsdflajsdl;fja;lsdjfla;jsdlfkasl;dkfja"];
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
