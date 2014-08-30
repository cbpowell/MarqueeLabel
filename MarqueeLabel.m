
//
//  MarqueeLabel.m
//  

#import "MarqueeLabel.h"
#import <QuartzCore/QuartzCore.h>

NSString *const kMarqueeLabelControllerRestartNotification = @"MarqueeLabelViewControllerRestart";
NSString *const kMarqueeLabelShouldLabelizeNotification = @"MarqueeLabelShouldLabelizeNotification";
NSString *const kMarqueeLabelShouldAnimateNotification = @"MarqueeLabelShouldAnimateNotification";

// Helpers
@interface UIView (MarqueeLabelHelpers)
- (UIViewController *)firstAvailableViewController;
- (id)traverseResponderChainForFirstViewController;
@end

@interface CAMediaTimingFunction (MarqueeLabelHelpers)
- (NSArray *)controlPoints;
- (CGFloat)durationPercentageForPositionPercentage:(CGFloat)positionPercentage withDuration:(NSTimeInterval)duration;
@end

@interface MarqueeLabel()

@property (nonatomic, strong) UILabel *subLabel;

@property (nonatomic, assign) BOOL orientationWillChange;
@property (nonatomic, strong) id orientationObserver;

@property (nonatomic, assign) NSTimeInterval animationDuration;
@property (nonatomic, assign, readonly) BOOL labelShouldScroll;
@property (nonatomic, weak) UITapGestureRecognizer *tapRecognizer;
@property (nonatomic, assign) CGRect homeLabelFrame;
@property (nonatomic, assign) CGRect awayLabelFrame;
@property (nonatomic, assign, readwrite) BOOL isPaused;

// Support
@property (nonatomic, strong) NSArray *gradientColors;
CGPoint MLOffsetCGPoint(CGPoint point, CGFloat offset);

@end


@implementation MarqueeLabel

#pragma mark - Class Methods and handlers

+ (void)restartLabelsOfController:(UIViewController *)controller {
    [MarqueeLabel notifyController:controller
                       withMessage:kMarqueeLabelControllerRestartNotification];
}

+ (void)controllerViewWillAppear:(UIViewController *)controller {
    [MarqueeLabel restartLabelsOfController:controller];
}

+ (void)controllerViewDidAppear:(UIViewController *)controller {
    [MarqueeLabel restartLabelsOfController:controller];
}

+ (void)controllerViewAppearing:(UIViewController *)controller {
    [MarqueeLabel restartLabelsOfController:controller];
}

+ (void)controllerLabelsShouldLabelize:(UIViewController *)controller {
    [MarqueeLabel notifyController:controller
                       withMessage:kMarqueeLabelShouldLabelizeNotification];
}

+ (void)controllerLabelsShouldAnimate:(UIViewController *)controller {
    [MarqueeLabel notifyController:controller
                       withMessage:kMarqueeLabelShouldAnimateNotification];
}

+ (void)notifyController:(UIViewController *)controller withMessage:(NSString *)message
{
    if (controller && message) {
        [[NSNotificationCenter defaultCenter] postNotificationName:message
                                                            object:nil
                                                          userInfo:[NSDictionary dictionaryWithObject:controller
                                                                                               forKey:@"controller"]];
    }
}

- (void)viewControllerShouldRestart:(NSNotification *)notification {
    UIViewController *controller = [[notification userInfo] objectForKey:@"controller"];
    if (controller == [self firstAvailableViewController]) {
        [self restartLabel];
    }
}

- (void)labelsShouldLabelize:(NSNotification *)notification {
    UIViewController *controller = [[notification userInfo] objectForKey:@"controller"];
    if (controller == [self firstAvailableViewController]) {
        self.labelize = YES;
    }
}

- (void)labelsShouldAnimate:(NSNotification *)notification {
    UIViewController *controller = [[notification userInfo] objectForKey:@"controller"];
    if (controller == [self firstAvailableViewController]) {
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
        
        _scrollDuration = aLengthOfScroll;
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

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupLabel];
        
        if (self.scrollDuration == 0) {
            self.scrollDuration = 7.0;
        }
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self forwardPropertiesToSubLabel];
}

- (void)forwardPropertiesToSubLabel {
    // Since we're a UILabel, we actually do implement all of UILabel's properties.
    // We don't care about these values, we just want to forward them on to our sublabel.
    NSArray *properties = @[@"baselineAdjustment", @"enabled", @"highlighted", @"highlightedTextColor",
                            @"minimumFontSize", @"shadowOffset", @"textAlignment",
                            @"userInteractionEnabled", @"text", @"adjustsFontSizeToFitWidth",
                            @"lineBreakMode", @"numberOfLines"];
    
    // Iterate through properties
    self.subLabel.font = super.font;
    self.subLabel.textColor = super.textColor;
    self.subLabel.backgroundColor = super.backgroundColor;
    self.subLabel.shadowColor = super.shadowColor;
    for (NSString *property in properties) {
        id val = [super valueForKey:property];
        [self.subLabel setValue:val forKey:property];
    }
    
    // Clear super to prevent double-drawing
    super.attributedText = nil;
}

