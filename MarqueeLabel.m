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
#import <CoreText/CoreText.h>

NSString *const kMarqueeLabelAnimationName = @"MarqueeLabelAnimationName";
NSString *const kMarqueeLabelAnimationInterval = @"MarqueeLabelAnimationInterval";
NSString *const kMarqueeLabelScrollAwayAnimation = @"MarqueeLabelScrollAwayAnimation";
NSString *const kMarqueeLabelScrollHomeAnimation = @"MarqueeLabelScrollHomeAnimation";
NSString *const kMarqueeLabelViewDidAppearNotification = @"MarqueeLabelViewControllerDidAppear";
NSString *const kMarqueeLabelShouldLabelizeNotification = @"MarqueeLabelShouldLabelizeNotification";
NSString *const kMarqueeLabelShouldAnimateNotification = @"MarqueeLabelShouldAnimateNotification";

// Thanks to Phil M
// http://stackoverflow.com/questions/1340434/get-to-uiviewcontroller-from-uiview-on-iphone

@interface UIView (FindUIViewController)
- (UIViewController *) firstAvailableUIViewController;
- (id) traverseResponderChainForUIViewController;
@end

@implementation UIView (FindUIViewController)
- (id)firstAvailableUIViewController {
    // convenience function for casting and to "mask" the recursive function
    return [self traverseResponderChainForUIViewController];
}

- (id)traverseResponderChainForUIViewController {
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

// Helpers
@interface UIFont (MarqueeHelpers)
- (CTFontRef)CTFont;
+ (UIFont *)fontFromCTFont:(CTFontRef)fontRef;
@end

@interface CATextLayer (MarqueeHelpers)
- (NSAttributedString *)attributedString;
- (void)setTextAlignment:(NSTextAlignment)textAlignment;
- (void)setLineBreakMode:(NSLineBreakMode)lineBreakMode;
@end

@interface MarqueeLabel()

@property (nonatomic, strong) CATextLayer *textLayer;

@property (nonatomic, assign, readwrite) BOOL awayFromHome;
@property (nonatomic, assign) BOOL orientationWillChange;

@property (nonatomic, assign) NSUInteger animationOptions;

@property (nonatomic, assign) NSTimeInterval animationDuration;
@property (nonatomic, assign) NSTimeInterval lengthOfScroll;
@property (nonatomic, assign) CGFloat rate;
@property (nonatomic, assign, readonly) BOOL labelShouldScroll;
@property (nonatomic, weak) UITapGestureRecognizer *tapRecognizer;
@property (nonatomic, assign) CGRect homeLabelFrame;
@property (nonatomic, assign) CGRect awayLabelFrame;
@property (nonatomic, assign, readwrite) BOOL isPaused;

- (void)scrollAwayWithInterval:(NSTimeInterval)interval;
- (void)scrollHomeWithInterval:(NSTimeInterval)interval;
- (void)returnLabelToOriginImmediately;
- (void)restartLabel;
- (void)setupLabel;
- (void)observedViewControllerChange:(NSNotification *)notification;
- (void)applyGradientMaskForFadeLength:(CGFloat)fadeLength;
- (void)applyGradientMaskForFadeLength:(CGFloat)fadeLength animated:(BOOL)animated;

// Support
@property (nonatomic, strong) NSArray *gradientColors;

@end


@implementation MarqueeLabel

#pragma mark - Class Methods and handlers

+ (void)controllerViewAppearing:(UIViewController *)controller {
    if (controller) { // avoid creating NSDictionary with nil object
        [[NSNotificationCenter defaultCenter] postNotificationName:kMarqueeLabelViewDidAppearNotification object:nil userInfo:[NSDictionary dictionaryWithObject:controller forKey:@"controller"]];
    }
}

+ (void)controllerLabelsShouldLabelize:(UIViewController *)controller {
    if (controller) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kMarqueeLabelShouldLabelizeNotification object:nil userInfo:[NSDictionary dictionaryWithObject:controller forKey:@"controller"]];
    }
}

+ (void)controllerLabelsShouldAnimate:(UIViewController *)controller {
    if (controller) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kMarqueeLabelShouldAnimateNotification object:nil userInfo:[NSDictionary dictionaryWithObject:controller forKey:@"controller"]];
    }
}

- (void)viewControllerDidAppear:(NSNotification *)notification {
    UIViewController *controller = [[notification userInfo] objectForKey:@"controller"];
    if (controller == [self firstAvailableUIViewController]) {
        [self restartLabel];
    }
}

- (void)labelsShouldLabelize:(NSNotification *)notification {
    UIViewController *controller = [[notification userInfo] objectForKey:@"controller"];
    if (controller == [self firstAvailableUIViewController]) {
        self.labelize = YES;
    }
}

