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
NSString *const kMarqueeLabelAnimationCompletionBlock = @"MarqueeLabelAnimationCompletionBlocK";
NSString *const kMarqueeLabelScrollAwayAnimation = @"MarqueeLabelScrollAwayAnimation";
NSString *const kMarqueeLabelScrollHomeAnimation = @"MarqueeLabelScrollHomeAnimation";
NSString *const kMarqueeLabelViewDidAppearNotification = @"MarqueeLabelViewControllerDidAppear";
NSString *const kMarqueeLabelShouldLabelizeNotification = @"MarqueeLabelShouldLabelizeNotification";
NSString *const kMarqueeLabelShouldAnimateNotification = @"MarqueeLabelShouldAnimateNotification";

typedef void (^animationCompletionBlock)(void);

@interface UIView (MarqueeLabelHelpers)
- (UIViewController *) firstAvailableUIViewController;
- (id) traverseResponderChainForUIViewController;
@end

// Helpers
@interface UIFont (MarqueeLabelHelpers)
- (CTFontRef)CTFont;
+ (UIFont *)fontFromCTFont:(CTFontRef)fontRef;
@end

@interface MLTextLayer : CATextLayer
- (void)setTextAlignment:(NSTextAlignment)textAlignment;
- (void)setLineBreakMode:(NSLineBreakMode)lineBreakMode;
@end

@interface MLBasicAnimation : CABasicAnimation
@end

@interface MarqueeLabel()

@property (nonatomic, strong) MLTextLayer *textLayer;

@property (nonatomic, assign, readwrite) BOOL awayFromHome;
@property (nonatomic, assign) BOOL orientationWillChange;
@property (nonatomic, strong) id orientationObserver;

@property (nonatomic, strong) NSString *mediaTimingFunction;
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
        [[NSNotificationCenter defaultCenter] postNotificationName:kMarqueeLabelViewDidAppearNotification
                                                            object:nil
                                                          userInfo:[NSDictionary dictionaryWithObjectsAndKeys:controller, @"controller", nil]];
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
        
        _lengthOfScroll = aLengthOfScroll;
        self.fadeLength = MIN(aFadeLength, frame.size.width/2);
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame rate:(CGFloat)pixelsPerSec andFadeLength:(CGFloat)aFadeLength {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLabel];
        
        _rate = pixelsPerSec;
        self.fadeLength = MIN(aFadeLength, frame.size.width/2);
    }
    return self;
}