- (void)setupLabel {
    
    // Basic UILabel options override
    self.clipsToBounds = YES;
    self.numberOfLines = 1;
    
    // Create first sublabel
    self.subLabel = [[UILabel alloc] initWithFrame:self.bounds];
    self.subLabel.tag = 700;
    self.subLabel.layer.anchorPoint = CGPointMake(0.0f, 0.0f);
    [self addSubview:self.subLabel];
    
    // Clear superclass UILabel background
    [super setBackgroundColor:[UIColor clearColor]];
    
    // Setup default values
    _animationCurve = UIViewAnimationOptionCurveLinear;
    _orientationWillChange = NO;
    _labelize = NO;
    _holdScrolling = NO;
    _tapToScroll = NO;
    _isPaused = NO;
    _fadeLength = 0.0f;
    _animationDelay = 1.0;
    _animationDuration = 0.0f;
    _continuousMarqueeExtraBuffer = 0.0f;
    
    // Add notification observers
    // Custom class notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewControllerShouldRestart:) name:kMarqueeLabelControllerRestartNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(labelsShouldLabelize:) name:kMarqueeLabelShouldLabelizeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(labelsShouldAnimate:) name:kMarqueeLabelShouldAnimateNotification object:nil];
    
    // UINavigationController view controller change notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observedViewControllerChange:) name:@"UINavigationControllerDidShowViewControllerNotification" object:nil];
    
    // UIApplication state notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(restartLabel) name:UIApplicationDidBecomeActiveNotification object:nil];
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
                                                                                 [weakSelf returnLabelToOriginImmediately];
                                                                                 animationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"UIViewAnimationDidStopNotification"
                                                                                                                                                       object:nil
                                                                                                                                                        queue:nil
                                                                                                                                                   usingBlock:^(NSNotification *notification){
                                                                                                                                                       if ([notification.userInfo objectForKey:@"delegate"] == weakSelf.window) {
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
    
    id ownController = [self firstAvailableViewController];
    if ([fromController isEqual:ownController]) {
        [self shutdownLabel];
    }
    else if ([toController isEqual:ownController]) {
        [self restartLabel];
    }
}

- (void)minimizeLabelFrameWithMaximumSize:(CGSize)maxSize adjustHeight:(BOOL)adjustHeight {
    if (self.subLabel.text != nil) {
        // Calculate text size
        if (CGSizeEqualToSize(maxSize, CGSizeZero)) {
            maxSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
        }
        CGSize minimumLabelSize = [self subLabelSize];
        
        
        // Adjust for fade length
        CGSize minimumSize = CGSizeMake(minimumLabelSize.width + (self.fadeLength * 2), minimumLabelSize.height);
        
        // Find minimum size of options
        minimumSize = CGSizeMake(MIN(minimumSize.width, maxSize.width), MIN(minimumSize.height, maxSize.height));
        
        // Apply to frame
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, minimumSize.width, (adjustHeight ? minimumSize.height : self.frame.size.height));
    }
}

-(void)didMoveToSuperview {
    [self updateSublabelAndLocationsAndBeginScroll:YES];
}

#pragma mark - MarqueeLabel Heavy Lifting

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self updateSublabelAndLocationsAndBeginScroll:!self.orientationWillChange];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    if (!newWindow) {
        [self shutdownLabel];
    }
}

- (void)didMoveToWindow {
    if (self.window) {
        [self updateSublabelAndLocationsAndBeginScroll:!self.orientationWillChange];
    }
}

- (void)updateSublabelAndLocations {
    [self updateSublabelAndLocationsAndBeginScroll:YES];
}

- (void)updateSublabelAndLocationsAndBeginScroll:(BOOL)beginScroll {
    if (!self.subLabel.text || !self.superview) {
        return;
    }
    
    // Calculate expected size
    CGSize expectedLabelSize = [self subLabelSize];
    
    // Invalidate intrinsic size
    [self invalidateIntrinsicContentSize];
    
    // Move to home
    [self returnLabelToOriginImmediately];
    
    // Configure gradient for the current condition
    [self applyGradientMaskForFadeLength:self.fadeLength animated:YES];
    
    // Check if label should scroll
    // Can be because: 1) text fits, or 2) labelization
    // The holdScrolling property does NOT affect this
    if (!self.labelShouldScroll) {
        // Set text alignment and break mode to act like normal label
        [self.subLabel setTextAlignment:[super textAlignment]];
        [self.subLabel setLineBreakMode:[super lineBreakMode]];
        
        CGRect labelFrame = CGRectIntegral(CGRectMake(0.0f, 0.0f, self.bounds.size.width , expectedLabelSize.height));
        
        self.homeLabelFrame = labelFrame;
        self.awayLabelFrame = labelFrame;
        
        // Remove any additional text layers (for MLContinuous)
        NSArray *labels = [self allSubLabels];
        for (UILabel *sl in labels) {
            if (sl != self.subLabel) {
                [sl removeFromSuperview];
            }
        }
        
        // Set sublabel frame to own bounds
        self.subLabel.frame = self.bounds;
        
        return;
    }
    
    // Label DOES need to scroll
    
    [self.subLabel setLineBreakMode:NSLineBreakByClipping];
    
    switch (self.marqueeType) {
        case MLContinuous:
        {
            self.homeLabelFrame = CGRectIntegral(CGRectMake(0.0f, 0.0f, expectedLabelSize.width, expectedLabelSize.height));
            CGFloat awayLabelOffset = -(self.homeLabelFrame.size.width + self.fadeLength + self.continuousMarqueeExtraBuffer);
            self.awayLabelFrame = CGRectIntegral(CGRectOffset(self.homeLabelFrame, awayLabelOffset, 0.0f));
            
            NSArray *labels = [self allSubLabels];
            if (labels.count < 2) {
                UILabel *secondSubLabel = [[UILabel alloc] initWithFrame:CGRectOffset(self.homeLabelFrame, -awayLabelOffset, 0.0f)];
                secondSubLabel.tag = 701;
                secondSubLabel.numberOfLines = 1;
                secondSubLabel.layer.anchorPoint = CGPointMake(0.0f, 0.0f);
                
                [self addSubview:secondSubLabel];
                labels = [labels arrayByAddingObject:secondSubLabel];
            }
            
            [self refreshSubLabels:labels];
            
            // Recompute the animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval) fabs(awayLabelOffset) / self.rate) : (self.scrollDuration);
            
            self.subLabel.frame = self.homeLabelFrame;
            
            break;
        }
            
        case MLContinuousReverse:
        {
            self.homeLabelFrame = CGRectIntegral(CGRectMake(self.bounds.size.width - expectedLabelSize.width, 0.0f, expectedLabelSize.width, expectedLabelSize.height));
            CGFloat awayLabelOffset = (self.homeLabelFrame.size.width + self.fadeLength + self.continuousMarqueeExtraBuffer);
            self.awayLabelFrame = CGRectIntegral(CGRectOffset(self.homeLabelFrame, awayLabelOffset, 0.0f));
            
            NSArray *labels = [self allSubLabels];
            if (labels.count < 2) {
                UILabel *secondSubLabel = [[UILabel alloc] initWithFrame:CGRectOffset(self.homeLabelFrame, -awayLabelOffset, 0.0f)];
                secondSubLabel.numberOfLines = 1;
                secondSubLabel.tag = 701;
                secondSubLabel.layer.anchorPoint = CGPointMake(0.0f, 0.0f);
                
                [self addSubview:secondSubLabel];
                labels = [labels arrayByAddingObject:secondSubLabel];
            }
            
            [self refreshSubLabels:labels];
            
            // Recompute the animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval) fabs(awayLabelOffset) / self.rate) : (self.scrollDuration);
            
            self.subLabel.frame = self.homeLabelFrame;
            
            break;
        }
            
        case MLRightLeft:
        {
            self.homeLabelFrame = CGRectIntegral(CGRectMake(self.bounds.size.width - expectedLabelSize.width, 0.0f, expectedLabelSize.width, expectedLabelSize.height));
            self.awayLabelFrame = CGRectIntegral(CGRectMake(self.fadeLength, 0.0f, expectedLabelSize.width, expectedLabelSize.height));
            
            // Calculate animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval)fabs(self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x) / self.rate) : (self.scrollDuration);
            
            // Set frame and text
            self.subLabel.frame = self.homeLabelFrame;
            
            // Enforce text alignment for this type
            self.subLabel.textAlignment = NSTextAlignmentRight;
            
            break;
        }
        
        case MLLeftRight:
        {
            self.homeLabelFrame = CGRectIntegral(CGRectMake(0.0f, 0.0f, expectedLabelSize.width, expectedLabelSize.height));
            self.awayLabelFrame = CGRectIntegral(CGRectOffset(self.homeLabelFrame, -expectedLabelSize.width + (self.bounds.size.width - self.fadeLength), 0.0));
            
            // Calculate animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval)fabs(self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x) / self.rate) : (self.scrollDuration);
            
            // Set frame
            self.subLabel.frame = self.homeLabelFrame;
            
            // Enforce text alignment for this type
            self.subLabel.textAlignment = NSTextAlignmentLeft;
            
            break;
        }
        
        default:
        {
            // Something strange has happened
            self.homeLabelFrame = CGRectZero;
            self.awayLabelFrame = CGRectZero;
            
            // Do not attempt to begin scroll
            return;
            break;
        }
            
    } //end of marqueeType switch
    
    if (!self.tapToScroll && !self.holdScrolling && beginScroll) {
        [self beginScroll];
    }
}

