
//
//  MarqueeLabel.m
//  

#import "MarqueeLabel.h"
#import <QuartzCore/QuartzCore.h>

NSString *const kMarqueeLabelViewDidAppearNotification = @"MarqueeLabelViewControllerDidAppear";
NSString *const kMarqueeLabelShouldLabelizeNotification = @"MarqueeLabelShouldLabelizeNotification";
NSString *const kMarqueeLabelShouldAnimateNotification = @"MarqueeLabelShouldAnimateNotification";

typedef void (^animationCompletionBlock)(void);

// Helpers
@interface UIView (MarqueeLabelHelpers)
- (UIViewController *)firstAvailableUIViewController;
- (id)traverseResponderChainForUIViewController;
@end

@interface MarqueeLabel()

@property (nonatomic, strong) UILabel *subLabel;

@property (nonatomic, assign, readwrite) BOOL awayFromHome;
@property (nonatomic, assign) BOOL orientationWillChange;
@property (nonatomic, strong) id orientationObserver;

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
- (NSArray *)allSubLabels;

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

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self) {
        [self setupLabel];
        
        if (self.lengthOfScroll == 0) {
            self.lengthOfScroll = 7.0;
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
    NSArray *properties = @[@"baselineAdjustment", @"enabled", @"font", @"highlighted", @"highlightedTextColor", @"minimumFontSize", @"shadowColor", @"shadowOffset", @"textAlignment", @"textColor", @"userInteractionEnabled", @"text", @"adjustsFontSizeToFitWidth", @"lineBreakMode", @"numberOfLines", @"backgroundColor"];
    for (NSString *property in properties) {
        id val = [super valueForKey:property];
        [self.subLabel setValue:val forKey:property];
    }
    [self setText:[super text]];
    [self setFont:[super font]];
}

- (void)setupLabel {
    
    // Basic UILabel options override
    self.clipsToBounds = YES;
    self.numberOfLines = 1;
    
    self.subLabel = [[UILabel alloc] initWithFrame:self.bounds];
    self.subLabel.tag = 700;
    [self addSubview:self.subLabel];
    
    [super setBackgroundColor:[UIColor clearColor]];
    
    _animationCurve = UIViewAnimationOptionCurveEaseInOut;
    _awayFromHome = NO;
    _orientationWillChange = NO;
    _labelize = NO;
    _holdScrolling = NO;
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
                                                                                 [weakSelf returnLabelToOriginImmediately];
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
    if (self.subLabel.text != nil) {
        // Calculate text size
        if (CGSizeEqualToSize(maxSize, CGSizeZero)) {
            maxSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
        }
        CGSize minimumLabelSize = [self.subLabel.text sizeWithFont:self.subLabel.font
                                                   constrainedToSize:maxSize
                                                       lineBreakMode:NSLineBreakByClipping];
        // Adjust for fade length
        CGSize minimumSize = CGSizeMake(minimumLabelSize.width + (self.fadeLength * 2), minimumLabelSize.height);
        
        // Apply to frame
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, minimumSize.width, (adjustHeight ? minimumSize.height : self.frame.size.height));
    }
}

-(void)didMoveToSuperview {
    [self updateSublabelAndLocationsAndBeginScroll:YES];
}

#pragma mark - MarqueeLabel Heavy Lifting

- (void)updateSublabelAndLocations {
    [self updateSublabelAndLocationsAndBeginScroll:YES];
}