- (void)labelsShouldAnimate:(NSNotification *)notification {
    UIViewController *controller = [[notification userInfo] objectForKey:@"controller"];
    if (controller == [self firstAvailableUIViewController]) {
        self.labelize = NO;
    }
}

#pragma mark - Initialization and Label Config

- (id)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame duration:7.0 andFadeLength:0.0];
}

- (id)initWithFrame:(CGRect)frame duration:(NSTimeInterval)aLengthOfScroll andFadeLength:(CGFloat)aFadeLength {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLabel];
        
        self.lengthOfScroll = aLengthOfScroll;
        self.fadeLength = MIN(aFadeLength, frame.size.width/2);
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame rate:(CGFloat)pixelsPerSec andFadeLength:(CGFloat)aFadeLength {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLabel];
        
        self.rate = pixelsPerSec;
        self.fadeLength = MIN(aFadeLength, frame.size.width/2);
    }
    return self;
}

- (void)setupLabel {
    
    // Basic UILabel options override
    self.clipsToBounds = YES;
    self.numberOfLines = 1;
    
    self.textLayer = [CATextLayer layer];
    self.textLayer.actions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                              [NSNull null], @"position",
                              [NSNull null], @"bounds",
                              nil];
    self.textLayer.anchorPoint = CGPointMake(0.0f, 0.0f);
    //self.textLayer.backgroundColor = [UIColor yellowColor].CGColor;
    self.textLayer.rasterizationScale = [[UIScreen mainScreen] scale];
    self.textLayer.contentsScale = [[UIScreen mainScreen] scale];
    self.textLayer.font = [[super font] CTFont];
    self.textLayer.fontSize = [[super font] pointSize];
    self.textLayer.foregroundColor = [super textColor].CGColor;
    
    self.textLayer.string = [super text];
    
    [self.layer addSublayer:self.textLayer];
    
    _animationOptions = (UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction);
    _awayFromHome = NO;
    _orientationWillChange = NO;
    _labelize = NO;
    _tapToScroll = NO;
    _isPaused = NO;
    //EXTRA: self.labelText = @"";  // Set to zero-length string to start, so that self.text returns a non-nil string (allows appending, etc)
    _animationDelay = 1.0;
    _animationDuration = 0.0f; // initialize animation duration
    
    // Add notification observers
    // Custom class notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewControllerDidAppear:) name:kMarqueeLabelViewDidAppearNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(labelsShouldLabelize:) name:kMarqueeLabelShouldLabelizeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(labelsShouldAnimate:) name:kMarqueeLabelShouldAnimateNotification object:nil];
    
    // UINavigationController view controller change notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observedViewControllerChange:) name:@"UINavigationControllerDidShowViewControllerNotification" object:nil];
    
    // UIApplication state notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(restartLabel) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(restartLabel) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shutdownLabel) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shutdownLabel) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    // Device Orientation change handling
    /* Necessary to prevent a "super-speed" scroll bug. When the frame is changed due to a flexible width autoresizing mask,
     * the setFrame call occurs during the in-flight orientation rotation animation, and the scroll to the away location
     * occurs at super speed. To work around this, the orientationWilLChange property is set to YES when the notification
     * UIApplicationWillChangeStatusBarOrientationNotification is posted, and a notification handler block listening for
     * the UIViewAnimationDidStopNotification notification is added. The handler block checks the notification userInfo to
     * see if the delegate of the ending animation is the UIWindow of the label. If so, the rotation animation has finished
     * and the label can be restarted, and the notification observer removed.
     */
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillChangeStatusBarOrientationNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *notification){
                                                      self.orientationWillChange = YES;
                                                      [[NSNotificationCenter defaultCenter] addObserverForName:@"UIViewAnimationDidStopNotification"
                                                                                                        object:nil
                                                                                                         queue:nil
                                                                                                    usingBlock:^(NSNotification *notification){
                                                                                                        if ([notification.userInfo objectForKey:@"delegate"] == self.window) {
                                                                                                            self.orientationWillChange = NO;
                                                                                                            [self restartLabel];
                                                                                                            
                                                                                                            // Remove notification observer
                                                                                                            [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIViewAnimationDidStopNotification" object:nil];
                                                                                                        }
                                                                                                    }];
                                                  }];
}

- (void)observedViewControllerChange:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    id fromController = [userInfo objectForKey:@"UINavigationControllerLastVisibleViewController"];
    id toController = [userInfo objectForKey:@"UINavigationControllerNextVisibleViewController"];
    
    id ownController = [self firstAvailableUIViewController];
    if ([fromController isEqual:ownController]) {
        [self shutdownLabel];
    }
    else if ([toController isEqual:ownController]) {
        [self restartLabel];
    }
}