- (CGSize)subLabelSize {
    // Calculate expected size
    CGSize expectedLabelSize = CGSizeZero;
    CGSize maximumLabelSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
    
    // Calculate based on attributed text
    expectedLabelSize = [self.subLabel.attributedText boundingRectWithSize:maximumLabelSize
                                                                   options:0
                                                                   context:nil].size;
    
    expectedLabelSize.width = ceilf(expectedLabelSize.width);
    expectedLabelSize.height = self.bounds.size.height;
    
    return expectedLabelSize;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize fitSize = [self.subLabel sizeThatFits:size];
    fitSize.width += 2.0f * self.fadeLength;
    return fitSize;
}

#pragma mark - Animation Handlers

- (BOOL)labelShouldScroll {
    BOOL stringLength = ([self.subLabel.text length] > 0);
    if (!stringLength) {
        return NO;
    }
    
    BOOL labelTooLarge = ([self subLabelSize].width > self.bounds.size.width);
    return (!self.labelize && labelTooLarge);
}

- (BOOL)labelReadyForScroll {
    // Check if we have a superview
    if (!self.superview) {
        return NO;
    }
    
    if (!self.window) {
        return NO;
    }
    
    // Check if our view controller is ready
    UIViewController *viewController = [self firstAvailableViewController];
    if (!viewController.isViewLoaded) {
        return NO;
    }
    // Check if application is in active state
    // Prevents CATransaction completionBlock (which does not receive a "finished" parameter
    // like UIView animations) from looping when the application has been backgrounded
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        return NO;
    }

    return YES;
}

- (void)beginScroll {
    [self beginScrollWithDelay:YES];
}

- (void)beginScrollWithDelay:(BOOL)delay {
    switch (self.marqueeType) {
        case MLContinuous:
        case MLContinuousReverse:
            [self scrollContinuousWithInterval:self.animationDuration after:(delay ? self.animationDelay : 0.0)];
            break;
        default:
            [self scrollAwayWithInterval:self.animationDuration];
            break;
    }
}

- (void)returnLabelToOriginImmediately {
    // Remove gradient animations
    [self.layer.mask removeAllAnimations];
    
    // Remove sublabel position animations
    NSArray *labels = [self allSubLabels];
    for (UILabel *sl in labels) {
        [sl.layer removeAllAnimations];
    }
}

- (void)scrollAwayWithInterval:(NSTimeInterval)interval {
    [self scrollAwayWithInterval:interval delay:YES];
}

- (void)scrollAwayWithInterval:(NSTimeInterval)interval delay:(BOOL)delay {
    [self scrollAwayWithInterval:interval delayAmount:(delay ? self.animationDelay : 0.0)];
}