- (void)updateSublabelAndLocationsAndBeginScroll:(BOOL)beginScroll {
    if (!self.subLabel.text) {
        return;
    }
    
    // Calculate expected size
    CGSize expectedLabelSize = [self subLabelSize];
    
    // Move to origin
    [self returnLabelToOriginImmediately];
    
    // Check if label is labelized, or does not need to scroll
    if (self.labelize || !self.labelShouldScroll) {
        // Set text alignment and break mode to act like normal label
        [self.subLabel setTextAlignment:[super textAlignment]];
        [self.subLabel setLineBreakMode:[super lineBreakMode]];
        
        CGRect labelFrame = CGRectMake(self.fadeLength, 0.0f, self.bounds.size.width - self.fadeLength * 2.0f, expectedLabelSize.height);
        
        self.homeLabelFrame = labelFrame;
        self.awayLabelFrame = labelFrame;
        
        // Remove any additional text layers (for MLContinuous)
        NSArray *labels = [self allSubLabels];
        for (UILabel *sl in labels) {
            if (sl != self.subLabel) {
                [sl removeFromSuperview];
            }
        }
        
        self.subLabel.frame = self.homeLabelFrame;
        
        return;
    }
    
    // Label does need to scroll
    [self.subLabel setLineBreakMode:NSLineBreakByClipping];
    
    switch (self.marqueeType) {
        case MLContinuous:
        {
            self.homeLabelFrame = CGRectMake(self.fadeLength, 0.0f, expectedLabelSize.width, expectedLabelSize.height);
            CGFloat awayLabelOffset = -(self.homeLabelFrame.size.width + 2 * self.fadeLength + self.continuousMarqueeExtraBuffer);
            self.awayLabelFrame = CGRectOffset(self.homeLabelFrame, awayLabelOffset, 0.0f);
            
            NSArray *labels = [self allSubLabels];
            if (labels.count < 2) {
                UILabel *secondSubLabel = [[UILabel alloc] initWithFrame:CGRectOffset(self.homeLabelFrame, self.homeLabelFrame.size.width + self.fadeLength + self.continuousMarqueeExtraBuffer, 0.0f)];
                secondSubLabel.tag = 701;
                secondSubLabel.numberOfLines = 1;
                
                [self addSubview:secondSubLabel];
                labels = [labels arrayByAddingObject:secondSubLabel];
            }
            
            [self refreshSubLabels:labels];
            
            // Recompute the animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval) fabs(self.awayLabelFrame.origin.x) / self.rate) : (self.lengthOfScroll);
            
            self.subLabel.frame = self.homeLabelFrame;
            
            break;
        }
            
        case MLContinuousReverse:
        {
            self.homeLabelFrame = CGRectMake(self.bounds.size.width - (expectedLabelSize.width + self.fadeLength), 0.0f, expectedLabelSize.width, expectedLabelSize.height);
            CGFloat awayLabelOffset = (self.homeLabelFrame.size.width + 2 * self.fadeLength + self.continuousMarqueeExtraBuffer);
            self.awayLabelFrame = CGRectOffset(self.homeLabelFrame, awayLabelOffset, 0.0f);
            
            NSArray *labels = [self allSubLabels];
            if (labels.count < 2) {
                UILabel *secondSubLabel = [[UILabel alloc] initWithFrame:CGRectOffset(self.homeLabelFrame, -(self.homeLabelFrame.size.width + self.fadeLength + self.continuousMarqueeExtraBuffer), 0.0f)];
                secondSubLabel.numberOfLines = 1;
                secondSubLabel.tag = 701;
                
                [self addSubview:secondSubLabel];
                labels = [labels arrayByAddingObject:secondSubLabel];
            }
            
            [self refreshSubLabels:labels];
            
            // Recompute the animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval) fabs(self.awayLabelFrame.origin.x) / self.rate) : (self.lengthOfScroll);
            
            self.subLabel.frame = self.homeLabelFrame;
            
            break;
        }
            
        case MLRightLeft:
        {
            self.homeLabelFrame = CGRectMake(self.bounds.size.width - (expectedLabelSize.width + self.fadeLength), 0.0f, expectedLabelSize.width, expectedLabelSize.height);
            self.awayLabelFrame = CGRectMake(self.fadeLength, 0.0f, expectedLabelSize.width, expectedLabelSize.height);
            
            // Calculate animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval)fabs(self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x) / self.rate) : (self.lengthOfScroll);
            
            // Set frame and text
            self.subLabel.frame = self.homeLabelFrame;
            
            // Enforce text alignment for this type
            self.subLabel.textAlignment = NSTextAlignmentRight;
            
            break;
        }
        
        //Fallback to LeftRight marqueeType
        default:
        {
            self.homeLabelFrame = CGRectMake(self.fadeLength, 0.0f, expectedLabelSize.width, expectedLabelSize.height);
            self.awayLabelFrame = CGRectOffset(self.homeLabelFrame, -expectedLabelSize.width + (self.bounds.size.width - self.fadeLength * 2), 0.0);
            
            // Calculate animation duration
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval)fabs(self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x) / self.rate) : (self.lengthOfScroll);
            
            // Set frame
            self.subLabel.frame = self.homeLabelFrame;
            
            // Enforce text alignment for this type
            self.subLabel.textAlignment = NSTextAlignmentLeft;
        }
            
    } //end of marqueeType switch
    
    if (!self.tapToScroll && !self.holdScrolling && beginScroll) {
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
    // Calculate expected size
    CGSize expectedLabelSize = CGSizeZero;
    CGSize maximumLabelSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
    // Check for attributed string attributes
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0) {
        // Calculate based on attributed text
        expectedLabelSize = [self.subLabel.attributedText boundingRectWithSize:maximumLabelSize
                                                                       options:0
                                                                       context:nil].size;
    } else {
        // Calculate on base string
        expectedLabelSize = [self.subLabel.text sizeWithFont:self.font
                                           constrainedToSize:maximumLabelSize
                                               lineBreakMode:NSLineBreakByClipping];
    }
    
    expectedLabelSize.width = ceilf(expectedLabelSize.width);
    expectedLabelSize.height = self.bounds.size.height;
    
    return expectedLabelSize;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize fitSize = [super sizeThatFits:size];
    fitSize.width += 2.0f * self.fadeLength;
    return fitSize;
}