- (void)minimizeLabelFrameWithMaximumSize:(CGSize)maxSize adjustHeight:(BOOL)adjustHeight {
    if (self.textLayer.string != nil) {
        // Calculate text size
        if (CGSizeEqualToSize(maxSize, CGSizeZero)) {
            maxSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
        }
        CGSize minimizedLabelSize = [(NSString *)self.textLayer.string sizeWithFont:[UIFont fontFromCTFont:self.textLayer.font]
                                                                  constrainedToSize:maxSize
                                                                      lineBreakMode:self.lineBreakMode];
        // Adjust for fade length
        minimizedLabelSize = CGSizeMake(minimizedLabelSize.width + (self.fadeLength * 2), minimizedLabelSize.height);
        
        // Apply to frame
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, minimizedLabelSize.width, (adjustHeight ? minimizedLabelSize.height : self.frame.size.height));
    }
}

#pragma mark - MarqueeLabel Heavy Lifting

- (void)updateSublabelAndLocations {
    [self updateSublabelAndLocationsAndBeginScroll:YES];
}

- (void)updateSublabelAndLocationsAndBeginScroll:(BOOL)beginScroll {
    if ([(NSString *)self.textLayer.string length] == 0) {
        return;
    }
    
    // Calculate expected size
    CGSize maximumLabelSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
    UIFont *labelFont = [UIFont fontFromCTFont:self.textLayer.font];
    CGSize expectedLabelSize = [(NSString *)self.textLayer.string sizeWithFont:labelFont
                                                             constrainedToSize:maximumLabelSize
                                                                 lineBreakMode:NSLineBreakByWordWrapping];
    
    //CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFMutableAttributedStringRef)[self.textLayer attributedString]);
    //expectedLabelSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), NULL, maximumLabelSize, NULL);
    //CFRelease(framesetter);
    
    // Calculate positioning offset
    CGFloat labelTextOffsetY = 0.0f;
    // Check for iOS 6 positioning
    if(([[[UIDevice currentDevice] systemVersion] compare:@"6" options:NSNumericSearch] == NSOrderedDescending)){
        labelTextOffsetY += ceilf(-(labelFont.capHeight - labelFont.xHeight));
    }
    // Vertical adjustment
    CGFloat labelVerticalAdjustment = (self.bounds.size.height/2) - (labelFont.ascender/2); //((self.bounds.size.height - (expectedLabelSize.height + labelFont.descender))/2);
    labelTextOffsetY += labelVerticalAdjustment;
    
    // Move to origin
    [self returnLabelToOriginImmediately];
    
    // Check if label should act like a label
    
    if (self.labelize) {
        // Currently labelized
        // Act like a UILabel
        [self returnLabelToOriginImmediately];
        
        // Set text alignment and break mode to act like normal label
        //EXTRA: self.subLabel.text = self.labelText;
        [self.textLayer setTextAlignment:[super textAlignment]];
        [self.textLayer setLineBreakMode:[super lineBreakMode]];
        
        // Create frames
        self.homeLabelFrame = CGRectMake(self.fadeLength, labelTextOffsetY, expectedLabelSize.width, expectedLabelSize.height);
        self.awayLabelFrame = CGRectNull;
        self.textLayer.frame = self.homeLabelFrame;
        
        return;
    }
    
    // Label is not set to be static
    
    if (!self.labelShouldScroll) {
        //EXTRA: CGRect labelFrame = CGRectInset(self.bounds, self.fadeLength, 0.0f);
        //EXTRA: CGRect labelFrame = CGRectOffset(CGRectInset(self.bounds, self.fadeLength, 0.0f), 0.0f, labelTextOffsetY);
        CGRect labelFrame = CGRectMake(self.fadeLength, labelTextOffsetY, self.bounds.size.width - self.fadeLength * 2, expectedLabelSize.height);
        self.homeLabelFrame = labelFrame;
        self.awayLabelFrame = labelFrame;
        
        self.textLayer.frame = self.homeLabelFrame;
        //EXTRA: self.textLayer.string = self.labelText;
        
        return;
    }
    
    // Set text alignment and break mode to act like MarqueeLabel
    [self.textLayer setTextAlignment:NSTextAlignmentCenter];
    [self.textLayer setLineBreakMode:NSLineBreakByClipping];
    
    switch (self.marqueeType) {
            
        /*
        case MLContinuous:
        {
            // Needed for determining if the label should scroll (will be changed)
            self.homeLabelFrame = CGRectMake(self.fadeLength, 0, expectedLabelSize.width, self.bounds.size.height);
            
            // Double the label text and insert the separator.
            NSString *doubledText = [self.labelText stringByAppendingFormat:@"%@%@", self.continuousMarqueeSeparator, self.labelText];
         
            // Make maximum size
            CGSize maximumLabelSize = CGSizeMake(CGFLOAT_MAX, self.frame.size.height);
            
            // Size of the new doubled label
            CGSize expectedLabelSizeDoubled = [doubledText sizeWithFont:self.subLabel.font
                                                      constrainedToSize:maximumLabelSize
                                                          lineBreakMode:self.subLabel.lineBreakMode];
            
            CGRect continuousLabelFrame = CGRectMake(self.fadeLength, 0, expectedLabelSizeDoubled.width, self.bounds.size.height);
            
            // Size of the label and the separator. This is the period of the translation to the left.
            CGSize labelAndSeparatorSize = [[self.labelText stringByAppendingString:self.continuousMarqueeSeparator] sizeWithFont:self.subLabel.font
                                                                                                                constrainedToSize:maximumLabelSize
                                                                                                                    lineBreakMode:self.subLabel.lineBreakMode];
            self.homeLabelFrame = continuousLabelFrame;
            self.awayLabelFrame = CGRectOffset(continuousLabelFrame, -labelAndSeparatorSize.width, 0.0);
            
            // Recompute the animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval) fabs(self.awayLabelFrame.origin.x) / self.rate) : (self.lengthOfScroll);
            
            self.subLabel.frame = self.homeLabelFrame;
            self.subLabel.text = doubledText;
            self.subLabel.textAlignment = UITextAlignmentLeft;
            
            break;
        }
        */
            
        case MLRightLeft:
        {
            self.homeLabelFrame = CGRectMake(self.bounds.size.width - (expectedLabelSize.width + self.fadeLength), labelTextOffsetY, expectedLabelSize.width, self.bounds.size.height);
            self.awayLabelFrame = CGRectMake(self.fadeLength, labelTextOffsetY, expectedLabelSize.width, self.bounds.size.height);
            
            // Calculate animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval)fabs(self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x) / self.rate) : (self.lengthOfScroll);
            
            // Set frame and text
            self.textLayer.frame = self.homeLabelFrame;
            //EXTRA: self.subLabel.text = self.labelText;
            
            // Enforce text alignment for this type
            //EXTRA: self.subLabel.textAlignment = UITextAlignmentRight;
            
            break;
        }
        default: //Fallback to LeftRight marqueeType
        {
            self.homeLabelFrame = CGRectMake(self.fadeLength, labelTextOffsetY, expectedLabelSize.width, expectedLabelSize.height);
            self.awayLabelFrame = CGRectOffset(self.homeLabelFrame, -expectedLabelSize.width + (self.bounds.size.width - self.fadeLength * 2), 0.0);
            
            // Calculate animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval)fabs(self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x) / self.rate) : (self.lengthOfScroll);
            
            // Set frame
            self.textLayer.frame = self.homeLabelFrame;
            //EXTRA: self.textLayer.text = self.labelText;
            
            // Enforce text alignment for this type
            //EXTRA: self.subLabel.textAlignment = UITextAlignmentLeft;
        }
            
    } //end of marqueeType switch
    
    if (!self.tapToScroll && beginScroll) {
        [self beginScroll];
    }
    
}

