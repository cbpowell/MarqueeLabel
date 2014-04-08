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

@synthesize labelizeSwitch;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Timer for changing texts
    self.labelChangeTimer = [NSTimer scheduledTimerWithTimeInterval:4 target:self selector:@selector(changeTheLabel) userInfo:nil repeats:YES];
    
    CBPMarqueeLabel *durationLabel = [[CBPMarqueeLabel alloc] initWithFrame:CGRectMake(10, 100, self.view.frame.size.width-20.0f, 20.0f) duration:8.0 andFadeLength:10.0f];
    durationLabel.tag = 101;
    durationLabel.numberOfLines = 1;
    durationLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    durationLabel.textAlignment = NSTextAlignmentLeft;
    durationLabel.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    durationLabel.backgroundColor = [UIColor clearColor];
    durationLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:18.0f];
    durationLabel.text = @"This is a test of the label. Look how long this label is! It's so long it stretches off the view!";
    [self.view addSubview:durationLabel];
    
    #if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
    MarqueeLabel *attributedLabel = [[MarqueeLabel alloc] initWithFrame:CGRectMake(10, 130, self.view.frame.size.width-20.0f, 26.0f) duration:8.0 andFadeLength:10.0f];
    attributedLabel.marqueeType = CBPMarqueeLabelTypeContinuous;
    attributedLabel.numberOfLines = 1;
    attributedLabel.textAlignment = NSTextAlignmentLeft;
    attributedLabel.backgroundColor = [UIColor clearColor];
    attributedLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:18.0f];
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@"This is a long string, that's also an attributed string, which works just as well!"];
    [attributedString addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"Helvetica-Bold" size:18.0f] range:NSMakeRange(0, 21)];
    [attributedString addAttribute:NSBackgroundColorAttributeName value:[UIColor lightGrayColor] range:NSMakeRange(10,11)];
    [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000] range:NSMakeRange(0,attributedString.length)];
    [attributedString addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue-Light" size:18.0f] range:NSMakeRange(21, attributedString.length - 21)];
    attributedLabel.attributedText = attributedString;
    [self.view addSubview:attributedLabel];
    #endif
    
    // Rate label example
    CBPMarqueeLabel *rateLabelOne = [[CBPMarqueeLabel alloc] initWithFrame:CGRectMake(10, 200, self.view.frame.size.width-20, 20)];
    rateLabelOne.rate = 200.0f;
    rateLabelOne.fadeLength = 10.0f;
    
    rateLabelOne.numberOfLines = 1;
    rateLabelOne.opaque = NO;
    rateLabelOne.enabled = YES;
    rateLabelOne.shadowOffset = CGSizeMake(0.0, -1.0);
    rateLabelOne.textAlignment = NSTextAlignmentLeft;
    rateLabelOne.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    rateLabelOne.backgroundColor = [UIColor clearColor];
    rateLabelOne.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    rateLabelOne.text = @"This is another long label that scrolls at a specific rate, rather than scrolling its length in a specific time window!";
    
    // For Autoresizing test
    rateLabelOne.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:rateLabelOne];
    
    
    // Tap to scroll
    CBPMarqueeLabel *tapToScrollLabel = [[CBPMarqueeLabel alloc] initWithFrame:CGRectMake(10, 230, self.view.frame.size.width-20, 20) rate:50.0f andFadeLength:10.0f];
    tapToScrollLabel.numberOfLines = 1;
    tapToScrollLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    tapToScrollLabel.textAlignment = NSTextAlignmentLeft;
    tapToScrollLabel.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    tapToScrollLabel.backgroundColor = [UIColor clearColor];
    tapToScrollLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    tapToScrollLabel.tapToScroll = YES;
    tapToScrollLabel.text = @"This label will not scroll until tapped, and then it performs its scroll cycle only once.";
    [self.view addSubview:tapToScrollLabel];
    
    
    // CBPMarqueeLabelTypeRightLeft label example
    CBPMarqueeLabel *rightLeftLabel = [[CBPMarqueeLabel alloc] initWithFrame:CGRectMake(10, 260, self.view.frame.size.width-20, 20) rate:50.0f andFadeLength:10.0f];
    rightLeftLabel.numberOfLines = 1;
    rightLeftLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    rightLeftLabel.textAlignment = NSTextAlignmentRight;
    rightLeftLabel.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    rightLeftLabel.backgroundColor = [UIColor clearColor];
    rightLeftLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    rightLeftLabel.marqueeType = CBPMarqueeLabelTypeRightLeft;
    rightLeftLabel.text = @"This text is not as long, but still long enough to scroll, and scrolls the same speed but to the right first!";
    [self.view addSubview:rightLeftLabel];
    
    // Continuous label example
    CBPMarqueeLabel *continuousLabel = [[CBPMarqueeLabel alloc] initWithFrame:CGRectMake(10, 300, self.view.frame.size.width-20, 20) rate:100.0f andFadeLength:10.0f];
    continuousLabel.tag = 102;
    continuousLabel.marqueeType = CBPMarqueeLabelTypeContinuous;
    continuousLabel.numberOfLines = 1;
    continuousLabel.opaque = NO;
    continuousLabel.enabled = YES;
    continuousLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    continuousLabel.textAlignment = NSTextAlignmentCenter;
    continuousLabel.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    continuousLabel.backgroundColor = [UIColor clearColor];
    continuousLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    continuousLabel.text = @"This is a short, centered label.";
    [self.view addSubview:continuousLabel];
    
    // Second continuous label example
    CBPMarqueeLabel *continuousLabel2 = [[CBPMarqueeLabel alloc] initWithFrame:CGRectMake(10, 330, self.view.frame.size.width-20, 20) rate:100.0f andFadeLength:10.0f];
    continuousLabel2.tag = 101;
    continuousLabel2.marqueeType = CBPMarqueeLabelTypeContinuous;
    continuousLabel2.animationCurve = UIViewAnimationOptionCurveLinear;
    continuousLabel2.continuousMarqueeExtraBuffer = 50.0f;
    continuousLabel2.numberOfLines = 1;
    continuousLabel2.opaque = NO;
    continuousLabel2.enabled = YES;
    continuousLabel2.shadowOffset = CGSizeMake(0.0, -1.0);
    continuousLabel2.textAlignment = NSTextAlignmentLeft;
    continuousLabel2.textColor = [UIColor colorWithRed:0.234 green:0.234 blue:0.234 alpha:1.000];
    continuousLabel2.backgroundColor = [UIColor clearColor];
    continuousLabel2.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
    continuousLabel2.text = @"This is another long label that scrolls continuously with a custom space between labels! You can also tap it to pause and unpause it!";
    
    [self.view addSubview:continuousLabel2];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pauseTap:)];
    tapRecognizer.numberOfTapsRequired = 1;
    tapRecognizer.numberOfTouchesRequired = 1;
    [continuousLabel2 addGestureRecognizer:tapRecognizer];
    continuousLabel2.userInteractionEnabled = YES; // Don't forget this, otherwise the gesture recognizer will fail (UILabel has this as NO by default)
    
}