#pragma mark - Animation Handlers

- (BOOL)labelShouldScroll {
    BOOL stringLength = ([self.subLabel.text length] > 0);
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
        case MLContinuousReverse:
            [self scrollContinuousWithInterval:[self durationForInterval:self.animationDuration] after:(delay ? self.animationDelay : 0.0)];
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
    
    UIViewController *viewController = [self firstAvailableUIViewController];
    if (!(viewController.isViewLoaded && viewController.view.window)) {
        return;
    }
    
    // Perform animation
    self.awayFromHome = YES;
    
    [self.subLabel.layer removeAllAnimations];
    [self.layer removeAllAnimations];
    
    [UIView animateWithDuration:interval
                          delay:delayAmount
                        options:self.animationCurve
                     animations:^{
                         self.subLabel.frame = self.awayLabelFrame;
                     }
                     completion:^(BOOL finished) {
                         if (finished) {
                             [self scrollHomeWithInterval:interval delayAmount:delayAmount];
                         }
                     }];
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
    
    [UIView animateWithDuration:interval
                          delay:delayAmount
                        options:self.animationCurve
                     animations:^{
                         self.subLabel.frame = self.homeLabelFrame;
                     }
                     completion:^(BOOL finished){
                         if (finished) {
                             // Set awayFromHome
                             self.awayFromHome = NO;
                             if (!self.tapToScroll && !self.holdScrolling) {
                                 [self scrollAwayWithInterval:interval];
                             }
                         }
                     }];
}

- (void)scrollContinuousWithInterval:(NSTimeInterval)interval after:(NSTimeInterval)delayAmount {
    if (![self superview]) {
        return;
    }
    
    // Return labels to home frame
    [self returnLabelToOriginImmediately];
    
    UIViewController *viewController = [self firstAvailableUIViewController];
    if (!(viewController.isViewLoaded && viewController.view.window)) {
        return;
    }
    
    NSArray *labels = [self allSubLabels];
    __block CGFloat offset = 0.0f;
    
    self.awayFromHome = YES;
    
    // Animate
    [UIView animateWithDuration:interval
                          delay:delayAmount
                        options:self.animationCurve
                     animations:^{
                         for (UILabel *sl in labels) {
                             sl.frame = CGRectOffset(self.awayLabelFrame, offset, 0.0f);
                             
                             // Increment offset
                             offset += (self.marqueeType == MLContinuousReverse ? -1 : 1) * (self.homeLabelFrame.size.width + 2 * self.fadeLength + self.continuousMarqueeExtraBuffer);
                         }
                     }
                     completion:^(BOOL finished) {
                         if (finished && !self.tapToScroll && !self.holdScrolling) {
                             self.awayFromHome = NO;
                             [self scrollContinuousWithInterval:interval after:delayAmount];
                         }
                     }];
}

