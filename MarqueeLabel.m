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
//  MarqueeLabel.m
//  

#import "MarqueeLabel.h"
#import <QuartzCore/QuartzCore.h>


// Thanks to Phil M
// http://stackoverflow.com/questions/1340434/get-to-uiviewcontroller-from-uiview-on-iphone

@interface UIView (FindUIViewController)
- (UIViewController *) firstAvailableUIViewController;
- (id) traverseResponderChainForUIViewController;
@end

@implementation UIView (FindUIViewController)
- (UIViewController *) firstAvailableUIViewController {
    // convenience function for casting and to "mask" the recursive function
    return (UIViewController *)[self traverseResponderChainForUIViewController];
}

- (id) traverseResponderChainForUIViewController {
    id nextResponder = [self nextResponder];
    if ([nextResponder isKindOfClass:[UIViewController class]]) {
        return nextResponder;
    } else if ([nextResponder isKindOfClass:[UIView class]]) {
        return [nextResponder traverseResponderChainForUIViewController];
    } else {
        return nil;
    }
}
@end


@interface MarqueeLabel()

@property (nonatomic, readwrite) BOOL awayFromHome;

@property (nonatomic, retain) UILabel *subLabel;
@property (nonatomic, retain) NSString *labelText;
@property (nonatomic) NSUInteger animationOptions;

@property (nonatomic) NSTimeInterval animationDuration;
@property (nonatomic) NSTimeInterval lengthOfScroll;
@property (nonatomic) CGFloat rate;
@property (nonatomic, readonly) BOOL labelShouldScroll;

@property (nonatomic) CGRect homeLabelFrame;
@property (nonatomic) CGRect awayLabelFrame;

@property (nonatomic) CGFloat baseAlpha;

- (void)scrollLeftWithInterval:(NSTimeInterval)interval;
- (void)scrollRightWithInterval:(NSTimeInterval)interval;
- (void)returnLabelToOriginImmediately;
- (void)restartLabel;
- (void)setupLabel;
- (void)observedViewControllerChange:(NSNotification *)notification;
- (void)applyGradientMask;

@end


@implementation MarqueeLabel

@synthesize subLabel, labelText;
@synthesize animationDuration, lengthOfScroll, rate, labelShouldScroll;
@synthesize animationOptions, homeLabelFrame, awayLabelFrame, baseAlpha;
@synthesize awayFromHome;
@synthesize animationCurve, labelize, fadeLength;

// UILabel properties for pass through WITH modification
@synthesize text;
@dynamic adjustsFontSizeToFitWidth, lineBreakMode, numberOfLines;

// UIView override properties
@synthesize backgroundColor;

// Pass through properties (no modification)
@dynamic baselineAdjustment, enabled, font, highlighted, highlightedTextColor, minimumFontSize;
@dynamic shadowColor, shadowOffset, textAlignment, textColor, userInteractionEnabled;


#pragma mark -
#pragma mark Initialization

- (id)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame duration:7.0 andFadeLength:0.0];
}

- (id)initWithFrame:(CGRect)frame duration:(NSTimeInterval)aLengthOfScroll andFadeLength:(float)aFadeLength {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLabel];
        
        self.lengthOfScroll = aLengthOfScroll;
        self.fadeLength = MIN(aFadeLength, frame.size.width/2);
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame rate:(float)pixelsPerSec andFadeLength:(float)aFadeLength {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLabel];
        
        self.rate = pixelsPerSec;
        self.fadeLength = MIN(aFadeLength, frame.size.width/2);
    }
    return self;
}

- (void)setupLabel {
    
    [self setClipsToBounds:YES];
    self.backgroundColor = [UIColor clearColor];
    self.animationOptions = (UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction);
    self.awayFromHome = NO;
    self.labelize = NO;
    self.labelText = nil;
    
    // Create sublabel
    UILabel *newLabel = [[UILabel alloc] initWithFrame:self.bounds];
    self.subLabel = newLabel;
    [self addSubview:self.subLabel];
    [newLabel release];
    
    // Add notification observers
    // UINavigationController view controller change notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observedViewControllerChange:) name:@"UINavigationControllerDidShowViewControllerNotification" object:nil];
    // UIApplication state notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(restartLabel) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(restartLabel) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shutdownLabel) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shutdownLabel) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)observedViewControllerChange:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    UIViewController *fromController = [userInfo objectForKey:@"UINavigationControllerLastVisibleViewController"];
    UIViewController *toController = [userInfo objectForKey:@"UINavigationControllerNextVisibleViewController"];
    
    UIViewController *ownController = [self firstAvailableUIViewController];
    if (fromController == ownController) {
        [self shutdownLabel];
        return;
    }
    
    if (toController == ownController) {
        [self restartLabel];
        return;
    }
}