- (void)applyGradientMaskForFadeLength:(CGFloat)fadeLength {
    [self applyGradientMaskForFadeLength:fadeLength animated:YES];
}

- (void)applyGradientMaskForFadeLength:(CGFloat)fadeLength animated:(BOOL)animated {
    
    if (animated) {
        [self returnLabelToOriginImmediately];
    }
    
    if (fadeLength != 0.0f) {
        // Recreate gradient mask with new fade length
        CAGradientLayer *gradientMask = [CAGradientLayer layer];
        
        gradientMask.bounds = self.layer.bounds;
        gradientMask.position = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
        
        gradientMask.shouldRasterize = YES;
        gradientMask.rasterizationScale = [UIScreen mainScreen].scale;
        
        gradientMask.startPoint = CGPointMake(0.0, CGRectGetMidY(self.frame));
        gradientMask.endPoint = CGPointMake(1.0, CGRectGetMidY(self.frame));
        CGFloat fadePoint = (CGFloat)self.fadeLength/self.frame.size.width;
        [gradientMask setColors:self.gradientColors];
        [gradientMask setLocations: [NSArray arrayWithObjects:
                                     [NSNumber numberWithDouble: 0.0],
                                     [NSNumber numberWithDouble: fadePoint],
                                     [NSNumber numberWithDouble: 1 - fadePoint],
                                     [NSNumber numberWithDouble: 1.0],
                                     nil]];
        self.layer.mask = gradientMask;
    } else {
        // Remove gradient mask for 0.0f lenth fade length
        self.layer.mask = nil;
    }
    
    if (animated && self.labelShouldScroll && !self.tapToScroll) {
        [self beginScroll];
    }
}

- (CGSize)subLabelSize {
    // Calculate label size
    CGSize maximumLabelSize = CGSizeMake(CGFLOAT_MAX, self.frame.size.height);
    UIFont *font = [UIFont fontFromCTFont:self.textLayer.font];
    CGSize expectedLabelSize = [(NSString *)self.textLayer.string sizeWithFont:font
                                                             constrainedToSize:maximumLabelSize
                                                                 lineBreakMode:NSLineBreakByClipping];
    return expectedLabelSize;
}

