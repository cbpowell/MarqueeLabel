/**
 * Copyright (c) 2012 Charles Powell
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
@synthesize labelizeSwitch;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.demoLabel = [[MarqueeLabel alloc] initWithFrame:CGRectMake(10, 100, self.view.frame.size.width-20, 20) duration:8.0 andFadeLength:10.0f];
    
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
    
    [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(changeTheLabel) userInfo:nil repeats:YES];
    
    // Rate-speed label example
    MarqueeLabel *rateLabelOne = [[MarqueeLabel alloc] initWithFrame:CGRectMake(10, 200, self.view.frame.size.width-20, 20) rate:50.0f andFadeLength:10.0f];
    rateLabelOne.numberOfLines = 1;
    rateLabelOne.opaque = NO;
    rateLabelOne.enabled = YES;
    rateLabelOne.fadeLength = 10.f;
    rateLabelOne.shadowOffset = CGSizeMake(0.0, -1.0);
    rateLabelOne.textAlignment = UITextAlignmentRight;
    rateLabelOne.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    rateLabelOne.backgroundColor = [UIColor clearColor];
    rateLabelOne.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    
    rateLabelOne.text = @"This is another long label that scrolls at a specific rate, rather than scrolling its length in a specific time window!";
    
    // For Autoresizing test
    rateLabelOne.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    [self.view addSubview:rateLabelOne];
    
    MarqueeLabel *rateLabelTwo = [[MarqueeLabel alloc] initWithFrame:CGRectMake(10, 230, self.view.frame.size.width-20, 20) rate:50.0f andFadeLength:10.0f];
    rateLabelTwo.numberOfLines = 1;
    rateLabelTwo.opaque = NO;
    rateLabelTwo.enabled = YES;
    rateLabelTwo.shadowOffset = CGSizeMake(0.0, -1.0);
    rateLabelTwo.textAlignment = UITextAlignmentRight;
    rateLabelTwo.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    rateLabelTwo.backgroundColor = [UIColor clearColor];
    rateLabelTwo.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    
    rateLabelTwo.tapToScroll = YES;
    rateLabelTwo.text = @"This label will not scroll until tapped, and then it performs its scroll cycle only once.";
    
    [self.view addSubview:rateLabelTwo];
    
    MarqueeLabel *rateLabelThree = [[MarqueeLabel alloc] initWithFrame:CGRectMake(10, 260, self.view.frame.size.width-20, 20) rate:50.0f andFadeLength:10.0f];
    rateLabelThree.numberOfLines = 1;
    rateLabelThree.opaque = NO;
    rateLabelThree.enabled = YES;
    rateLabelThree.shadowOffset = CGSizeMake(0.0, -1.0);
    rateLabelThree.textAlignment = UITextAlignmentRight;
    rateLabelThree.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    rateLabelThree.backgroundColor = [UIColor clearColor];
    rateLabelThree.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    
    rateLabelThree.marqueeType = MLRightLeft;
    rateLabelThree.text =@"This text is not as long, but still long enough to scroll, and scrolls the same speed but to the right first!";
    
    [self.view addSubview:rateLabelThree];
    
    // Continuous label example
    MarqueeLabel *continuousLabel = [[MarqueeLabel alloc] initWithFrame:CGRectMake(10, 300, self.view.frame.size.width-20, 20) rate:50.0f andFadeLength:10.0f];
    continuousLabel.marqueeType = MLContinuous;
    continuousLabel.numberOfLines = 1;
    continuousLabel.opaque = NO;
    continuousLabel.enabled = YES;
    continuousLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    continuousLabel.textAlignment = UITextAlignmentLeft;
    continuousLabel.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    continuousLabel.backgroundColor = [UIColor clearColor];
    continuousLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    continuousLabel.text = @"This is another long label that scrolls continuously rather than scrolling back and forth!";
    
    [self.view addSubview:continuousLabel];
    
    MarqueeLabel *continuousLabel2 = [[MarqueeLabel alloc] initWithFrame:CGRectMake(10, 330, self.view.frame.size.width-20, 20) rate:50.0f andFadeLength:10.0f];
    continuousLabel2.marqueeType = MLContinuous;
    continuousLabel2.continuousMarqueeSeparator = @"  |SEPARATOR|  ";
    continuousLabel2.animationCurve = UIViewAnimationOptionCurveLinear;
    continuousLabel2.numberOfLines = 1;
    continuousLabel2.opaque = NO;
    continuousLabel2.enabled = YES;
    continuousLabel2.shadowOffset = CGSizeMake(0.0, -1.0);
    continuousLabel2.textAlignment = UITextAlignmentLeft;
    continuousLabel2.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    continuousLabel2.backgroundColor = [UIColor clearColor];
    continuousLabel2.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    continuousLabel2.text = @"This is another long label that scrolls continuously with a custom label separator! You can also tap it to pause and unpause it!";
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pauseTap:)];
    [continuousLabel2 addGestureRecognizer:tapRecognizer];
    continuousLabel2.tag = 101;
    
    [self.view addSubview:continuousLabel2];
}

- (void)changeTheLabel {
    // Generate even or odd
    int i = arc4random() % 2;
    if (i == 0) {
        self.demoLabel.text = @"This label is not as long.";
    } else {
        self.demoLabel.text = @"Now we've switched to a string of text that is longer than the specified frame, and will scroll.";
    }
}

- (void)pauseTap:(UITapGestureRecognizer *)recognizer {
    MarqueeLabel *continuousLabel2 = (MarqueeLabel *)recognizer.view;
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if (!continuousLabel2.isPaused) {
            [continuousLabel2 pauseLabel];
        } else {
            [continuousLabel2 unpauseLabel];
        }
    }
}

- (IBAction)labelizeSwitched:(UISwitch *)sender {
    for (UIView *v in self.view.subviews) {
        if ([v isKindOfClass:[MarqueeLabel class]]) {
            [(MarqueeLabel *)v setLabelize:sender.on];
        }
    }
}

- (IBAction)pushNewViewController:(id)sender {
    UIViewController *newViewController = [[UIViewController alloc] initWithNibName:@"ModalViewController" bundle:nil];
    [self presentViewController:newViewController animated:YES completion:^{
        [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(dismissTheModal) userInfo:nil repeats:NO];
    }];
}

- (void)dismissTheModal {
    [self dismissViewControllerAnimated:YES completion:nil];
}
     
// For Autoresizing test
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [MarqueeLabel controllerViewAppearing:self];
}

- (void)viewDidUnload {
	[super viewDidUnload];
    
    self.demoLabel = nil;
}



@end
