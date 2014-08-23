//
//  MarqueeLabel-Swift.swift
//  MarqueeLabelDemo-Swift
//
//  Created by Charles Powell on 8/6/14.
//  Copyright (c) 2014 Charles Powell. All rights reserved.
//

import UIKit
import QuartzCore



public class MarqueeLabel: UILabel {
    
    /**
    An enum that defines the types of `MarqueeLabel` scrolling
    
    - LeftRight: Scrolls left first, then back right to the original position.
    - RightLeft: Scrolls right first, then back left to the original position.
    - Continuous: Continuously scrolls left (with a pause at the original position if animationDelay is set).
    - ContinuousReverse: Continuously scrolls right (with a pause at the original position if animationDelay is set).
    */
    
    public enum Type {
        case LeftRight
        case RightLeft
        case Continuous
        case ContinuousReverse
    }
    
    private enum ControllerNotifications: String {
        case Restart = "MLViewControllerRestart"
        case Labelize = "MLShouldLabelize"
        case Animate = "MLShouldAnimate"
    }
    
    //
    // MARK: - Public properties
    //
    
    public var type: Type = .Continuous {
        didSet {
            if type == oldValue {
                return
            }
            self.removeSecondarySublabels()
        }
    }
    
    public var animationCurve: UIViewAnimationOptions = UIViewAnimationOptions.CurveLinear {
        didSet {
            // TODO: implement this
        }
    }
    
    public var labelize: Bool = false {
        didSet {
            if labelize != oldValue {
                self.updateAndScroll(true)
            }
        }
    }
    
    public var holdScrolling: Bool = false {
        didSet {
            if holdScrolling != oldValue {
                if oldValue == true && !self.awayFromHome() {
                    self.beginScroll()
                }
            }
        }
    }
    
    public var tapToScroll: Bool = false {
        didSet {
            if tapToScroll != tapToScroll {
                if tapToScroll {
                    let tapRecognizer = UITapGestureRecognizer(target: self, action: "labelWasTapped:")
                    self.addGestureRecognizer(tapRecognizer)
                    self.userInteractionEnabled = true
                } else {
                    if let recognizer = self.gestureRecognizers.first as UIGestureRecognizer? {
                        self.removeGestureRecognizer(recognizer)
                    }
                    self.userInteractionEnabled = false
                }
            }
        }
    }
    
    public var isPaused: Bool {
        return self.sublabel.layer.speed == 0.0
    }
    
    public var scrollDuration: NSTimeInterval? = 7.0 {
        didSet {
            if scrollDuration != oldValue {
                self.scrollRate = nil
                self.updateAndScroll()
            }
        }
    }
    
    public var scrollRate: CGFloat? = nil {
        didSet {
            if scrollRate != oldValue {
                self.scrollDuration = nil
                self.updateAndScroll()
            }
        }
    }
    
    public var continuousMarqueeExtraBuffer: CGFloat = 0.0 {
        didSet {
            if continuousMarqueeExtraBuffer != oldValue {
                self.updateAndScroll()
            }
        }
    }
    
    public var fadeLength: CGFloat = 0.0 {
        didSet {
            if fadeLength != oldValue {
                self.applyGradientMask(fadeLength, animated: true)
            }
        }
    }
    
    public var animationDelay: NSTimeInterval = 1.0
    
    //
    // MARK: - Private details
    //
    
    private var sublabel = UILabel()
    private var orientationWillChange = false
    private var orientationObserver: AnyObject?
    private var animationDuration: NSTimeInterval = 0.0;

    private var homeLabelFrame: CGRect = CGRect.zeroRect
    private var awayLabelFrame: CGRect = CGRect.zeroRect
    
    
    //
    // MARK: - Initialization
    //
    
    init(frame: CGRect, rate: CGFloat, fadeLength fade: CGFloat) {
        scrollRate = rate
        fadeLength = CGFloat(min(fade, frame.size.width/2.0))
        super.init(frame: frame)
        self.setup()
    }
    
    init(frame: CGRect, duration: NSTimeInterval, fadeLength fade: CGFloat) {
        scrollDuration = duration
        fadeLength = CGFloat(min(fade, frame.size.width/2.0))
        super.init(frame: frame)
        self.setup()
    }
    
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    convenience public override init(frame: CGRect) {
        self.init(frame: frame, duration:7.0, fadeLength:0.0)
    }
    