#pragma mark - Animation Handlers

- (BOOL)labelShouldScroll {
    BOOL stringLength = ([(NSString *)self.textLayer.string length] > 0);
    if (!stringLength) {
        return NO;
    }
    
    BOOL labelWidth = (self.bounds.size.width < [self subLabelSize].width + self.fadeLength); //EXTRA: (self.marqueeType == MLContinuous ? 2 * self.fadeLength : self.fadeLength)));
    return (!self.labelize && labelWidth);
}

- (NSTimeInterval)durationForInterval:(NSTimeInterval)interval {
    switch (self.marqueeType) {
        /*
        EXTRA:
        case MLContinuous:
            return (interval * 2.0);
            break;
        */
        default:
            return interval;
            break;
    }
}

- (void)beginScroll {
    [self beginScrollWithDelay:YES];
}

- (void)beginScrollWithDelay:(BOOL)delay {
    switch (self.marqueeType) {
        /*
        //EXTRA:
        case MLContinuous:
            [self scrollLeftPerpetualWithInterval:[self durationForInterval:self.animationDuration] after:(delay ? self.animationDelay : 0.0)];
            break;
        */
        default:
            [self scrollAwayWithInterval:[self durationForInterval:self.animationDuration]];
            break;
    }
}

- (void)scrollAwayWithInterval:(NSTimeInterval)interval {
    [self scrollAwayWithInterval:interval delay:YES];
}

- (void)scrollAwayWithInterval:(NSTimeInterval)interval delay:(BOOL)delay {
    [self scrollAwayWithInterval:interval delayAmount:(delay ? self.animationDelay : 0.0)];
}

- (void)scrollAwayWithInterval:(NSTimeInterval)interval delayAmount:(NSTimeInterval)delayAmount {
    if (![self superview]) {
        return;
    }
    
    // Perform animation
    self.awayFromHome = YES;
    
    if (self.textLayer.animationKeys.count > 0) {
        [self.textLayer removeAllAnimations];
    }
    
    UIViewController *viewController = [self firstAvailableUIViewController];
    if (!(viewController.isViewLoaded && viewController.view.window)) {
        return;
    }
    
    [CATransaction begin];
    
    [CATransaction setCompletionBlock:^{
        self.textLayer.position = self.awayLabelFrame.origin;
        [self scrollHomeWithInterval:interval delayAmount:delayAmount];
    }];
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    animation.fromValue = [self.textLayer valueForKey:@"position"];
    animation.toValue = [NSValue valueWithCGPoint:self.awayLabelFrame.origin];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.duration = interval;
    animation.beginTime = CACurrentMediaTime() + delayAmount;
    animation.removedOnCompletion = NO;
    animation.fillMode = kCAFillModeForwards;
    animation.delegate = self;
    
    [animation setValue:kMarqueeLabelScrollAwayAnimation forKey:kMarqueeLabelAnimationName];
    [animation setValue:[NSNumber numberWithDouble:interval] forKey:kMarqueeLabelAnimationInterval];
    
    [self.textLayer addAnimation:animation forKey:kMarqueeLabelScrollAwayAnimation];
    
    [CATransaction commit];
    /*
    [UIView animateWithDuration:interval
                          delay:(delay ? self.animationDelay : 0.0)
                        options:self.animationOptions
                     animations:^{
                         self.subLabel.frame = self.awayLabelFrame;
                     }
                     completion:^(BOOL finished) {
                         if (finished) {
                             [self scrollHomeWithInterval:interval];
                         }
                     }];
    */
}

- (void)scrollHomeWithInterval:(NSTimeInterval)interval {
    [self scrollHomeWithInterval:interval delay:YES];
}

- (void)scrollHomeWithInterval:(NSTimeInterval)interval delay:(BOOL)delay {
    [self scrollHomeWithInterval:interval delayAmount:(delay ? self.animationDelay : 0.0)];
}