- (void)scrollAwayWithInterval:(NSTimeInterval)interval delayAmount:(NSTimeInterval)delayAmount {
    // Check for conditions which would prevent scrolling
    if (![self labelReadyForScroll]) {
        return;
    }
    
    [self.subLabel.layer removeAllAnimations];
    [self.layer.mask removeAllAnimations];
    
    // Call pre-animation method
    [self labelWillBeginScroll];
    
    // Animate
    [CATransaction begin];
    
    // Set Duration
    [CATransaction setAnimationDuration:(2.0 * (delayAmount + interval))];

    // Create animation for gradient, if needed
    if (self.fadeLength != 0.0f) {
        CAKeyframeAnimation *gradAnim = [self keyFrameAnimationForGradientFadeLength:self.fadeLength
                                                                            interval:interval
                                                                               delay:delayAmount];
        [self.layer.mask addAnimation:gradAnim forKey:@"gradient"];
    }
    
    // Set completion block, after adding gradient animation (so that gradient animation does not affect completion)
    [CATransaction setCompletionBlock:^{
        // Call returned home method
        [self labelReturnedToHome:YES];
        // Check to ensure that:
        // 1) We don't double fire if an animation already exists
        // 2) The instance is still attached to a window - this completion block is called for
        //    many reasons, including if the animation is removed due to the view being removed
        //    from the UIWindow (typically when the view controller is no longer the "top" view)
        if (self.window && ![self.subLabel.layer animationForKey:@"position"]) {
            // Begin again, if conditions met
            if (self.labelShouldScroll && !self.tapToScroll && !self.holdScrolling) {
                [self scrollAwayWithInterval:interval delayAmount:delayAmount];
            }
        }
    }];

    // Create animation for position
    NSArray *values = @[[NSValue valueWithCGPoint:self.homeLabelFrame.origin],      // Initial location, home
                        [NSValue valueWithCGPoint:self.homeLabelFrame.origin],      // Initial delay, at home
                        [NSValue valueWithCGPoint:self.awayLabelFrame.origin],      // Animation to away
                        [NSValue valueWithCGPoint:self.awayLabelFrame.origin],      // Delay at away
                        [NSValue valueWithCGPoint:self.homeLabelFrame.origin]];     // Animation to home
    
    CAKeyframeAnimation *awayAnim = [self keyFrameAnimationForProperty:@"position"
                                                                values:values
                                                              interval:interval
                                                                 delay:delayAmount];
    [self.subLabel.layer addAnimation:awayAnim forKey:@"position"];
    
    [CATransaction commit];
}

- (void)scrollContinuousWithInterval:(NSTimeInterval)interval after:(NSTimeInterval)delayAmount {
    // Check for conditions which would prevent scrolling
    if (![self labelReadyForScroll]) {
        return;
    }
    
    // Return labels to home frame
    [self.subLabel.layer removeAllAnimations];
    [self.layer.mask removeAllAnimations];
    
    // Call pre-animation method
    [self labelWillBeginScroll];
    
    // Animate
    [CATransaction begin];
    
    // Set Duration
    [CATransaction setAnimationDuration:(delayAmount + interval)];
    
    // Create animation for gradient, if needed
    if (self.fadeLength != 0.0f) {
        CAKeyframeAnimation *gradAnim = [self keyFrameAnimationForGradientFadeLength:self.fadeLength
                                                                            interval:interval
                                                                               delay:delayAmount];
        [self.layer.mask addAnimation:gradAnim forKey:@"gradient"];
    }
    
    // Set completion block, after adding gradient animation (so that gradient animation does not affect completion)
    [CATransaction setCompletionBlock:^{
        // Call returned home method
        [self labelReturnedToHome:YES];
        // Check to ensure that:
        // 1) We don't double fire if an animation already exists
        // 2) The instance is still attached to a window - this completion block is called for
        //    many reasons, including if the animation is removed due to the view being removed
        //    from the UIWindow (typically when the view controller is no longer the "top" view)
        if (self.window && ![self.subLabel.layer animationForKey:@"position"]) {
            // Begin again, if conditions met
            if (self.labelShouldScroll && !self.tapToScroll && !self.holdScrolling) {
                [self scrollContinuousWithInterval:interval after:delayAmount];
            }
        }
    }];
    
    // Create animations for sublabel positions
    NSArray *labels = [self allSubLabels];
    CGFloat offset = 0.0f;
    for (UILabel *sl in labels) {
        // Create values, bumped by the offset
        NSArray *values = @[[NSValue valueWithCGPoint:MLOffsetCGPoint(self.homeLabelFrame.origin, offset)],      // Initial location, home
                            [NSValue valueWithCGPoint:MLOffsetCGPoint(self.homeLabelFrame.origin, offset)],      // Initial delay, at home
                            [NSValue valueWithCGPoint:MLOffsetCGPoint(self.awayLabelFrame.origin, offset)]];     // Animation to home
        
        CAKeyframeAnimation *awayAnim = [self keyFrameAnimationForProperty:@"position"
                                                                    values:values
                                                                  interval:interval
                                                                     delay:delayAmount];
        [sl.layer addAnimation:awayAnim forKey:@"position"];
        
        // Increment offset
        offset += (self.marqueeType == MLContinuousReverse ? -1.0f : 1.0f) * (self.homeLabelFrame.size.width + self.fadeLength + self.continuousMarqueeExtraBuffer);
    }
    
    [CATransaction commit];
}

