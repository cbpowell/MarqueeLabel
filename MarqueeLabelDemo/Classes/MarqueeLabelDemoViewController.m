/**
 * Copyright (c) 2011 Charles Powell
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

//
//  MarqueeLabelDemoViewController.m
//  MarqueeLabelDemo
//

#import "MarqueeLabelDemoViewController.h"

@implementation MarqueeLabelDemoViewController

@synthesize demoLabel;

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
    
    MarqueeLabel *newLabel = [[MarqueeLabel alloc] initWithFrame:CGRectMake(10, 100, self.view.frame.size.width-20, 20) duration:8.0 andFadeLength:10.0f];
    self.demoLabel = newLabel;
    [newLabel release];
    
    [self.view addSubview:self.demoLabel];
    
    self.demoLabel.numberOfLines = 1;
    self.demoLabel.opaque = NO;
    self.demoLabel.enabled = YES;
    self.demoLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    self.demoLabel.textAlignment = UITextAlignmentLeft;
    self.demoLabel.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    self.demoLabel.backgroundColor = [UIColor clearColor];
    self.demoLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    
    self.demoLabel.text = @"This is a test of the label. Look how long this label is! It's so long it stretches off the view!";

    [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(changeTheLabel) userInfo:nil repeats:NO];
    
    // Rate-speed label example
    MarqueeLabel *rateLabelOne = [[MarqueeLabel alloc] initWithFrame:CGRectMake(10, 200, self.view.frame.size.width-20, 20) rate:50.0f andFadeLength:10.0f];
    rateLabelOne.numberOfLines = 1;
    rateLabelOne.opaque = NO;
    rateLabelOne.enabled = YES;
    rateLabelOne.shadowOffset = CGSizeMake(0.0, -1.0);
    rateLabelOne.textAlignment = UITextAlignmentLeft;
    rateLabelOne.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    rateLabelOne.backgroundColor = [UIColor clearColor];
    rateLabelOne.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    rateLabelOne.text = @"This is another long label that scrolls at a specific rate, rather than scrolling its length in a specific time window!";
    
    [self.view addSubview:rateLabelOne];
    [rateLabelOne release];
    
    MarqueeLabel *rateLabelTwo = [[MarqueeLabel alloc] initWithFrame:CGRectMake(10, 230, self.view.frame.size.width-20, 20) rate:50.0f andFadeLength:10.0f];
    rateLabelTwo.numberOfLines = 1;
    rateLabelTwo.opaque = NO;
    rateLabelTwo.enabled = YES;
    rateLabelTwo.shadowOffset = CGSizeMake(0.0, -1.0);
    rateLabelTwo.textAlignment = UITextAlignmentLeft;
    rateLabelTwo.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    rateLabelTwo.backgroundColor = [UIColor clearColor];
    rateLabelTwo.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    rateLabelTwo.text = @"This text is not as long, but still long enough to scroll, and scrolls the same speed!";
    
    [self.view addSubview:rateLabelTwo];
    [rateLabelTwo release];
    
}

- (void)changeTheLabel {
    self.demoLabel.text = @"This label is not as long.";
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
    
    self.demoLabel = nil;
    
    [super dealloc];
}

@end