    private func setup() {
        // Create sublabel
        self.sublabel = UILabel(frame: self.bounds)
        // Add sublabel
        self.addSubview(self.sublabel)
        
        // Configure self
        super.backgroundColor = UIColor.clearColor()
        super.clipsToBounds = true
        super.numberOfLines = 1
        
        // Add notification observers
        // Custom class notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "labelsShouldRestart:", name: ControllerNotifications.Restart.toRaw(), object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "labelsShouldLabelize:", name: ControllerNotifications.Labelize.toRaw(), object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "labelsShouldAnimate:", name: ControllerNotifications.Animate.toRaw(), object: nil)
        
        // UINavigationController view controller change notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "observedViewControllerChange:", name:"UINavigationControllerDidShowViewControllerNotification", object:nil);
        
        // UIApplication state notifications
        /*
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "restartLabel", name: UIApplicationWillEnterForegroundNotification, object:nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "restartLabel", name: UIApplicationDidBecomeActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "shutdownLabel", name: UIApplicationWillResignActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "shutdownLabel", name: UIApplicationDidEnterBackgroundNotification, object: nil)
        */
        
        /*
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
        */
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        self.forwardPropertiesToSublabel()
    }
    
    private func forwardPropertiesToSublabel() {
        // Since we're a UILabel, we actually do implement all of UILabel's properties.
        // We don't care about these values, we just want to forward them on to our sublabel.
        let properties = ["baselineAdjustment", "enabled", "font",
                          "highlighted", "highlightedTextColor", "minimumFontSize",
                          "shadowColor", "shadowOffset", "textAlignment", "textColor",
                          "userInteractionEnabled", "text", "adjustsFontSizeToFitWidth",
                          "lineBreakMode", "numberOfLines", "backgroundColor"]
        
        // Iterate through properties
        for prop in properties {
            let value: AnyObject! = super.valueForKey(prop)
            self.sublabel.setValue(value, forKeyPath: prop)
        }
        
        // Get text
        self.attributedText = super.attributedText
        
        // Clear super text, in the case of IB-created labels, to prevent double-drawing
        super.attributedText = nil
    }
    