- (void)applyGradientMaskForFadeLength:(CGFloat)fadeLength animated:(BOOL)animated {
    // Check for zero-length fade
    if (fadeLength <= 0.0f) {
        [self removeGradientMask];
        return;
    }
    
    CAGradientLayer *gradientMask = (CAGradientLayer *)self.layer.mask;
    
    [gradientMask removeAllAnimations];
    
    if (!gradientMask) {
        // Create CAGradientLayer if needed
        gradientMask = [CAGradientLayer layer];
    }
    gradientMask.bounds = self.layer.bounds;
    gradientMask.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    gradientMask.shouldRasterize = YES;
    gradientMask.rasterizationScale = [UIScreen mainScreen].scale;
    gradientMask.colors = self.gradientColors;
    gradientMask.startPoint = CGPointMake(0.0f, CGRectGetMidY(self.frame));
    gradientMask.endPoint = CGPointMake(1.0f, CGRectGetMidY(self.frame));
    // Start with default (no fade) locations
    gradientMask.locations = @[@(0.0f), @(0.0f), @(1.0f), @(1.0f)];
    
    // Set mask
    self.layer.mask = gradientMask;
    
    CGFloat leadingFadeLength = 0.0f;
    CGFloat trailingFadeLength = fadeLength;
    
    // No fade if labelized, or if no scrolling is needed
    if (self.labelize || !self.labelShouldScroll) {
        leadingFadeLength = 0.0f;
        trailingFadeLength = 0.0f;
    }
    
    CGFloat leftFadeLength, rightFadeLength;
    switch (self.marqueeType) {
        case MLContinuousReverse:
        case MLRightLeft:
            leftFadeLength = trailingFadeLength;
            rightFadeLength = leadingFadeLength;
            break;
            
        default:
            // MLContinuous
            // MLLeftRight
            leftFadeLength = leadingFadeLength;
            rightFadeLength = trailingFadeLength;
            break;
    }
    
    CGFloat leftFadePoint = leftFadeLength/self.bounds.size.width;
    CGFloat rightFadePoint = rightFadeLength/self.bounds.size.width;
    
    NSArray *adjustedLocations = @[@(0.0f), @(leftFadePoint), @(1.0f - rightFadePoint), @(1.0f)];
    if (animated) {
        // Create animation for gradient change
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"locations"];
        animation.fromValue = gradientMask.locations;
        animation.toValue = adjustedLocations;
        animation.duration = 0.25;
        
        [gradientMask addAnimation:animation forKey:animation.keyPath];
        gradientMask.locations = adjustedLocations;
    } else {
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        gradientMask.locations = adjustedLocations;
        [CATransaction commit];
    }
}

- (void)removeGradientMask {
    self.layer.mask = nil;
}

- (CAKeyframeAnimation *)keyFrameAnimationForGradientFadeLength:(CGFloat)fadeLength
                                                       interval:(NSTimeInterval)interval
                                                          delay:(NSTimeInterval)delayAmount
{
    // Setup
    NSArray *values = nil;
    NSArray *keyTimes = nil;
    CGFloat fadeFraction = fadeLength/self.bounds.size.width;
    NSTimeInterval totalDuration;
    
    // Create new animation
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"locations"];
    
    // Get timing function
    CAMediaTimingFunction *timingFunction = [self timingFunctionForAnimationOptions:self.animationCurve];
    
    // Define keyTimes
    switch (self.marqueeType) {
        case MLLeftRight:
        case MLRightLeft:
            // Calculate total animation duration
            totalDuration = 2.0 * (delayAmount + interval);
            keyTimes = @[
                         @(0.0),                                                    // Initial gradient
                         @(delayAmount/totalDuration),                              // Begin of fade in
                         @((delayAmount + 0.4)/totalDuration),                      // End of fade in, just as scroll away starts
                         @(0.95 * totalDuration/totalDuration),                     // Begin of fade out, just before scroll home completes
                         @(1.0),                                                    // End of fade out, as scroll home completes
                         @(1.0)                                                     // Buffer final value (used on continuous types)
                         ];
            break;
            
        case MLContinuousReverse:
        default:
            // Calculate total animation duration
            totalDuration = delayAmount + interval;
            
            // Find when the lead label will be totally offscreen
            CGFloat offsetDistance = (self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x);
            CGFloat startFadeFraction = fabs(self.subLabel.bounds.size.width / offsetDistance);
            // Find when the animation will hit that point
            CGFloat startFadeTimeFraction = [timingFunction durationPercentageForPositionPercentage:startFadeFraction withDuration:totalDuration];
            NSTimeInterval startFadeTime = delayAmount + startFadeTimeFraction * interval;
            
            keyTimes = @[
                         @(0.0),                                            // Initial gradient
                         @(delayAmount/totalDuration),                      // Begin of fade in
                         @((delayAmount + 0.2)/totalDuration),              // End of fade in, just as scroll away starts
                         @((startFadeTime)/totalDuration),                  // Begin of fade out, just before scroll home completes
                         @((startFadeTime + 0.1)/totalDuration),            // End of fade out, as scroll home completes
                         @(1.0)                                             // Buffer final value (used on continuous types)
                         ];
            break;
    }
    
    // Define values
    switch (self.marqueeType) {
        case MLContinuousReverse:
        case MLRightLeft:
            values = @[
                       @[@(0.0f), @(fadeFraction), @(1.0f), @(1.0f)],                   // Initial gradient
                       @[@(0.0f), @(fadeFraction), @(1.0f), @(1.0f)],                   // Begin of fade in
                       @[@(0.0f), @(fadeFraction), @(1.0f - fadeFraction), @(1.0f)],    // End of fade in, just as scroll away starts
                       @[@(0.0f), @(fadeFraction), @(1.0f - fadeFraction), @(1.0f)],    // Begin of fade out, just before scroll home completes
                       @[@(0.0f), @(fadeFraction), @(1.0f), @(1.0f)],                   // End of fade out, as scroll home completes
                       @[@(0.0f), @(fadeFraction), @(1.0f), @(1.0f)]                    // Final "home" value
                       ];
            break;
            
        case MLLeftRight:
        default:
            values = @[
                       @[@(0.0f), @(0.0f), @(1.0f - fadeFraction), @(1.0f)],            // Initial gradient
                       @[@(0.0f), @(0.0f), @(1.0f - fadeFraction), @(1.0f)],            // Begin of fade in
                       @[@(0.0f), @(fadeFraction), @(1.0f - fadeFraction), @(1.0f)],    // End of fade in, just as scroll away starts
                       @[@(0.0f), @(fadeFraction), @(1.0f - fadeFraction), @(1.0f)],    // Begin of fade out, just before scroll home completes
                       @[@(0.0f), @(0.0f), @(1.0f - fadeFraction), @(1.0f)],            // End of fade out, as scroll home completes
                       @[@(0.0f), @(0.0f), @(1.0f - fadeFraction), @(1.0f)]             // Final "home" value
                       ];
            break;
    }
    
    animation.values = values;
    animation.keyTimes = keyTimes;
    animation.timingFunctions = @[timingFunction, timingFunction, timingFunction, timingFunction];
    
    return animation;
}