- (void)applyGradientMask {
    [self returnLabelToOriginImmediately];
    if (self.fadeLength != 0.0f) {
        CAGradientLayer* gradientMask = [CAGradientLayer layer];
        gradientMask.bounds = self.layer.bounds;
        gradientMask.position = CGPointMake([self bounds].size.width / 2, [self bounds].size.height / 2);
        NSObject *transparent = (NSObject*) [[UIColor clearColor] CGColor];
        NSObject *opaque = (NSObject*) [[UIColor blackColor] CGColor];
        gradientMask.startPoint = CGPointMake(0.0, CGRectGetMidY(self.frame));
        gradientMask.endPoint = CGPointMake(1.0, CGRectGetMidY(self.frame));
        float fadePoint = (float)self.fadeLength/self.frame.size.width;
        [gradientMask setColors: [NSArray arrayWithObjects: transparent, opaque, opaque, transparent, nil]];
        [gradientMask setLocations: [NSArray arrayWithObjects:
                                     [NSNumber numberWithFloat: 0.0],
                                     [NSNumber numberWithFloat: fadePoint],
                                     [NSNumber numberWithFloat: 1 - fadePoint],
                                     [NSNumber numberWithFloat: 1.0],
                                     nil]];
        self.layer.mask = gradientMask;
    } else {
        self.layer.mask = nil;
    }
    
    if (self.labelShouldScroll) {
        [self scrollLeftWithInterval:self.animationDuration];
    }
}

#pragma mark -
#pragma mark Animation Handlers 

- (void)scrollLeftWithInterval:(NSTimeInterval)interval {
    
    // Perform animation
    self.awayFromHome = YES;
    [UIView animateWithDuration:interval
                          delay:1.0 
                        options:self.animationOptions
                     animations:^{
                         self.subLabel.frame = self.awayLabelFrame;
                     }
                     completion:^(BOOL finished) {
                         if (finished) {
                             [self scrollRightWithInterval:interval];
                         }
                     }];
}

- (void)scrollRightWithInterval:(NSTimeInterval)interval {
    
    // Perform animation
    [UIView animateWithDuration:animationDuration
                          delay:0.3
                        options:self.animationOptions
                     animations:^{
                         self.subLabel.frame = self.homeLabelFrame;
                     }
                     completion:^(BOOL finished){
                         if (finished) {
                             // Set awayFromHome
                             self.awayFromHome = NO;
                             [self scrollLeftWithInterval:interval];
                         }
                     }];
}

- (void)returnLabelToOriginImmediately {
    
    if (!CGRectEqualToRect(self.subLabel.frame, self.homeLabelFrame)) {
        [UIView animateWithDuration:0
                              delay:0
                            options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState) 
                         animations:^{
                             self.subLabel.frame = self.homeLabelFrame;
                         }
                         completion:^(BOOL finished){
                             if (finished) {
                                 self.awayFromHome = NO;
                             }
                         }];
    }
}


- (void)restartLabel {
    [self returnLabelToOriginImmediately];
    
    if (self.labelShouldScroll) {
        [self scrollLeftWithInterval:self.animationDuration];
    }
}

- (void)shutdownLabel {
    [self.layer removeAllAnimations];
    
    [self returnLabelToOriginImmediately];
}

// Custom labelize mutator to restart scrolling after changing labelize to NO
- (void)setLabelize:(BOOL)labelization {

    if (labelization) {
        labelize = YES;
        if (self.subLabel) {
            [self returnLabelToOriginImmediately];
        }
    } else {
        labelize = NO;
        [self restartLabel];
    }
}

