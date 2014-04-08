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
    [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(changeTheLabel) userInfo:nil repeats:YES];
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
    [CBPMarqueeLabel controllerViewAppearing:self];
}


@end