- (CAKeyframeAnimation *)keyFrameAnimationForProperty:(NSString *)property
                                               values:(NSArray *)values
                                             interval:(NSTimeInterval)interval
                                                delay:(NSTimeInterval)delayAmount
{
    // Create new animation
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:property];
    
    // Get timing function
    CAMediaTimingFunction *timingFunction = [self timingFunctionForAnimationOptions:self.animationCurve];
    
    // Calculate times based on marqueeType
    NSTimeInterval totalDuration;
    switch (self.marqueeType) {
        case MLLeftRight:
        case MLRightLeft:
            NSAssert(values.count == 5, @"Incorrect number of values passed for MLLeftRight-type animation");
            totalDuration = 2.0 * (delayAmount + interval);
            // Set up keyTimes
            animation.keyTimes = @[@(0.0),                                                   // Initial location, home
                                   @(delayAmount/totalDuration),                             // Initial delay, at home
                                   @((delayAmount + interval)/totalDuration),                // Animation to away
                                   @((delayAmount + interval + delayAmount)/totalDuration),  // Delay at away
                                   @(1.0)];                                                  // Animation to home
            
            animation.timingFunctions = @[timingFunction,
                                          timingFunction,
                                          timingFunction,
                                          timingFunction];
            
            break;
            
            // MLContinuous
            // MLContinuousReverse
        default:
            NSAssert(values.count == 3, @"Incorrect number of values passed for MLContinous-type animation");
            totalDuration = delayAmount + interval;
            // Set up keyTimes
            animation.keyTimes = @[@(0.0),                              // Initial location, home
                                   @(delayAmount/totalDuration),        // Initial delay, at home
                                   @(1.0)];                             // Animation to away
            
            animation.timingFunctions = @[timingFunction,
                                          timingFunction];
            
            break;
    }
    
    // Set values
    animation.values = values;
    
    return animation;
}

- (CAMediaTimingFunction *)timingFunctionForAnimationOptions:(UIViewAnimationOptions)animationOptions {
    NSString *timingFunction;
    switch (animationOptions) {
        case UIViewAnimationOptionCurveEaseIn:
            timingFunction = kCAMediaTimingFunctionEaseIn;
            break;
            
        case UIViewAnimationOptionCurveEaseInOut:
            timingFunction = kCAMediaTimingFunctionEaseInEaseOut;
            break;
            
        case UIViewAnimationOptionCurveEaseOut:
            timingFunction = kCAMediaTimingFunctionEaseOut;
            break;
            
        default:
            timingFunction = kCAMediaTimingFunctionLinear;
            break;
    }
    
    return [CAMediaTimingFunction functionWithName:timingFunction];
}


#pragma mark - Label Control

- (void)restartLabel {
    [self applyGradientMaskForFadeLength:self.fadeLength animated:NO];
    
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
        // Pause sublabel position animations
        NSArray *labels = [self allSubLabels];
        for (UILabel *sl in labels) {
            CFTimeInterval labelPauseTime = [sl.layer convertTime:CACurrentMediaTime() fromLayer:nil];
            sl.layer.speed = 0.0;
            sl.layer.timeOffset = labelPauseTime;
        }
        // Pause gradient fade animation
        CFTimeInterval gradientPauseTime = [self.layer.mask convertTime:CACurrentMediaTime() fromLayer:nil];
        self.layer.mask.speed = 0.0;
        self.layer.mask.timeOffset = gradientPauseTime;
        
        self.isPaused = YES;
    }
}

-(void)unpauseLabel
{
    if (self.isPaused) {
        // Unpause sublabel position animations
        NSArray *labels = [self allSubLabels];
        for (UILabel *sl in labels) {
            CFTimeInterval labelPausedTime = sl.layer.timeOffset;
            sl.layer.speed = 1.0;
            sl.layer.timeOffset = 0.0;
            sl.layer.beginTime = 0.0;
            sl.layer.beginTime = [sl.layer convertTime:CACurrentMediaTime() fromLayer:nil] - labelPausedTime;
        }
        // Unpause gradient fade animation
        CFTimeInterval gradientPauseTime = self.layer.mask.timeOffset;
        self.layer.mask.speed = 1.0;
        self.layer.mask.timeOffset = 0.0;
        self.layer.mask.beginTime = 0.0;
        self.layer.mask.beginTime = [self.layer.mask convertTime:CACurrentMediaTime() fromLayer:nil] - gradientPauseTime;
        
        self.isPaused = NO;
    }
}

- (void)labelWasTapped:(UITapGestureRecognizer *)recognizer {
    if (self.labelShouldScroll) {
        [self beginScrollWithDelay:NO];
    }
}

- (void)labelWillBeginScroll {
    // Default implementation does nothing
    return;
}

- (void)labelReturnedToHome:(BOOL)finished {
    // Default implementation does nothing
    return;
}

#pragma mark - Modified UILabel Methods/Getters/Setters

- (UIView *)viewForBaselineLayout {
    // Use subLabel view for handling baseline layouts
    return self.subLabel;
}

- (NSString *)text {
    return self.subLabel.text;
}

- (void)setText:(NSString *)text {
    if ([text isEqualToString:self.subLabel.text]) {
        return;
    }
    self.subLabel.text = text;
    [self updateSublabelAndLocations];
}

- (NSAttributedString *)attributedText {
    return self.subLabel.attributedText;
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if ([attributedText isEqualToAttributedString:self.subLabel.attributedText]) {
        return;
    }
    self.subLabel.attributedText = attributedText;
    [self updateSublabelAndLocations];
}

- (UIFont *)font {
    return self.subLabel.font;
}

- (void)setFont:(UIFont *)font {
    if ([font isEqual:self.subLabel.font]) {
        return;
    }
    self.subLabel.font = font;
    [self updateSublabelAndLocations];
}

- (UIColor *)textColor {
    return self.subLabel.textColor;
}

- (void)setTextColor:(UIColor *)textColor {
    [self updateSubLabelsForKey:@"textColor" withValue:textColor];
}