#pragma mark -
#pragma mark Modified UILabel Getters/Setters

- (void)setText:(NSString *)newText {
    
    if (![newText isEqualToString:self.labelText]) {
        
        // Set labelText to incoming newText
        self.labelText = newText;
        
        // Calculate label size
        CGSize maximumLabelSize = CGSizeMake(9999, self.frame.size.height);
        CGSize expectedLabelSize = [self.labelText sizeWithFont:self.subLabel.font
                                       constrainedToSize:maximumLabelSize
                                           lineBreakMode:self.subLabel.lineBreakMode];
        // Create home label frame
        self.homeLabelFrame = CGRectMake(self.fadeLength, 0, (expectedLabelSize.width + self.fadeLength), self.bounds.size.height);
        self.awayLabelFrame = CGRectOffset(self.homeLabelFrame, -expectedLabelSize.width + (self.bounds.size.width - self.fadeLength * 2), 0.0);
        
        if (!self.labelize) {
            // Label is not set to be static
            
            // Calculate animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval) fabs(self.awayLabelFrame.origin.x) / self.rate) : (self.lengthOfScroll);
            
            // Store current alpha
            self.baseAlpha = self.subLabel.alpha;
            
            // Fade out quickly
            [UIView animateWithDuration:0.1
                                  delay:0.0 
                                options:(UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState)
                             animations:^{
                                 self.subLabel.alpha = 0.0;
                             }
                             completion:^(BOOL finished){
                                 
                                 // Animate move immediately
                                 [self returnLabelToOriginImmediately];
                                 
                                 // Set frame and text while invisible
                                 self.subLabel.frame = self.homeLabelFrame;
                                 self.subLabel.text = self.labelText;
                                 
                                 // Fade in quickly
                                 [UIView animateWithDuration:0.1
                                                       delay:0.0
                                                     options:(UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState)
                                                  animations:^{
                                                      self.subLabel.alpha = self.baseAlpha;
                                                  }
                                                  completion:^(BOOL finished) {
                                                      if (self.labelShouldScroll) {
                                                          [self scrollLeftWithInterval:self.animationDuration];
                                                      }
                                                  }];
                             }];
            
        } else {
            // Currently labelized, act like a UILabel
            self.subLabel.frame = self.homeLabelFrame;
            self.subLabel.text = self.labelText;
            
        }
    }
}

- (NSString *)text {
    return self.labelText;
}

#pragma mark -
#pragma mark Overridden UIView properties

- (void)setBackgroundColor:(UIColor *)newColor {
    
    if (![newColor isEqual:self.subLabel.backgroundColor]) {
        
        self.subLabel.backgroundColor = newColor;
    }
    
}

- (UIColor *)backgroundColor {
    
    return self.subLabel.backgroundColor;
    
}

#pragma mark -
#pragma mark Custom Getters and Setters
- (void)setAnimationCurve:(UIViewAnimationOptions)anAnimationCurve {
    NSUInteger allowableOptions = UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionCurveLinear;
    if ((allowableOptions & animationCurve) == anAnimationCurve) {
        self.animationOptions = (anAnimationCurve | UIViewAnimationOptionAllowUserInteraction);
    }
}

- (void)setFadeLength:(CGFloat)aFadeLength {
    if (fadeLength != aFadeLength) {
        fadeLength = aFadeLength;
        [self applyGradientMask];
    }
}

- (BOOL)labelShouldScroll {
    return ((self.labelText != nil) && !CGRectContainsRect(self.bounds, self.homeLabelFrame));
}

#pragma mark -
#pragma mark UILabel Message Forwarding

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [UILabel instanceMethodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    if ([subLabel respondsToSelector:[anInvocation selector]]) {
        [anInvocation invokeWithTarget:subLabel];
    } else {
        NSLog(@"MarqueeLabel does not recognize the selector");
        [super forwardInvocation:anInvocation];
    }
}

- (id)valueForUndefinedKey:(NSString *)key {
    return [subLabel valueForKey:key];
}

- (void) setValue:(id)value forUndefinedKey:(NSString *)key {
    [subLabel setValue:value forKey:key];
}

#pragma mark -

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [labelText release];
    [subLabel release];
    [super dealloc];
}


@end