- (void)scrollHomeWithInterval:(NSTimeInterval)interval delayAmount:(NSTimeInterval)delayAmount {
    if (![self superview]) {
        return;
    }
    
    // Perform animation
    [CATransaction begin];
    
    [CATransaction setCompletionBlock:^{
        if (!self.tapToScroll) {
            [self scrollAwayWithInterval:interval delayAmount:delayAmount];
            self.awayFromHome = NO;
        }
    }];
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    animation.fromValue = [self.textLayer valueForKey:@"position"];
    animation.toValue = [NSValue valueWithCGPoint:self.homeLabelFrame.origin];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.duration = interval;
    animation.beginTime = CACurrentMediaTime() + delayAmount;
    animation.delegate = self;
    
    self.textLayer.position = self.homeLabelFrame.origin;
    
    [animation setValue:kMarqueeLabelScrollHomeAnimation forKey:kMarqueeLabelAnimationName];
    [animation setValue:[NSNumber numberWithDouble:interval] forKey:kMarqueeLabelAnimationInterval];
    
    [self.textLayer addAnimation:animation forKey:kMarqueeLabelScrollHomeAnimation];
    
    [CATransaction commit];
    
    /* //EXTRA
    [UIView animateWithDuration:interval
                          delay:(delay ? self.animationDelay : 0.0)
                        options:self.animationOptions
                     animations:^{
                         self.subLabel.frame = self.homeLabelFrame;
                     }
                     completion:^(BOOL finished){
                         if (finished) {
                             // Set awayFromHome
                             self.awayFromHome = NO;
                             if (!self.tapToScroll) {
                                 [self scrollAwayWithInterval:interval];
                             }
                         }
                     }];
    */
}

/*
 //EXTRA:
- (void)scrollLeftPerpetualWithInterval:(NSTimeInterval)interval after:(NSTimeInterval)delay{
    
    // Reset label home
    [self returnLabelToOriginImmediately];
    
    // Animate
    [UIView animateWithDuration:interval
                          delay:delay 
                        options:self.animationOptions
                     animations:^{
                         self.subLabel.frame = self.awayLabelFrame;
                     }
                     completion:^(BOOL finished) {
                         if (finished && !self.tapToScroll) {
                             [self scrollLeftPerpetualWithInterval:interval after:delay];
                         }
                     }];
}
*/

- (void)returnLabelToOriginImmediately {
    [self.textLayer removeAllAnimations];
    self.textLayer.frame = self.homeLabelFrame;
    // EXTRA: (self.textLayer.frame, self.homeLabelFrame) || CGRectEqualToRect(self.homeLabelFrame, CGRectNull) || CGRectEqualToRect(self.homeLabelFrame, CGRectZero)) {
    if (self.textLayer.position.x == self.homeLabelFrame.origin.x) {
        self.awayFromHome = NO;
    } else {
        [self returnLabelToOriginImmediately];
    }
}

/*
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    NSString *animationName = [anim valueForKey:kMarqueeLabelAnimationName];
    
    if ([animationName isEqualToString:kMarqueeLabelScrollAwayAnimation]) {
        // Scroll away animation has finished
        // Scroll back home
        NSTimeInterval interval = [[anim valueForKey:kMarqueeLabelAnimationInterval] doubleValue];
        [self scrollHomeWithInterval:interval];
    }
    
    if ([animationName isEqualToString:kMarqueeLabelScrollHomeAnimation]) {
        // Scroll home animation has finished
        // Scroll away if needed
        NSTimeInterval interval = [[anim valueForKey:kMarqueeLabelAnimationInterval] doubleValue];
        // Set awayFromHome
        if (!self.tapToScroll) {
            [self scrollAwayWithInterval:interval];
            self.awayFromHome = NO;
        }
    }
}
 */

#pragma mark - Label Control

- (void)restartLabel {
    [self returnLabelToOriginImmediately];
    
    if (self.labelShouldScroll && !self.tapToScroll) {
        [self beginScroll];
    }
}


- (void)resetLabel {
    [self returnLabelToOriginImmediately];
    self.homeLabelFrame = CGRectNull;
    self.awayLabelFrame = CGRectNull;
}

- (void)shutdownLabel {
    [self returnLabelToOriginImmediately];
}

-(void)pauseLabel
{
    if (!self.isPaused) {
        CFTimeInterval pausedTime = [self.layer convertTime:CACurrentMediaTime() fromLayer:nil];
        self.layer.speed = 0.0;
        self.layer.timeOffset = pausedTime;
        self.isPaused = YES;
    }
}