- (UIColor *)backgroundColor {
    return self.subLabel.backgroundColor;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [self updateSubLabelsForKey:@"backgroundColor" withValue:backgroundColor];
}

- (UIColor *)shadowColor {
    return self.subLabel.shadowColor;
}

- (void)setShadowColor:(UIColor *)shadowColor {
    [self updateSubLabelsForKey:@"shadowColor" withValue:shadowColor];
}

- (CGSize)shadowOffset {
    return self.subLabel.shadowOffset;
}

- (void)setShadowOffset:(CGSize)shadowOffset {
    [self updateSubLabelsForKey:@"shadowOffset" withValue:[NSValue valueWithCGSize:shadowOffset]];
}

- (UIColor *)highlightedTextColor {
    return self.subLabel.highlightedTextColor;
}

- (void)setHighlightedTextColor:(UIColor *)highlightedTextColor {
    [self updateSubLabelsForKey:@"highlightedTextColor" withValue:highlightedTextColor];
}

- (BOOL)isHighlighted {
    return self.subLabel.isHighlighted;
}

- (void)setHighlighted:(BOOL)highlighted {
    [self updateSubLabelsForKey:@"highlighted" withValue:@(highlighted)];
}

- (BOOL)isEnabled {
    return self.subLabel.isEnabled;
}

- (void)setEnabled:(BOOL)enabled {
    [self updateSubLabelsForKey:@"enabled" withValue:@(enabled)];
}

- (void)setNumberOfLines:(NSInteger)numberOfLines {
    // By the nature of MarqueeLabel, this is 1
    [super setNumberOfLines:1];
}

- (void)setAdjustsFontSizeToFitWidth:(BOOL)adjustsFontSizeToFitWidth {
    // By the nature of MarqueeLabel, this is NO
    [super setAdjustsFontSizeToFitWidth:NO];
}

- (void)setMinimumFontSize:(CGFloat)minimumFontSize {
    [super setMinimumFontSize:0.0];
}

- (UIBaselineAdjustment)baselineAdjustment {
    return self.subLabel.baselineAdjustment;
}

- (void)setBaselineAdjustment:(UIBaselineAdjustment)baselineAdjustment {
    [self updateSubLabelsForKey:@"baselineAdjustment" withValue:@(baselineAdjustment)];
}

- (CGSize)intrinsicContentSize {
    return self.subLabel.intrinsicContentSize;
}

- (void)setAdjustsLetterSpacingToFitWidth:(BOOL)adjustsLetterSpacingToFitWidth {
    // By the nature of MarqueeLabel, this is NO
    [super setAdjustsLetterSpacingToFitWidth:NO];
}

- (void)setMinimumScaleFactor:(CGFloat)minimumScaleFactor {
    [super setMinimumScaleFactor:0.0f];
}

- (void)refreshSubLabels:(NSArray *)subLabels {
    for (UILabel *sl in subLabels) {
        sl.attributedText = self.attributedText;
        sl.backgroundColor = self.backgroundColor;
        sl.shadowColor = self.shadowColor;
        sl.shadowOffset = self.shadowOffset;
        sl.textAlignment = NSTextAlignmentLeft;
    }
}

- (void)updateSubLabelsForKey:(NSString *)key withValue:(id)value {
    NSArray *labels = [self allSubLabels];
    for (UILabel *sl in labels) {
        [sl setValue:value forKeyPath:key];
    }
}

- (void)updateSubLabelsForKeysWithValues:(NSDictionary *)dictionary {
    NSArray *labels = [self allSubLabels];
    for (UILabel *sl in labels) {
        for (NSString *key in dictionary) {
            [sl setValue:[dictionary objectForKey:key] forKey:key];
        }
    }
}

#pragma mark - Custom Getters and Setters

- (void)setRate:(CGFloat)rate {
    if (_rate == rate) {
        return;
    }
    
    _scrollDuration = 0.0f;
    _rate = rate;
    [self updateSublabelAndLocations];
}

- (void)setScrollDuration:(NSTimeInterval)lengthOfScroll {
    if (_scrollDuration == lengthOfScroll) {
        return;
    }
    
    _rate = 0.0f;
    _scrollDuration = lengthOfScroll;
    [self updateSublabelAndLocations];
}

- (void)setAnimationCurve:(UIViewAnimationOptions)animationCurve {
    if (_animationCurve == animationCurve) {
        return;
    }
    
    NSUInteger allowableOptions = UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionCurveLinear;
    if ((allowableOptions & animationCurve) == animationCurve) {
        _animationCurve = animationCurve;
    }
}

- (void)setContinuousMarqueeExtraBuffer:(CGFloat)continuousMarqueeExtraBuffer {
    if (_continuousMarqueeExtraBuffer == continuousMarqueeExtraBuffer) {
        return;
    }
    
    // Do not allow negative values
    _continuousMarqueeExtraBuffer = fabsf(continuousMarqueeExtraBuffer);
    [self updateSublabelAndLocations];
}

- (void)setFadeLength:(CGFloat)fadeLength {
    if (_fadeLength == fadeLength) {
        return;
    }
    
    _fadeLength = fadeLength;
    
    [self applyGradientMaskForFadeLength:self.fadeLength animated:YES];
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
        NSArray *labels = [self allSubLabels];
        for (UILabel *sl in labels) {
            if (sl != self.subLabel) {
                [sl removeFromSuperview];
            }
        }
    }
    
    [self updateSublabelAndLocations];
}

- (void)setLabelize:(BOOL)labelize {
    if (_labelize == labelize) {
        return;
    }
    
    _labelize = labelize;
    
    [self updateSublabelAndLocationsAndBeginScroll:YES];
}

- (void)setHoldScrolling:(BOOL)holdScrolling {
    if (_holdScrolling == holdScrolling) {
        return;
    }
    
    _holdScrolling = holdScrolling;
    
    if (!holdScrolling && !self.awayFromHome) {
        [self beginScroll];
    }
}