- (void)returnLabelToOriginImmediately {
    NSArray *labels = [self allSubLabels];
    CGFloat offset = 0.0f;
    for (UILabel *sl in labels) {
        [sl.layer removeAllAnimations];
        sl.frame = CGRectOffset(self.homeLabelFrame, offset, 0.0f);
        offset += (self.marqueeType == MLContinuousReverse ? -1 : 1) * (self.homeLabelFrame.size.width + self.fadeLength + self.continuousMarqueeExtraBuffer);
    }
    
    if (self.subLabel.frame.origin.x == self.homeLabelFrame.origin.x) {
        self.awayFromHome = NO;
    } else {
        [self returnLabelToOriginImmediately];
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
        NSArray *labels = [self allSubLabels];
        for (UILabel *sl in labels) {
            CFTimeInterval pausedTime = [sl.layer convertTime:CACurrentMediaTime() fromLayer:nil];
            sl.layer.speed = 0.0;
            sl.layer.timeOffset = pausedTime;
        }
        self.isPaused = YES;
    }
}

-(void)unpauseLabel
{
    if (self.isPaused) {
        NSArray *labels = [self allSubLabels];
        for (UILabel *sl in labels) {
            CFTimeInterval pausedTime = [sl.layer timeOffset];
            sl.layer.speed = 1.0;
            sl.layer.timeOffset = 0.0;
            sl.layer.beginTime = 0.0;
            CFTimeInterval timeSincePause = [sl.layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
            sl.layer.beginTime = timeSincePause;
        }
        self.isPaused = NO;
    }
}

- (void)labelWasTapped:(UITapGestureRecognizer *)recognizer {
    if (self.labelShouldScroll) {
        [self beginScrollWithDelay:NO];
    }
}

#pragma mark - Modified UILabel Getters/Setters

- (void)setFrame:(CGRect)frame {
    CGRect oldFrame = self.frame;
    
    [super setFrame:frame];
    
    if (CGSizeEqualToSize(frame.size, oldFrame.size)) {
        return;
    }
    
    [self applyGradientMaskForFadeLength:self.fadeLength animated:!self.orientationWillChange];
    [self updateSublabelAndLocationsAndBeginScroll:!self.orientationWillChange];
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

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
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

- (void)setAdjustsLetterSpacingToFitWidth:(BOOL)adjustsLetterSpacingToFitWidth {
    // By the nature of MarqueeLabel, this is NO
    [super setAdjustsLetterSpacingToFitWidth:NO];
}

- (void)setMinimumScaleFactor:(CGFloat)minimumScaleFactor {
    [super setMinimumScaleFactor:0.0f];
}
#endif

- (void)refreshSubLabels:(NSArray *)subLabels {
    for (UILabel *sl in subLabels) {
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
        sl.attributedText = self.attributedText;
#else
        sl.text = self.text;
        sl.font = self.font;
        sl.textColor = self.textColor;
#endif
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
        NSArray *labels = [self allSubLabels];
        for (UILabel *sl in labels) {
            if (sl != self.subLabel) {
                [sl removeFromSuperview];
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

- (void)setLabelize:(BOOL)labelize {
    if (_labelize == labelize) {
        return;
    }
    
    _labelize = labelize;
    
    if (labelize && self.subLabel != nil) {
        [self returnLabelToOriginImmediately];
    }
    
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