    //
    // MARK: - MarqueeLabel Heavy Lifting
    //

    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.updateAndScroll(!self.orientationWillChange)
    }

    override public func willMoveToWindow(newWindow: UIWindow?) {
        if newWindow == nil {
            self.shutdownLabel()
        }
    }
    
    override public func didMoveToWindow() {
        if self.window != nil {
            self.updateAndScroll(!self.orientationWillChange)
        }
    }
    
    private func updateAndScroll() {
        self.updateAndScroll(!self.orientationWillChange)
    }
    
    private func updateAndScroll(beginScroll: Bool) {
        // Check if scrolling can occur
        if !self.labelReadyForScroll() {
            return
        }
        
        // Calculate expected size
        let expectedLabelSize = self.sublabelSize()
        
        // Invalidate intrinsic size
        self.invalidateIntrinsicContentSize()
        
        // Move label to home
        self.returnLabelToHome()
        
        // Configure gradient for current condition
        self.applyGradientMask(self.fadeLength, animated: true)
        
        // Check if label should scroll
        // Note that the holdScrolling propery does not affect this
        if !self.labelShouldScroll() {
            // Set text alignment and break mode to act like a normal label
            self.sublabel.textAlignment = super.textAlignment
            self.sublabel.lineBreakMode = super.lineBreakMode
            
            let labelFrame = CGRectIntegral(CGRect(x: 0.0, y: 0.0, width: self.bounds.size.width, height: expectedLabelSize.height))
            
            self.homeLabelFrame = labelFrame
            self.awayLabelFrame = labelFrame
            
            // Remove an additional sublabels (for continuous types)
            self.removeSecondarySublabels()
            
            // Set the sublabel frame to own bounds
            self.sublabel.frame = self.bounds
            
            return
        }
        
        switch self.type {
        case .Continuous:
            self.homeLabelFrame = CGRectIntegral(CGRectMake(0.0, 0.0, expectedLabelSize.width, expectedLabelSize.height))
            let awayLabelOffset: CGFloat = -(self.homeLabelFrame.size.width + self.fadeLength + self.continuousMarqueeExtraBuffer)
            self.awayLabelFrame = CGRectIntegral(CGRectOffset(self.homeLabelFrame, awayLabelOffset, 0.0))
            
            var sublabels = self.allSublabels()
            if (sublabels.count < 2) {
                let secondSublabel = UILabel(frame: CGRectOffset(self.homeLabelFrame, -awayLabelOffset, 0.0))
                secondSublabel.tag = 701;
                secondSublabel.numberOfLines = 1;
                secondSublabel.layer.anchorPoint = CGPointMake(0.0, 0.0);
                self.addSubview(secondSublabel)
                sublabels.append(secondSublabel)
            }
            self.refreshSublabels(sublabels)
            
            // Recompute the animation duration
            self.animationDuration = {
                if let rate = self.scrollRate {
                    return NSTimeInterval(fabs(awayLabelOffset) / rate)
                } else {
                    return self.scrollDuration ?? 7.0
                }
            }()

            self.sublabel.frame = self.homeLabelFrame
        
        case .ContinuousReverse:
            self.homeLabelFrame = CGRectIntegral(CGRectMake(self.bounds.size.width - expectedLabelSize.width, 0.0, expectedLabelSize.width, expectedLabelSize.height))
            let awayLabelOffset: CGFloat = (self.homeLabelFrame.size.width + self.fadeLength + self.continuousMarqueeExtraBuffer)
            self.awayLabelFrame = CGRectIntegral(CGRectOffset(self.homeLabelFrame, awayLabelOffset, 0.0))
            
            var sublabels = self.allSublabels()
            if (sublabels.count < 2) {
                let secondSublabel = UILabel(frame: CGRectOffset(self.homeLabelFrame, -awayLabelOffset, 0.0))
                secondSublabel.tag = 701;
                secondSublabel.numberOfLines = 1;
                secondSublabel.layer.anchorPoint = CGPointMake(0.0, 0.0)
                self.addSubview(secondSublabel)
                sublabels.append(secondSublabel)
            }
            self.refreshSublabels(sublabels)
            
            // Recompute the animation duration
            self.animationDuration = {
                if let rate = self.scrollRate {
                    return NSTimeInterval(fabs(awayLabelOffset) / rate)
                } else {
                    return self.scrollDuration ?? 7.0
                }
                }()
            
            self.sublabel.frame = self.homeLabelFrame
        
        case .RightLeft:
            self.homeLabelFrame = CGRectIntegral(CGRectMake(self.bounds.size.width - expectedLabelSize.width, 0.0, expectedLabelSize.width, expectedLabelSize.height))
            self.awayLabelFrame = CGRectIntegral(CGRectMake(self.fadeLength, 0.0, expectedLabelSize.width, expectedLabelSize.height))
            
            // Recompute the animation duration
            self.animationDuration = {
                if let rate = self.scrollRate {
                    return NSTimeInterval(fabs(self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x) / rate)
                } else {
                    return self.scrollDuration ?? 7.0
                }
                }()
            
            // Set frame and text
            self.sublabel.frame = self.homeLabelFrame
            
            // Enforce text alignment for this type
            self.sublabel.textAlignment = NSTextAlignment.Right
            
        case .LeftRight:
            self.homeLabelFrame = CGRectIntegral(CGRectMake(0.0, 0.0, expectedLabelSize.width, expectedLabelSize.height))
            self.awayLabelFrame = CGRectIntegral(CGRectOffset(self.homeLabelFrame, -expectedLabelSize.width + (self.bounds.size.width - self.fadeLength), 0.0))
            
            // Recompute the animation duration
            self.animationDuration = {
                if let rate = self.scrollRate {
                    return NSTimeInterval(fabs(self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x) / rate)
                } else {
                    return self.scrollDuration ?? 7.0
                }
                }()
            
            // Set frame and text
            self.sublabel.frame = self.homeLabelFrame
            
            // Enforce text alignment for this type
            self.sublabel.textAlignment = NSTextAlignment.Left
            
        default:
            // Something strange happened!
            self.homeLabelFrame = CGRect.zeroRect
            self.awayLabelFrame = CGRect.zeroRect
            
            // Do not attempt to scroll
            return
        }
        
        if !self.tapToScroll && !self.holdScrolling && beginScroll {
            self.beginScroll()
        }
    }
    
    func sublabelSize() -> CGSize {
        // Bound the expected size
        let maximumLabelSize = CGSizeMake(CGFloat.max, CGFloat.max)
        
        // Calculate the expected size
        var expectedLabelSize: CGSize
        if let text = self.sublabel.attributedText? {
            expectedLabelSize = text.boundingRectWithSize(maximumLabelSize, options: NSStringDrawingOptions.UsesFontLeading, context: nil).size
        } else {
            expectedLabelSize = CGSize.zeroSize
        }
        //var expectedLabelSize = self.sublabel.attributedText?.boundingRectWithSize(maximumLabelSize, options: NSStringDrawingOptions.fromRaw(0)!, context: nil).size ?? CGSize.zeroSize
        expectedLabelSize.width = CGFloat(ceilf(Float(expectedLabelSize.width)))
        expectedLabelSize.height = self.bounds.size.height
        
        return expectedLabelSize
    }
    
    override public func sizeThatFits(size: CGSize) -> CGSize {
        var fitSize = self.sublabel.sizeThatFits(size)
        fitSize.width += 2.0 * self.fadeLength
        
        return fitSize
    }
    
    //
    // MARK: - Animation Handling
    //
    
    private func labelShouldScroll() -> Bool {
        // Check for nil string
        if self.sublabel.text == nil {
            return false
        }
        
        // Check for empty string
        if self.sublabel.text.isEmpty {
            return false
        }
        
        // Check if the label string fits
        let labelTooLarge = self.sublabelSize().width > self.bounds.size.width
        return (!self.labelize && labelTooLarge)
    }
    
    private func labelReadyForScroll() -> Bool {
        // Check if we have a superview
        if self.superview == nil {
            return false
        }
        
        // Check if we are attached to a window
        if self.window == nil {
            return false
        }
        
        // Check if our view controller is ready
        let viewController = self.firstAvailableViewController()
        if viewController != nil {
            if !viewController!.isViewLoaded() {
                return false
            }
        }
        
        return true
    }
    
    private func beginScroll() {
        self.beginScroll(true)
    }
    
    private func beginScroll(delay: Bool) {
        switch self.type {
        case .LeftRight, .RightLeft:
            self.scrollAway(self.animationDuration, delay: self.animationDelay)
        default:
            self.scrollContinuous(self.animationDuration, delay: self.animationDuration)
        }
    }
    
    private func returnLabelToHome() {
        // Remove any gradient animation
        self.layer.mask?.removeAllAnimations()
        
        // Remove all sublabel position animations
        for sl in self.allSublabels() {
            sl.layer.removeAllAnimations()
        }
    }
    
    private func awayFromHome() -> Bool {
        if let presentationLayer = self.sublabel.layer.presentationLayer() as? CALayer {
            return !(presentationLayer.position.x == self.homeLabelFrame.origin.x)
        }
        
        return false
    }
    
    private func scroll(interval: NSTimeInterval,
                        delay: NSTimeInterval = 0.0,
                        scroller: (interval: NSTimeInterval, delay: NSTimeInterval) -> (),
                        callback: MarqueeLabel -> (interval: NSTimeInterval, delay: NSTimeInterval) -> ()) {
        // Check for conditions which would prevent scrolling
        if !self.labelReadyForScroll() {
            return
        }
        
        // Remove any animations
        self.sublabel.layer.removeAllAnimations()
        self.layer.mask?.removeAllAnimations()
        
        // Call pre-animation hook
        self.labelWillBeginScroll()
        
        // Start animation transactions
        CATransaction.begin()
        CATransaction.setAnimationDuration(interval)
        
        // Create gradient animation, if needed
        if self.fadeLength != 0.0 {
            let gradientAnimation = self.keyFrameAnimationForGradient(self.fadeLength, interval: interval, delay: delay)
            self.layer.mask.addAnimation(gradientAnimation, forKey: "gradient")
        }
        
        
        CATransaction.setCompletionBlock { () -> Void in
            // Call returned home method
            self.labelReturnedToHome(true)
            // Check to ensure that:
            // 1) We don't double fire if an animation already exists
            // 2) The instance is still attached to a window - this completion block is called for
            //    many reasons, including if the animation is removed due to the view being removed
            //    from the UIWindow (typically when the view controller is no longer the "top" view)
            if (self.window != nil && self.sublabel.layer.animationForKey("position") == nil) {
                // Begin again, if conditions met
                if (self.labelShouldScroll() && !self.tapToScroll && !self.holdScrolling) {
                    // Perform callback
                    callback(self)(interval: interval, delay: delay)
                }
            }
        }
        
        
        // Call scroller
        scroller(interval: interval, delay: delay)
        
        CATransaction.commit()
    }
    
    private func scrollAway(interval: NSTimeInterval, delay: NSTimeInterval = 0.0) {
        // Create scroller, which defines the animation to perform
        let scroller = { (interval: NSTimeInterval, delay: NSTimeInterval) -> () in
            // Create animation for position
            let values: [NSValue] = [
                NSValue(CGPoint: self.homeLabelFrame.origin),
                NSValue(CGPoint: self.homeLabelFrame.origin),
                NSValue(CGPoint: self.awayLabelFrame.origin),
                NSValue(CGPoint: self.awayLabelFrame.origin),
                NSValue(CGPoint: self.homeLabelFrame.origin)
            ]
            
            let awayAnimation = self.keyFrameAnimationForProperty("position", values: values, interval: interval, delay: delay)
            self.sublabel.layer.addAnimation(awayAnimation, forKey: "position")
        }
        
        // Create curried function for callback
        let callback = MarqueeLabel.scrollAway
        
        // Scroll
        self.scroll(interval, delay: delay, scroller: scroller, callback: callback)
    }

    
    private func scrollContinuous(interval: NSTimeInterval, delay: NSTimeInterval) {
        let scroller = { (interval: NSTimeInterval, delay: NSTimeInterval) -> () in
            // Create animation for positions
            var offset: CGFloat = 0.0
            for sl in self.allSublabels() {
                // Create values, bumped by the offset
                let values: [NSValue] = [
                    NSValue(CGPoint: self.offsetCGPoint(self.homeLabelFrame.origin, offset: offset)),
                    NSValue(CGPoint: self.offsetCGPoint(self.homeLabelFrame.origin, offset: offset)),
                    NSValue(CGPoint: self.offsetCGPoint(self.awayLabelFrame.origin, offset: offset))
                ]
                
                // Generate animation
                let awayAnimation = self.keyFrameAnimationForProperty("position", values: values, interval: interval, delay: delay)
                sl.layer.addAnimation(awayAnimation, forKey: "position")
                
                // Increment offset
                offset += (self.type == .ContinuousReverse ? -1.0 : 1.0) * (self.homeLabelFrame.size.width + self.fadeLength + self.continuousMarqueeExtraBuffer)
            }
        }
        
        let callback = MarqueeLabel.scrollContinuous
        
        self.scroll(interval, delay: delay, scroller: scroller, callback: callback)
    }
    
    private func applyGradientMask(fadeLength: CGFloat, animated: Bool) {
        // Check for zero-length fade
        if (fadeLength <= 0.0) {
            self.removeGradientMask()
            return
        }
        
        let gradientMask = self.layer.mask as CAGradientLayer? ?? CAGradientLayer()

        // Remove any in flight animations
        gradientMask.removeAllAnimations()
        
        gradientMask.bounds = self.layer.bounds;
        gradientMask.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds))
        gradientMask.shouldRasterize = true
        gradientMask.rasterizationScale = UIScreen.mainScreen().scale
        //gradientMask.colors = self.gradientColors
        gradientMask.startPoint = CGPointMake(0.0, CGRectGetMidY(self.frame))
        gradientMask.endPoint = CGPointMake(1.0, CGRectGetMidY(self.frame))
        // Start with default (no fade) locations
        gradientMask.locations = [0.0, 0.0, 1.0, 1.0]
        
        // Set mask
        self.layer.mask = gradientMask
        
        var leadingFadeLength: CGFloat = 0.0
        var trailingFadeLength: CGFloat = fadeLength
        
        // No fade if labelized, or if no scrolling is needed
        if (self.labelize || !self.labelShouldScroll()) {
            leadingFadeLength = 0.0
            trailingFadeLength = 0.0
        }
        
        var leftFadeLength, rightFadeLength: CGFloat
        switch (self.type) {
        case .ContinuousReverse, .RightLeft:
            leftFadeLength = trailingFadeLength
            rightFadeLength = leadingFadeLength
        
        // .MLContinuous, .MLLeftRight
        default:
            leftFadeLength = leadingFadeLength;
            rightFadeLength = trailingFadeLength;
            break;
        }
        
        let leftFadePoint: CGFloat = leftFadeLength/self.bounds.size.width;
        let rightFadePoint: CGFloat = rightFadeLength/self.bounds.size.width;
        
        let adjustedLocations = [0.0, leftFadePoint, 1.0 - rightFadePoint, 1.0]
        if (animated) {
            // Create animation for gradient change
            let animation = CABasicAnimation(keyPath: "locations")
            animation.fromValue = gradientMask.locations;
            animation.toValue = adjustedLocations;
            animation.duration = 0.25;
            
            gradientMask.addAnimation(animation, forKey: animation.keyPath)
            gradientMask.locations = adjustedLocations;
        } else {
            CATransaction.begin()
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            gradientMask.locations = adjustedLocations;
            CATransaction.commit()
        }
    }
    
    private func removeGradientMask() {
        self.layer.mask = nil
    }
    
    private func keyFrameAnimationForGradient(fadeLength: CGFloat, interval: NSTimeInterval, delay: NSTimeInterval) -> CAKeyframeAnimation {
        // Setup
        var values: [AnyObject]? = nil
        var keyTimes: [AnyObject]? = nil
        let fadeFraction = fadeLength/self.bounds.size.width
        
        // Create new animation
        let animation = CAKeyframeAnimation(keyPath: "locations")
        
        // Get timing function
        let timingFunction = self.timingFunctionForAnimationOptions(self.animationCurve)
        
        // Define keyTimes
        switch (self.type) {
        case .LeftRight, .RightLeft:
            // Calculate total animation duration
            let totalDuration = 2.0 * (delay + interval);
            keyTimes =
            [
                0.0,                                              // Initial gradient
                delay/totalDuration,                              // Begin of fade in
                (delay + 0.4)/totalDuration,                      // End of fade in, just as scroll away starts
                0.95 * totalDuration/totalDuration,               // Begin of fade out, just before scroll home completes
                1.0,                                              // End of fade out, as scroll home completes
                1.0                                               // Buffer final value (used on continuous types)
            ]
            
        // .MLContinuous, .MLContinuousReverse
        default:
            // Calculate total animation duration
            let totalDuration = delay + interval;
            
            // Find when the lead label will be totally offscreen
            let offsetDistance = (self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x);
            let startFadeFraction = fabs(self.sublabel.bounds.size.width / offsetDistance);
            // Find when the animation will hit that point
            let startFadeTimeFraction = timingFunction.durationPercentageForPositionPercentage(startFadeFraction, duration: totalDuration)
            let startFadeTime = delay + NSTimeInterval(startFadeTimeFraction) * interval;
            
            keyTimes = [
                0.0,                                        // Initial gradient
                delay/totalDuration,                        // Begin of fade in
                (delay + 0.2)/totalDuration,                // End of fade in, just as scroll away starts
                startFadeTime/totalDuration,                // Begin of fade out, just before scroll home completes
                (startFadeTime + 0.1)/totalDuration,        // End of fade out, as scroll home completes
                1.0                                         // Buffer final value (used on continuous types)
            ]
            break;
        }
        
        // Define values
        switch (self.type) {
        case .ContinuousReverse, .RightLeft:
            values = [
                [0.0, fadeFraction, 1.0, 1.0],                   // Initial gradient
                [0.0, fadeFraction, 1.0, 1.0],                   // Begin of fade in
                [0.0, fadeFraction, 1.0 - fadeFraction, 1.0],    // End of fade in, just as scroll away starts
                [0.0, fadeFraction, 1.0 - fadeFraction, 1.0],    // Begin of fade out, just before scroll home completes
                [0.0, fadeFraction, 1.0, 1.0],                   // End of fade out, as scroll home completes
                [0.0, fadeFraction, 1.0, 1.0]                    // Final "home" value
            ]
            break;
        
        // .MLContinuous, .MLLeftRight
        default:
            values = [
            [0.0, 0.0, 1.0 - fadeFraction, 1.0],            // Initial gradient
            [0.0, 0.0, 1.0 - fadeFraction, 1.0],            // Begin of fade in
            [0.0, fadeFraction, 1.0 - fadeFraction, 1.0],   // End of fade in, just as scroll away starts
            [0.0, fadeFraction, 1.0 - fadeFraction, 1.0],   // Begin of fade out, just before scroll home completes
            [0.0, 0.0, 1.0 - fadeFraction, 1.0],            // End of fade out, as scroll home completes
            [0.0, 0.0, 1.0 - fadeFraction, 1.0]             // Final "home" value
            ];
            break;
        }
        
        animation.values = values;
        animation.keyTimes = keyTimes;
        animation.timingFunctions = [timingFunction, timingFunction, timingFunction, timingFunction]
        
        return animation;
    }
    
    private func keyFrameAnimationForProperty(property: String, values: [NSValue], interval: NSTimeInterval, delay: NSTimeInterval) -> CAKeyframeAnimation {
        // Create new animation
        let animation = CAKeyframeAnimation(keyPath: property)
        
        // Get timing function
        let timingFunction = self.timingFunctionForAnimationOptions(self.animationCurve)
        
        // Calculate times based on marqueeType
        var totalDuration: NSTimeInterval = 0.0
        switch (self.type) {
        case .LeftRight, .RightLeft:
            //NSAssert(values.count == 5, @"Incorrect number of values passed for MLLeftRight-type animation");
            totalDuration = 2.0 * (delay + interval);
            // Set up keyTimes
            animation.keyTimes = [
                0.0,                                            // Initial location, home
                delay/totalDuration,                            // Initial delay, at home
                (delay + interval)/totalDuration,               // Animation to away
                (delay + interval + delay)/totalDuration,       // Delay at away
                1.0                                             // Animation to home
            ]
            
            animation.timingFunctions = [
                timingFunction,
                timingFunction,
                timingFunction,
                timingFunction
            ];
            
            // MLContinuous
            // MLContinuousReverse
        default:
            //NSAssert(values.count == 3, @"Incorrect number of values passed for MLContinous-type animation");
            totalDuration = delay + interval;
            // Set up keyTimes
            animation.keyTimes = [
                0.0,                        // Initial location, home
                delay/totalDuration,        // Initial delay, at home
                1.0                         // Animation to away
            ]
            
            animation.timingFunctions = [
                timingFunction,
                timingFunction
            ]
        }
        
        // Set values
        animation.values = values;
        
        return animation
    }
    
    private func timingFunctionForAnimationOptions(options: UIViewAnimationOptions) -> CAMediaTimingFunction {
        var timingFunction: NSString? = nil
        
        switch options {
        case UIViewAnimationOptions.CurveEaseIn:
            timingFunction = kCAMediaTimingFunctionEaseIn
        case UIViewAnimationOptions.CurveEaseInOut:
            timingFunction = kCAMediaTimingFunctionEaseInEaseOut
        case UIViewAnimationOptions.CurveEaseOut:
            timingFunction = kCAMediaTimingFunctionEaseOut
        default:
            timingFunction = kCAMediaTimingFunctionLinear
        }
        
        return CAMediaTimingFunction(name: timingFunction)
    }
    
    //
    // MARK: - Label Control
    //
    
    public func restartLabel() {
        self.applyGradientMask(self.fadeLength, animated: false)
        
        if self.labelShouldScroll() && !self.tapToScroll {
            self.beginScroll()
        }
    }
    
    public func resetLabel() {
        self.returnLabelToHome()
        self.homeLabelFrame = CGRect.nullRect
        self.awayLabelFrame = CGRect.nullRect
    }
    
    public func shutdownLabel() {
        self.returnLabelToHome()
    }
    
    public func pauseLabel() {
        // TODO: implement
    }
    
    public func unpauseLabel() {
        // TODO: implement
    }
    
    private func labelWasTapped(recognizer: UIGestureRecognizer) {
        if self.labelShouldScroll() {
            self.beginScroll(true)
        }
    }
    
    public func labelWillBeginScroll() {
        // Default implementation does nothing - override to customize
        return;
    }
    
    public func labelReturnedToHome(finished: Bool) {
        // Default implementation does nothing - override to customize
        return;
    }
    
    //
    // MARK: - Modified UILabel getter/setters
    //
    
    public override var text: String! {
        didSet {
            if text == oldValue {
                return
            }
            self.updateAndScroll()
        }
    }
    
    public override var attributedText: NSAttributedString! {
        didSet {
            if attributedText == oldValue {
                return
            }
            self.updateAndScroll()
        }
    }
    
    public override var font: UIFont! {
        get {
            return self.sublabel.font
        }
        
        set {
            if self.sublabel.font == newValue {
                return
            }
            self.sublabel.font = newValue
            self.updateAndScroll()
        }
    }
    
    public override var textColor: UIColor! {
        get {
            return self.sublabel.textColor
        }
        
        set {
            self.updateSublabelsForKey("textColor", value: newValue)
        }
    }
    
    public override var backgroundColor: UIColor? {
        get {
            return self.sublabel.backgroundColor
        }
        
        set {
            self.updateSublabelsForKey("backgroundColor", value: newValue)
        }
    }
    
    public override var shadowColor: UIColor! {
        get {
            return self.sublabel.shadowColor
        }
        
        set {
            self.updateSublabelsForKey("shadowColor", value: newValue)
        }
    }
    
    public override var highlightedTextColor: UIColor! {
        get {
            return self.sublabel.highlightedTextColor
        }
        
        set {
            self.updateSublabelsForKey("highlightedTextColor", value: newValue)
        }
    }
    
    public override var highlighted: Bool {
        get {
            return self.sublabel.highlighted
        }
        
        set {
            self.updateSublabelsForKey("highlighted", value: newValue)
        }
    }
    
    public override var enabled: Bool {
        get {
            return self.sublabel.enabled
        }
        
        set {
            self.updateSublabelsForKey("enabled", value: newValue)
        }
    }
    
    public override var numberOfLines: Int {
        get {
            return super.numberOfLines
        }
        
        set {
            // By the nature of MarqueeLabel, this is 1
            super.numberOfLines = 1
        }
    }
    
    public override var adjustsFontSizeToFitWidth: Bool {
        get {
            return super.adjustsFontSizeToFitWidth
        }
        
        set {
            // By the nature of MarqueeLabel, this is false
            self.adjustsFontSizeToFitWidth = false
        }
    }
    
    public override var minimumScaleFactor: CGFloat {
        get {
            return super.minimumScaleFactor
        }
        
        set {
            self.minimumScaleFactor = 0.0
        }
    }
    
    public override var baselineAdjustment: UIBaselineAdjustment {
        get {
            return self.sublabel.baselineAdjustment
        }
        
        set {
            self.updateSublabelsForKey("baselineAdjustment", value: newValue.toRaw())
        }
    }
    
    /*
    // TODO: Fix this?
    public override var adjustsFontSizeToFitWidth: Bool {
        get {
            return super.adjustsFontSizeToFitWidth
        }
        
        set {
            // By the nature of MarqueeLabel, this is NO
            self.adjustsFontSizeToFitWidth = false
        }
    }
    */
    
    public override func intrinsicContentSize() -> CGSize {
        return self.sublabel.intrinsicContentSize()
    }
    
    private func refreshSublabels(labels: [UILabel]) {
        for sl in labels {
            sl.attributedText = self.attributedText
            sl.backgroundColor = self.backgroundColor
            sl.shadowColor = self.shadowColor
            sl.shadowOffset = self.shadowOffset
            sl.textAlignment = self.textAlignment
        }
    }
    
    private func updateSublabelsForKey(key: String, value: AnyObject?) {
        for sl in self.allSublabels() {
            sl.setValue(value, forKeyPath: key)
        }
    }
    
    
    //
    // MARK: - Custom getter/setters
    //
    
    //
    // MARK: - Support
    //
    
    private func allSublabels() -> [UILabel] {
        let sublabels: [UILabel] = self.subviews.filter({ (sl: AnyObject) -> Bool in
            return sl.tag >= 700
        }) as [UILabel]
        
        return sublabels
    }
    
    private func removeSecondarySublabels() {
        for sl in self.allSublabels() {
            if sl != self.sublabel {
                sl.removeFromSuperview()
            }
        }
    }
    
    private func offsetCGPoint(point: CGPoint, offset: CGFloat) -> CGPoint {
        return CGPointMake(point.x + offset, point.y)
    }
    
    //
    // MARK: - Deinit
    //
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self.orientationObserver!)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
}