-(void)unpauseLabel
{
    if (self.isPaused) {
        CFTimeInterval pausedTime = [self.layer timeOffset];
        self.layer.speed = 1.0;
        self.layer.timeOffset = 0.0;
        self.layer.beginTime = 0.0;
        CFTimeInterval timeSincePause = [self.layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
        self.layer.beginTime = timeSincePause;
        self.isPaused = NO;
    }
}

- (void)labelWasTapped:(UITapGestureRecognizer *)recognizer {
    if (self.labelShouldScroll) {
        [self beginScrollWithDelay:NO];
    }
}

#pragma mark - Modified UILabel Getters/Setters

- (NSString *)text {
    return (NSString *)self.textLayer.string;
}

- (void)setText:(NSString *)text {
    if ([text isEqualToString:(NSString *)self.textLayer.string]) {
        return;
    }
    
    self.textLayer.string = text;
    
    [self updateSublabelAndLocations];
}

- (UIFont *)font {
    return [UIFont fontFromCTFont:self.textLayer.font];
}

- (void)setFont:(UIFont *)font {
    if ([font isEqual:[UIFont fontFromCTFont:self.textLayer.font]]) {
        return;
    }
    
    CTFontRef fontRef = [font CTFont];
    self.textLayer.font = fontRef;
    self.textLayer.fontSize = font.pointSize;
    CFRelease(fontRef);
    
    [self updateSublabelAndLocations];
}

- (UIColor *)textColor {
    return [UIColor colorWithCGColor:self.textLayer.foregroundColor];
}

- (void)setTextColor:(UIColor *)textColor {
    if (CGColorEqualToColor(textColor.CGColor, self.textLayer.foregroundColor)) {
        return;
    }
    
    self.textLayer.foregroundColor = textColor.CGColor;

    [self setNeedsDisplay];
}

- (UIColor *)shadowColor {
    return [UIColor colorWithCGColor:self.textLayer.shadowColor];
}

- (void)setShadowColor:(UIColor *)shadowColor {
    if (CGColorEqualToColor(shadowColor.CGColor, self.textLayer.shadowColor)) {
        return;
    }
    
    self.textLayer.shadowColor = shadowColor.CGColor;
    
    [self setNeedsDisplay];
}

- (void)setFrame:(CGRect)frame {
    
    [super setFrame:frame];
    
    [self applyGradientMaskForFadeLength:self.fadeLength animated:!self.orientationWillChange];
    [self updateSublabelAndLocationsAndBeginScroll:!self.orientationWillChange];
}

#pragma Override UILabel Getters and Setters

- (void)setNumberOfLines:(NSInteger)numberOfLines {
    // By the nature of MarqueeLabel, this is 1
    [super setNumberOfLines:1];
}

- (void)setAdjustsFontSizeToFitWidth:(BOOL)adjustsFontSizeToFitWidth {
    // By the nature of MarqueeLabel, this is NO
    [super setAdjustsFontSizeToFitWidth:NO];
}

- (void)setAdjustsLetterSpacingToFitWidth:(BOOL)adjustsLetterSpacingToFitWidth {
    // By the nature of MarqueeLabel, this is NO
    [super setAdjustsLetterSpacingToFitWidth:NO];
}

- (void)setMinimumFontSize:(CGFloat)minimumFontSize {
    [super setMinimumFontSize:0.0];
}

- (void)setMinimumScaleFactor:(CGFloat)minimumScaleFactor {
    [super setMinimumScaleFactor:0.0f];
}

#pragma mark - Custom Getters and Setters

- (void)setAnimationCurve:(UIViewAnimationOptions)anAnimationCurve {
    NSUInteger allowableOptions = UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionCurveLinear;
    if ((allowableOptions & anAnimationCurve) == anAnimationCurve) {
        self.animationOptions = (anAnimationCurve | UIViewAnimationOptionAllowUserInteraction);
    }
}

- (void)setFadeLength:(CGFloat)fadeLength {
    if (_fadeLength != fadeLength) {
        _fadeLength = fadeLength;
        [self applyGradientMaskForFadeLength:_fadeLength];
        [self updateSublabelAndLocations];
    }
}

- (void)setTapToScroll:(BOOL)tapToScroll {
    if (_tapToScroll == tapToScroll) {
        return;
    }
    
    _tapToScroll = tapToScroll;
    
    if (_tapToScroll) {
        UITapGestureRecognizer *newTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(labelWasTapped:)];
        [self addGestureRecognizer:newTapRecognizer];
        self.tapRecognizer = newTapRecognizer;
    } else {
        [self removeGestureRecognizer:self.tapRecognizer];
        self.tapRecognizer = nil;
    }
}

- (void)setMarqueeType:(MarqueeType)marqueeType {
    if (marqueeType == _marqueeType) {
        return;
    }
    
    _marqueeType = marqueeType;
    
    /*
    //EXTRA:
    if (_marqueeType == MLContinuous) {
        self.textAlignment = UITextAlignmentCenter;
    }
    */
}

- (CGRect)awayLabelFrame {
    if (CGRectEqualToRect(_awayLabelFrame, CGRectNull)) {
        // Calculate label size
        CGSize expectedLabelSize = [self subLabelSize];
        // Create home label frame
        _awayLabelFrame = CGRectOffset(self.homeLabelFrame, -expectedLabelSize.width + (self.bounds.size.width - self.fadeLength * 2), 0.0);
    }
    
    return _awayLabelFrame;
}

- (CGRect)homeLabelFrame {
    if (CGRectEqualToRect(_homeLabelFrame, CGRectNull)) {
        // Calculate label size
        CGSize expectedLabelSize = [self subLabelSize];
        // Create home label frame
        _homeLabelFrame = CGRectMake(self.fadeLength, 0, (expectedLabelSize.width + self.fadeLength), self.bounds.size.height);
    }
    
    return _homeLabelFrame;
}