- (BOOL)awayFromHome {
    CALayer *presentationLayer = self.subLabel.layer.presentationLayer;
    if (!presentationLayer) {
        return NO;
    }
    return !(presentationLayer.position.x == self.homeLabelFrame.origin.x);
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

- (NSArray *)allSubLabels {
    return [self.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"tag >= %i", 700]];
}

#pragma mark -

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.orientationObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end



#pragma mark - Helpers

CGPoint MLOffsetCGPoint(CGPoint point, CGFloat offset) {
    return CGPointMake(point.x + offset, point.y);
}

@implementation UIView (MarqueeLabelHelpers)
// Thanks to Phil M
// http://stackoverflow.com/questions/1340434/get-to-uiviewcontroller-from-uiview-on-iphone

- (id)firstAvailableViewController
{
    // convenience function for casting and to "mask" the recursive function
    return [self traverseResponderChainForFirstViewController];
}

- (id)traverseResponderChainForFirstViewController
{
    id nextResponder = [self nextResponder];
    if ([nextResponder isKindOfClass:[UIViewController class]]) {
        return nextResponder;
    } else if ([nextResponder isKindOfClass:[UIView class]]) {
        return [nextResponder traverseResponderChainForFirstViewController];
    } else {
        return nil;
    }
}

@end

@implementation CAMediaTimingFunction (MarqueeLabelHelpers)

- (CGFloat)durationPercentageForPositionPercentage:(CGFloat)positionPercentage withDuration:(NSTimeInterval)duration
{
    // Finds the animation duration percentage that corresponds with the given animation "position" percentage.
    // Utilizes Newton's Method to solve for the parametric Bezier curve that is used by CAMediaAnimation.
    
    NSArray *controlPoints = [self controlPoints];
    CGFloat epsilon = 1.0f / (100.0f * duration);
    
    // Find the t value that gives the position percentage we want
    CGFloat t_found = [self solveTForY:positionPercentage
                           withEpsilon:epsilon
                         controlPoints:controlPoints];
    
    // With that t, find the corresponding animation percentage
    CGFloat durationPercentage = [self XforCurveAt:t_found withControlPoints:controlPoints];
    
    return durationPercentage;
}

- (CGFloat)solveTForY:(CGFloat)y_0 withEpsilon:(CGFloat)epsilon controlPoints:(NSArray *)controlPoints
{
    // Use Newton's Method: http://en.wikipedia.org/wiki/Newton's_method
    // For first guess, use t = y (i.e. if curve were linear)
    CGFloat t0 = y_0;
    CGFloat t1 = y_0;
    CGFloat f0, df0;
    
    for (int i = 0; i < 15; i++) {
        // Base this iteration of t1 calculated from last iteration
        t0 = t1;
        // Calculate f(t0)
        f0 = [self YforCurveAt:t0 withControlPoints:controlPoints] - y_0;
        // Check if this is close (enough)
        if (fabs(f0) < epsilon) {
            // Done!
            return t0;
        }
        // Else continue Newton's Method
        df0 = [self derivativeYValueForCurveAt:t0 withControlPoints:controlPoints];
        // Check if derivative is small or zero ( http://en.wikipedia.org/wiki/Newton's_method#Failure_analysis )
        if (fabs(df0) < 1e-6) {
            break;
        }
        // Else recalculate t1
        t1 = t0 - f0/df0;
    }
    
    NSLog(@"MarqueeLabel: Failed to find t for Y input!");
    return t0;
}

- (CGFloat)YforCurveAt:(CGFloat)t withControlPoints:(NSArray *)controlPoints
{
    CGPoint P0 = [controlPoints[0] CGPointValue];
    CGPoint P1 = [controlPoints[1] CGPointValue];
    CGPoint P2 = [controlPoints[2] CGPointValue];
    CGPoint P3 = [controlPoints[3] CGPointValue];
    
    // Per http://en.wikipedia.org/wiki/Bézier_curve#Cubic_B.C3.A9zier_curves
    return  powf((1 - t),3) * P0.y +
            3.0f * powf(1 - t, 2) * t * P1.y +
            3.0f * (1 - t) * powf(t, 2) * P2.y +
            powf(t, 3) * P3.y;
    
}

- (CGFloat)XforCurveAt:(CGFloat)t withControlPoints:(NSArray *)controlPoints
{
    CGPoint P0 = [controlPoints[0] CGPointValue];
    CGPoint P1 = [controlPoints[1] CGPointValue];
    CGPoint P2 = [controlPoints[2] CGPointValue];
    CGPoint P3 = [controlPoints[3] CGPointValue];
    
    // Per http://en.wikipedia.org/wiki/Bézier_curve#Cubic_B.C3.A9zier_curves
    return  powf((1 - t),3) * P0.x +
            3.0f * powf(1 - t, 2) * t * P1.x +
            3.0f * (1 - t) * powf(t, 2) * P2.x +
            powf(t, 3) * P3.x;
    
}

- (CGFloat)derivativeYValueForCurveAt:(CGFloat)t withControlPoints:(NSArray *)controlPoints
{
    CGPoint P0 = [controlPoints[0] CGPointValue];
    CGPoint P1 = [controlPoints[1] CGPointValue];
    CGPoint P2 = [controlPoints[2] CGPointValue];
    CGPoint P3 = [controlPoints[3] CGPointValue];
    
    return  powf(t, 2) * (-3.0f * P0.y - 9.0f * P1.y - 9.0f * P2.y + 3.0f * P3.y) +
            t * (6.0f * P0.y + 6.0f * P2.y) +
            (-3.0f * P0.y + 3.0f * P1.y);
}

- (NSArray *)controlPoints
{
    float point[2];
    NSMutableArray *pointArray = [NSMutableArray array];
    for (int i = 0; i <= 3; i++) {
        [self getControlPointAtIndex:i values:point];
        [pointArray addObject:[NSValue valueWithCGPoint:CGPointMake(point[0], point[1])]];
    }
    
    return [NSArray arrayWithArray:pointArray];
}

@end