- (void)changeTheLabel {
    // Generate even or odd
    int i = arc4random() % 2;
    if (i == 0) {
        [(CBPMarqueeLabel *)[self.view viewWithTag:101] setText:@"This label is not as long."];
        [(CBPMarqueeLabel *)[self.view viewWithTag:102] setText:@"That also scrolls continuously rather than scrolling back and forth!"];
    } else {
        [(CBPMarqueeLabel *)[self.view viewWithTag:101] setText:@"Now we've switched to a string of text that is longer than the specified frame, and will scroll."];
        [(CBPMarqueeLabel *)[self.view viewWithTag:102] setText:@"This is a short, centered label."];
    }
}

- (void)pauseTap:(UITapGestureRecognizer *)recognizer {
    CBPMarqueeLabel *continuousLabel2 = (CBPMarqueeLabel *)recognizer.view;
    
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
        if ([v isKindOfClass:[CBPMarqueeLabel class]]) {
            [(CBPMarqueeLabel *)v setLabelize:sender.on];
        }
    }
}

- (IBAction)pushNewViewController:(id)sender {
    UIViewController *newViewController = [[UIViewController alloc] initWithNibName:@"ModalViewController" bundle:nil];
    __weak __typeof(&*self)weakSelf = self;
    [self presentViewController:newViewController animated:YES completion:^{
        [NSTimer scheduledTimerWithTimeInterval:5.0 target:weakSelf selector:@selector(dismissTheModal) userInfo:nil repeats:NO];
    }];
}

- (void)dismissTheModal {
    __weak __typeof(&*self)weakSelf = self;
    [self dismissViewControllerAnimated:YES completion:^{
        [CBPMarqueeLabel controllerViewWillAppear:weakSelf];
    }];
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

- (void)viewDidUnload {
    [self.labelChangeTimer invalidate];
    self.labelChangeTimer = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [CBPMarqueeLabel controllerViewWillAppear:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Optionally could use viewDidAppear bulk method
    
    // However, comment out the controllerViewWillAppear: method above, and uncomment the below method
    // to see the text jump when the modal view is finally fully dismissed. This is because viewDidAppear:
    // is not called until the view has fully appeared (animations complete, etc) so the text is not reset
    // to the home position until that point, and then the automatic scrolling begins again.
    
    // [MarqueeLabel controllerViewDidAppear:self];
}


@end