//
// MARK: - Support
//

private extension UIResponder {
    // Thanks to Phil M
    // http://stackoverflow.com/questions/1340434/get-to-uiviewcontroller-from-uiview-on-iphone
    
    func firstAvailableViewController() -> UIViewController? {
        // convenience function for casting and to "mask" the recursive function
        return self.traverseResponderChainForFirstViewController() as UIViewController?
    }
    
    func traverseResponderChainForFirstViewController() -> AnyObject? {
        let nextResponder = self.nextResponder()
        if nextResponder != nil {
            if nextResponder.isKindOfClass(UIViewController) {
                return nextResponder
            } else if (nextResponder.isKindOfClass(UIView)) {
                return nextResponder.traverseResponderChainForFirstViewController()
            } else {
                return nil;
            }
        }
        return nil
    }
}


private extension CAMediaTimingFunction {
    
    func durationPercentageForPositionPercentage(positionPercentage: CGFloat, duration: NSTimeInterval) -> CGFloat {
        // Finds the animation duration percentage that corresponds with the given animation "position" percentage.
        // Utilizes Newton's Method to solve for the parametric Bezier curve that is used by CAMediaAnimation.
        
        let controlPoints = self.controlPoints()
        let epsilon: CGFloat = 1.0 / (100.0 * CGFloat(duration))
        
        // Find the t value that gives the position percentage we want
        let t_found = self.solveTforY(positionPercentage, epsilon: epsilon, controlPoints: controlPoints)
        
        // With that t, find the corresponding animation percentage
        let durationPercentage = self.XforCurveAt(t_found, controlPoints: controlPoints)
        
        return durationPercentage;
    }
    