- (NSString *)continuousMarqueeSeparator {
    if (_continuousMarqueeSeparator == nil) {
        _continuousMarqueeSeparator = @"       ";
    }
    
    return _continuousMarqueeSeparator;
}

// Custom labelize mutator to restart scrolling after changing labelize to NO
- (void)setLabelize:(BOOL)labelize {
    
    if (labelize) {
        _labelize = YES;
        if (self.textLayer != nil) {
            [self returnLabelToOriginImmediately];
        }
    } else {
        _labelize = NO;
        [self updateSublabelAndLocationsAndBeginScroll:YES];
    }
}

#pragma mark - Support

- (NSArray *)gradientColors {
    if (!_gradientColors) {
        NSObject *transparent = (NSObject *)[[UIColor clearColor] CGColor];
        NSObject *opaque = (NSObject *)[[UIColor blackColor] CGColor];
        _gradientColors = [NSArray arrayWithObjects: transparent, opaque, opaque, transparent, nil];
    }
    return _gradientColors;
}

#pragma mark -

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end


@implementation UIFont (MarqueeHelpers)

- (CTFontRef)CTFont {
    CTFontRef fontRef = CTFontCreateWithName((__bridge CFStringRef)(self.fontName), self.pointSize, NULL);
    return fontRef;
}

+ (UIFont *)fontFromCTFont:(CTFontRef)fontRef {
    NSString *fontName = (NSString *)CFBridgingRelease(CTFontCopyName(fontRef, kCTFontPostScriptNameKey));
    CGFloat fontSize = CTFontGetSize(fontRef);
    return [UIFont fontWithName:fontName size:fontSize];
}

@end

@implementation CATextLayer (MarqueeHelpers)

- (NSAttributedString *)attributedString {
    
    // If string is an attributed string
    if ([self.string isKindOfClass:[NSAttributedString class]]) {
        return self.string;
    }
    
    // Collect required parameters, and construct an attributed string
    NSString *string = self.string;
    CGColorRef color = self.foregroundColor;
    CTFontRef theFont = self.font;
    CTTextAlignment alignment;
    
    if ([self.alignmentMode isEqualToString:kCAAlignmentLeft]) {
        alignment = kCTLeftTextAlignment;
        
    } else if ([self.alignmentMode isEqualToString:kCAAlignmentRight]) {
        alignment = kCTRightTextAlignment;
        
    } else if ([self.alignmentMode isEqualToString:kCAAlignmentCenter]) {
        alignment = kCTCenterTextAlignment;
        
    } else if ([self.alignmentMode isEqualToString:kCAAlignmentJustified]) {
        alignment = kCTJustifiedTextAlignment;
        
    } else if ([self.alignmentMode isEqualToString:kCAAlignmentNatural]) {
        alignment = kCTNaturalTextAlignment;
    }
    
    // Process the information to get an attributed string
    CFMutableAttributedStringRef attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    
    if (string != nil)
        CFAttributedStringReplaceString (attrString, CFRangeMake(0, 0), (CFStringRef)string);
    
    CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFAttributedStringGetLength(attrString)), kCTForegroundColorAttributeName, color);
    CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFAttributedStringGetLength(attrString)), kCTFontAttributeName, theFont);
    
    CTParagraphStyleSetting settings[] = {kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment};
    CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(settings, sizeof(settings) / sizeof(settings[0]));
    CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFAttributedStringGetLength(attrString)), kCTParagraphStyleAttributeName, paragraphStyle);
    CFRelease(paragraphStyle);
    
    NSMutableAttributedString *ret = (__bridge NSMutableAttributedString *)attrString;
    
    return ret;
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment {
    switch (textAlignment) {
        case NSTextAlignmentLeft:
            self.alignmentMode = kCAAlignmentLeft;
            break;
        case NSTextAlignmentRight:
            self.alignmentMode = kCAAlignmentRight;
            break;
        case NSTextAlignmentCenter:
            self.alignmentMode = kCAAlignmentCenter;
            break;
        default:
            self.alignmentMode = kCAAlignmentNatural;
            break;
    }
    
    [self setNeedsDisplay];
}

- (void)setLineBreakMode:(NSLineBreakMode)lineBreakMode {
    switch (lineBreakMode) {
        case NSLineBreakByWordWrapping:
            self.wrapped = YES;
            break;
        case NSLineBreakByClipping:
            self.wrapped = NO;
            break;
        case NSLineBreakByTruncatingHead:
            self.truncationMode = kCATruncationStart;
            break;
        case NSLineBreakByTruncatingTail:
            self.truncationMode = kCATruncationEnd;
            break;
        case NSLineBreakByTruncatingMiddle:
            self.truncationMode = kCATruncationMiddle;
            break;
        default:
            break;
    }
    
    [self setNeedsDisplay];
}

@end