- (void)setupLabel {
    
    // Basic UILabel options override
    self.clipsToBounds = YES;
    self.numberOfLines = 1;
    
    self.textLayer = [MLTextLayer layer];
    self.textLayer.name = @"textLayer";
    self.textLayer.font = [[super font] CTFont];
    self.textLayer.fontSize = [[super font] pointSize];
    self.textLayer.foregroundColor = [super textColor].CGColor;
    
    self.textLayer.string = [super text];
    
    [self.layer addSublayer:self.textLayer];
    
    _animationCurve = UIViewAnimationOptionCurveEaseInOut;
    _mediaTimingFunction = kCAMediaTimingFunctionEaseInEaseOut;
    _awayFromHome = NO;
    _orientationWillChange = NO;
    _labelize = NO;
    _tapToScroll = NO;
    _isPaused = NO;
    _animationDelay = 1.0;
    _animationDuration = 0.0f;
    _continuousMarqueeExtraBuffer = 0.0f;
    
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
    
    __weak __typeof(&*self)weakSelf = self;
    
    __block id animationObserver = nil;
    self.orientationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillChangeStatusBarOrientationNotification
                                                                                 object:nil
                                                                                  queue:nil
                                                                             usingBlock:^(NSNotification *notification){
                                                                                 weakSelf.orientationWillChange = YES;
                                                                                 animationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"UIViewAnimationDidStopNotification"
                                                                                                                                                       object:nil
                                                                                                                                                        queue:nil
                                                                                                                                                   usingBlock:^(NSNotification *notification){
                                                                                                                                                       if ([notification.userInfo objectForKey:@"delegate"] == self.window) {
                                                                                                                                                           weakSelf.orientationWillChange = NO;
                                                                                                                                                           [weakSelf restartLabel];
                                                                                                                                                           
                                                                                                                                                           // Remove notification observer
                                                                                                                                                           [[NSNotificationCenter defaultCenter] removeObserver:animationObserver];
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
    
    // Calculate vertical positioning offset
    // Note: 1.0f adjustment determined empirically, but seems to work for a wide range of possible label heights
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat labelTextOffsetY = ceilf(self.bounds.size.height/2) - ceilf((labelFont.ascender - labelFont.capHeight/2) * scale)/scale - 1.0f;
    
    CGSize expectedLabelSize = [(NSString *)self.textLayer.string sizeWithFont:labelFont
                                                             constrainedToSize:maximumLabelSize
                                                                 lineBreakMode:NSLineBreakByTruncatingTail];
    
    expectedLabelSize.height = self.bounds.size.height + fabs(labelTextOffsetY);
    
    // Move to origin
    [self returnLabelToOriginImmediately];
    
    // Check if label is labelized, or does not need to scroll
    if (self.labelize || !self.labelShouldScroll) {
        // Set text alignment and break mode to act like normal label
        [self.textLayer setTextAlignment:[super textAlignment]];
        [self.textLayer setLineBreakMode:[super lineBreakMode]];
        
        CGRect labelFrame = CGRectMake(self.fadeLength, labelTextOffsetY, self.bounds.size.width - self.fadeLength * 2.0f, expectedLabelSize.height);
        
        self.homeLabelFrame = labelFrame;
        self.awayLabelFrame = labelFrame;
        
        // Remove any additional text layers (for MLContinuous)
        NSArray *textLayers = [self.layer.sublayers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", @"textLayer"]];
        for (MLTextLayer *tl in textLayers) {
            if (tl != self.textLayer) {
                [tl removeFromSuperlayer];
            }
        }
        
        self.textLayer.frame = self.homeLabelFrame;
        
        return;
    }
    
    // Label does need to scroll
    [self.textLayer setLineBreakMode:NSLineBreakByClipping];
    
    switch (self.marqueeType) {
        case MLContinuous:
        {
            self.homeLabelFrame = CGRectMake(self.fadeLength, labelTextOffsetY, expectedLabelSize.width, expectedLabelSize.height);
            CGFloat awayLabelOffset = -(self.homeLabelFrame.size.width + 2 * self.fadeLength + self.continuousMarqueeExtraBuffer);
            self.awayLabelFrame = CGRectOffset(self.homeLabelFrame, awayLabelOffset, 0.0f);
            
            NSArray *textLayers = [self.layer.sublayers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", @"textLayer"]];
            if (textLayers.count < 2) {
                MLTextLayer *secondTextLayer = [MLTextLayer layer];
                secondTextLayer.frame = self.homeLabelFrame;
                secondTextLayer.name = @"textLayer";
                secondTextLayer.font = self.textLayer.font;
                secondTextLayer.fontSize = self.textLayer.fontSize;
                secondTextLayer.foregroundColor = self.textLayer.foregroundColor;
                secondTextLayer.backgroundColor = self.textLayer.backgroundColor;
                secondTextLayer.shadowColor = self.textLayer.shadowColor;
                secondTextLayer.shadowOffset = self.textLayer.shadowOffset;
                secondTextLayer.textAlignment = NSTextAlignmentLeft;
                
                secondTextLayer.frame = CGRectOffset(self.homeLabelFrame, self.homeLabelFrame.size.width + self.fadeLength + self.continuousMarqueeExtraBuffer, 0.0f);
                [self.layer addSublayer:secondTextLayer];
                textLayers = [textLayers arrayByAddingObject:secondTextLayer];
            }
            
            for (MLTextLayer *tl in textLayers) {
                tl.string = self.textLayer.string;
            }
            
            // Recompute the animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval) fabs(self.awayLabelFrame.origin.x) / self.rate) : (self.lengthOfScroll);
            
            // Enforce text alignment for this type
            self.textLayer.textAlignment = NSTextAlignmentLeft;
            
            self.textLayer.frame = self.homeLabelFrame;
            
            break;
        }
            
        case MLRightLeft:
        {
            self.homeLabelFrame = CGRectMake(self.bounds.size.width - (expectedLabelSize.width + self.fadeLength), labelTextOffsetY, expectedLabelSize.width, expectedLabelSize.height);
            self.awayLabelFrame = CGRectMake(self.fadeLength, labelTextOffsetY, expectedLabelSize.width, expectedLabelSize.height);
            
            // Calculate animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval)fabs(self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x) / self.rate) : (self.lengthOfScroll);
            
            // Set frame and text
            self.textLayer.frame = self.homeLabelFrame;
            
            // Enforce text alignment for this type
            self.textLayer.textAlignment = NSTextAlignmentRight;
            
            break;
        }
        
        //Fallback to LeftRight marqueeType
        default:
        {
            self.homeLabelFrame = CGRectMake(self.fadeLength, labelTextOffsetY, expectedLabelSize.width, expectedLabelSize.height);
            self.awayLabelFrame = CGRectOffset(self.homeLabelFrame, -expectedLabelSize.width + (self.bounds.size.width - self.fadeLength * 2), 0.0);
            
            // Calculate animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval)fabs(self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x) / self.rate) : (self.lengthOfScroll);
            
            // Set frame
            self.textLayer.frame = self.homeLabelFrame;
            
            // Enforce text alignment for this type
            self.textLayer.textAlignment = NSTextAlignmentLeft;
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
    
    CAGradientLayer *gradientMask = nil;
    if (fadeLength != 0.0f) {
        // Recreate gradient mask with new fade length
        gradientMask = [CAGradientLayer layer];
        
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
    }
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    self.layer.mask = gradientMask;
    [CATransaction commit];
    
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
    
    BOOL labelWidth = (self.bounds.size.width < [self subLabelSize].width + (self.marqueeType == MLContinuous ? 2 * self.fadeLength : self.fadeLength));
    return (!self.labelize && labelWidth);
}

- (NSTimeInterval)durationForInterval:(NSTimeInterval)interval {
    switch (self.marqueeType) {
        case MLContinuous:
            return (interval * 2.0);
            break;
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
        case MLContinuous:
            [self scrollLeftPerpetualWithInterval:[self durationForInterval:self.animationDuration] after:(delay ? self.animationDelay : 0.0)];
            break;
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
    
    MLBasicAnimation *animation = [MLBasicAnimation animationWithKeyPath:@"position"];
    animation.fromValue = [self.textLayer valueForKey:@"position"];
    animation.toValue = [NSValue valueWithCGPoint:self.awayLabelFrame.origin];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:self.mediaTimingFunction];
    animation.duration = interval;
    animation.beginTime = CACurrentMediaTime() + delayAmount;
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = NO;
    animation.delegate = self;
    
    // Set completion block
    __weak __typeof(&*self)weakSelf = self;
    animationCompletionBlock completionBlock = ^void(void)
    {
        // Check for in-flight animation away
        if ([weakSelf.layer animationForKey:kMarqueeLabelScrollHomeAnimation]) {
            return;
        }
        
        weakSelf.textLayer.position = weakSelf.awayLabelFrame.origin;
        [weakSelf scrollHomeWithInterval:interval delayAmount:delayAmount];
    };
    [animation setValue:[completionBlock copy] forKey:kMarqueeLabelAnimationCompletionBlock];
    [animation setValue:kMarqueeLabelScrollAwayAnimation forKey:kMarqueeLabelAnimationName];
    
    
    [self.textLayer addAnimation:animation forKey:kMarqueeLabelScrollAwayAnimation];
    
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
    
    MLBasicAnimation *animation = [MLBasicAnimation animationWithKeyPath:@"position"];
    animation.fromValue = [self.textLayer valueForKey:@"position"];
    animation.toValue = [NSValue valueWithCGPoint:self.homeLabelFrame.origin];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:self.mediaTimingFunction];
    animation.duration = interval;
    animation.beginTime = CACurrentMediaTime() + delayAmount;
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = NO;
    animation.delegate = self;
    
    self.textLayer.position = self.homeLabelFrame.origin;
    
    // Set completion block
    __weak __typeof(&*self)weakSelf = self;
    animationCompletionBlock completionBlock = ^void(void)
    {
        // Check for in-flight animation away
        if ([weakSelf.layer animationForKey:kMarqueeLabelScrollAwayAnimation]) {
            return;
        }
        
        self.awayFromHome = NO;
        weakSelf.textLayer.position = weakSelf.homeLabelFrame.origin;
        if (!weakSelf.tapToScroll) {
            [weakSelf scrollAwayWithInterval:interval delayAmount:delayAmount];
        }
    };
    [animation setValue:[completionBlock copy] forKey:kMarqueeLabelAnimationCompletionBlock];
    [animation setValue:kMarqueeLabelScrollHomeAnimation forKey:kMarqueeLabelAnimationName];
    
    [self.textLayer addAnimation:animation forKey:kMarqueeLabelScrollHomeAnimation];
    
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

- (void)scrollLeftPerpetualWithInterval:(NSTimeInterval)interval after:(NSTimeInterval)delayAmount {
    if (![self superview]) {
        return;
    }
    
    // Return label to home frame
    [self returnLabelToOriginImmediately];
    
    UIViewController *viewController = [self firstAvailableUIViewController];
    if (!(viewController.isViewLoaded && viewController.view.window)) {
        return;
    }
    
    NSArray *textLayers = [self.layer.sublayers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", @"textLayer"]];
    CGFloat offset = 0.0f;
    
    [CATransaction begin];
    
    for (MLTextLayer *tl in textLayers) {
        MLBasicAnimation *layerAnimation = [MLBasicAnimation animationWithKeyPath:@"position"];
        layerAnimation.fromValue = [tl valueForKey:@"position"];
        CGPoint toPoint = self.awayLabelFrame.origin;
        toPoint.x += offset;
        layerAnimation.toValue = [NSValue valueWithCGPoint:toPoint];
        layerAnimation.timingFunction = [CAMediaTimingFunction functionWithName:self.mediaTimingFunction];
        layerAnimation.duration = interval;
        layerAnimation.beginTime = CACurrentMediaTime() + delayAmount;
        layerAnimation.fillMode = kCAFillModeForwards;
        layerAnimation.removedOnCompletion = NO;
        layerAnimation.delegate = self;
        
        if (offset == 0.0f) {
            // First animation
            // Set completion block
            __weak __typeof(&*self)weakSelf = self;
            animationCompletionBlock completionBlock = ^void(void)
            {
                // Check for in-flight animation away
                if ([weakSelf.layer animationForKey:kMarqueeLabelScrollAwayAnimation]) {
                    return;
                }
                
                weakSelf.textLayer.position = weakSelf.awayLabelFrame.origin;
                if (!weakSelf.tapToScroll) {
                    [self scrollLeftPerpetualWithInterval:interval after:delayAmount];
                }
            };
            [layerAnimation setValue:[completionBlock copy] forKey:kMarqueeLabelAnimationCompletionBlock];
            [layerAnimation setValue:kMarqueeLabelScrollAwayAnimation forKey:kMarqueeLabelAnimationName];
        }
        
        // Add animation
        [tl addAnimation:layerAnimation forKey:kMarqueeLabelScrollAwayAnimation];
        
        // Increment offset
        offset += self.homeLabelFrame.size.width + 2 * self.fadeLength + self.continuousMarqueeExtraBuffer;
    }
    
    [CATransaction commit];
    
    /*
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
     */
}

- (void)returnLabelToOriginImmediately {
    [self.layer removeAllAnimations];
    
    NSArray *textLayers = [self.layer.sublayers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", @"textLayer"]];
    CGFloat offset = 0.0f;
    for (MLTextLayer *tl in textLayers) {
        [tl removeAllAnimations];
        tl.frame = CGRectOffset(self.homeLabelFrame, offset, 0.0f);
        offset += self.homeLabelFrame.size.width + self.fadeLength + self.continuousMarqueeExtraBuffer;
    }
    
    if (self.textLayer.position.x == self.homeLabelFrame.origin.x) {
        self.awayFromHome = NO;
    } else {
        [self returnLabelToOriginImmediately];
    }
}

#pragma mark CATextLayer Delegate

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if(!flag) {
        // Animation was interrupted
        return;
    }
    
    animationCompletionBlock completionBlock = [anim valueForKey:kMarqueeLabelAnimationCompletionBlock];
    if (completionBlock) {
        completionBlock();
    }
}

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

- (void)setAnimationCurve:(UIViewAnimationOptions)animationCurve {
    if (_animationCurve == animationCurve) {
        return;
    }
    
    _animationCurve = animationCurve;
    
    NSUInteger allowableOptions = UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionCurveLinear;
    if ((allowableOptions & animationCurve) == animationCurve) {
        switch (animationCurve) {
            case UIViewAnimationOptionCurveEaseIn:
                self.mediaTimingFunction = kCAMediaTimingFunctionEaseIn;
                break;
            
            case UIViewAnimationOptionCurveEaseOut:
                self.mediaTimingFunction = kCAMediaTimingFunctionEaseOut;
                break;
            
            case UIViewAnimationOptionCurveLinear:
                self.mediaTimingFunction = kCAMediaTimingFunctionLinear;
                break;
            
            default:
                self.mediaTimingFunction = kCAMediaTimingFunctionEaseInEaseOut;
                break;
        }
    }
}

- (void)setFadeLength:(CGFloat)fadeLength {
    if (_fadeLength == fadeLength) {
        return;
    }
    
    _fadeLength = fadeLength;
    [self applyGradientMaskForFadeLength:_fadeLength];
    [self updateSublabelAndLocations];
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
        self.userInteractionEnabled = YES;
    } else {
        [self removeGestureRecognizer:self.tapRecognizer];
        self.tapRecognizer = nil;
        self.userInteractionEnabled = NO;
    }
}

- (void)setMarqueeType:(MarqueeType)marqueeType {
    if (marqueeType == _marqueeType) {
        return;
    }
    
    _marqueeType = marqueeType;
    
    if (_marqueeType == MLContinuous) {
        
    } else {
        // Remove any second text layers
        NSArray *textLayers = [self.layer.sublayers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", @"textLayer"]];
        for (MLTextLayer *tl in textLayers) {
            if (tl != self.textLayer) {
                [tl removeFromSuperlayer];
            }
        }
    }
    
    [self updateSublabelAndLocations];
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

// Custom labelize mutator to restart scrolling after changing labelize to NO
- (void)setLabelize:(BOOL)labelize {
    if (_labelize == labelize) {
        return;
    }
    
    _labelize = labelize;
    
    if (labelize && self.textLayer != nil) {
        [self returnLabelToOriginImmediately];
    }
    
    [self updateSublabelAndLocationsAndBeginScroll:YES];
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

- (void)drawRect:(CGRect)rect {
    // Do nothing, override UILabel drawing
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.orientationObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end



#pragma mark - Helpers

@implementation UIView (MarqueeLabelHelpers)
// Thanks to Phil M
// http://stackoverflow.com/questions/1340434/get-to-uiviewcontroller-from-uiview-on-iphone

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


@implementation MLBasicAnimation

@end


@implementation UIFont (MarqueeLabelHelpers)

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


@implementation MLTextLayer

+ (id)layer {
    MLTextLayer *layer = [[MLTextLayer alloc] init];
    if (layer) {
        // Disable lots of implicit animations
        layer.actions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                  [NSNull null], @"shadowColor",
                                  [NSNull null], @"foregroundColor",
                                  [NSNull null], @"font",
                                  [NSNull null], @"fontSize",
                                  [NSNull null], @"contents",
                                  [NSNull null], @"position",
                                  [NSNull null], @"bounds",
                                  [NSNull null], @"string",
                                  nil];
        layer.anchorPoint = CGPointMake(0.0f, 0.0f);
        layer.rasterizationScale = [[UIScreen mainScreen] scale];
        layer.contentsScale = [[UIScreen mainScreen] scale];
    }
    return layer;
}

- (void)setBounds:(CGRect)bounds {
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    [super setBounds:bounds];
    [CATransaction commit];
}

- (void)setPosition:(CGPoint)position {
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    [super setPosition:position];
    [CATransaction commit];
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