    func solveTforY(y_0: CGFloat, epsilon: CGFloat, controlPoints: [CGPoint]) -> CGFloat {
        // Use Newton's Method: http://en.wikipedia.org/wiki/Newton's_method
        // For first guess, use t = y (i.e. if curve were linear)
        var t0 = y_0
        var t1 = y_0
        var f0, df0: CGFloat
        
        for (var i = 0; i < 15; i++) {
            // Base this iteration of t1 calculated from last iteration
            t0 = t1;
            // Calculate f(t0)
            f0 = self.YforCurveAt(t0, controlPoints: controlPoints)
            // Check if this is close (enough)
            if (fabs(f0) < epsilon) {
                // Done!
                return t0;
            }
            // Else continue Newton's Method
            df0 = self.derivativeCurveYValueAt(t0, controlPoints: controlPoints)
            // Check if derivative is small or zero ( http://en.wikipedia.org/wiki/Newton's_method#Failure_analysis )
            if (fabs(df0) < 1e-6) {
                break;
            }
            // Else recalculate t1
            t1 = t0 - f0/df0;
        }
        
        // Give up - shouldn't ever get here...I hope
        println("MarqueeLabel: Failed to find t for Y input!")
        return t0;
    }
    
    func YforCurveAt(t: CGFloat, controlPoints:[CGPoint]) -> CGFloat {
        let P0 = controlPoints[0]
        let P1 = controlPoints[1]
        let P2 = controlPoints[2]
        let P3 = controlPoints[3]
        
        // Per http://en.wikipedia.org/wiki/Bezier_curve#Cubic_B.C3.A9zier_curves
        let y0 = pow(1.0 - t, 3.0) * P0.y
        let y1 = 3.0 * pow(1.0 - t, 2) * t * P1.y
        let y2 = 3.0 * (1.0 - t) * pow(t, 2.0) * P2.y
        let y3 = pow(t, 3.0) * P3.y
        
        return y0 + y1 + y2 + y3
    }
    
    func XforCurveAt(t: CGFloat, controlPoints: [CGPoint]) -> CGFloat {
        let P0 = controlPoints[0]
        let P1 = controlPoints[1]
        let P2 = controlPoints[2]
        let P3 = controlPoints[3]
        
        // Per http://en.wikipedia.org/wiki/Bezier_curve#Cubic_B.C3.A9zier_curves
        
        let x0 = pow((1.0 - t),3.0) * P0.x
        let x1 = 3.0 * pow(1.0 - t, 2.0) * t * P1.x
        let x2 = 3.0 * (1.0 - t) * pow(t, 2.0) * P2.x
        let x3 = pow(t, 3.0) * P3.x
        
        return x0 + x1 + x2 + x3
    }
    
    func derivativeCurveYValueAt(t: CGFloat, controlPoints: [CGPoint]) -> CGFloat {
        let P0 = controlPoints[0]
        let P1 = controlPoints[1]
        let P2 = controlPoints[2]
        let P3 = controlPoints[3]
        
        let dy1: CGFloat = pow(t, 3.0) * ((3.0 * P0.y) - (9.0 * (P1.y + P2.y) + 3.0 * P3.y))
        let dy2: CGFloat = t * 6.0 * (P0.y + P2.y)
        let dy3: CGFloat = -3.0 * P0.y + 3.0 * P1.y
        
        return dy1 + dy2 + dy3
    }
    
    func controlPoints() -> [CGPoint] {
        // Create point array to point to
        var point: [Float] = [0.0, 0.0]
        var pointArray = [CGPoint]()
        for (var i: UInt = 0; i <= 3; i++) {
            self.getControlPointAtIndex(i, values: &point)
            pointArray.append(CGPoint(x: CGFloat(point[0]), y: CGFloat(point[1])))
        }
        
        return pointArray
    }
}
