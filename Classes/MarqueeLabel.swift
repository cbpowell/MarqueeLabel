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
            removeSecondarySublabels()
        }
    }
    
    public var animationCurve: UIViewAnimationCurve = .Linear
    
    public var labelize: Bool = false {
        didSet {
            if labelize != oldValue {
                updateAndScroll(true)
            }
        }
    }
    
    public var holdScrolling: Bool = false {
        didSet {
            if holdScrolling != oldValue {
                if oldValue == true && !awayFromHome() {
                    beginScroll()
                }
            }
        }
    }
    
    public var tapToScroll: Bool = false {
        didSet {
            if tapToScroll != oldValue {
                if tapToScroll {
                    let tapRecognizer = UITapGestureRecognizer(target: self, action: "labelWasTapped:")
                    self.addGestureRecognizer(tapRecognizer)
                    userInteractionEnabled = true
                } else {
                    if let recognizer = self.gestureRecognizers.first as UIGestureRecognizer? {
                        self.removeGestureRecognizer(recognizer)
                    }
                    userInteractionEnabled = false
                }
            }
        }
    }
    
    public var isPaused: Bool {
        return (sublabel.layer.speed == 0.0)
    }
    
    public var scrollDuration: NSTimeInterval? = 7.0 {
        didSet {
            if scrollDuration != oldValue {
                scrollRate = nil
                updateAndScroll()
            }
        }
    }
    
    public var scrollRate: CGFloat? = nil {
        didSet {
            if scrollRate != oldValue {
                scrollDuration = nil
                updateAndScroll()
            }
        }
    }
    
    public var continuousExtraBuffer: CGFloat = 0.0 {
        didSet {
            if continuousExtraBuffer != oldValue {
                updateAndScroll()
            }
        }
    }
    
    public var fadeLength: CGFloat = 0.0 {
        didSet {
            if fadeLength != oldValue {
                applyGradientMask(fadeLength, animated: true)
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
    private var animationDuration: NSTimeInterval = 0.0

    private var homeLabelFrame: CGRect = CGRect.zeroRect
    private var awayLabelFrame: CGRect = CGRect.zeroRect
    

    //
    // MARK: - Class Functions and Helpers
    //

    class func restartLabelsOfController(controller: UIViewController) {
        MarqueeLabel.notifyController(controller, message: .Restart)
    }
    
    class func controllerViewWillAppear(controller: UIViewController) {
        MarqueeLabel.restartLabelsOfController(controller)
    }
    
    class func controllerViewDidAppear(controller: UIViewController) {
        MarqueeLabel.restartLabelsOfController(controller)
    }
    
    class func controllerLabelsLabelize(controller: UIViewController) {
        MarqueeLabel.notifyController(controller, message: .Labelize)
    }


    class func controllerLabelsAnimate(controller: UIViewController) {
        MarqueeLabel.notifyController(controller, message: .Animate)
    }


    class private func notifyController(controller: UIViewController, message: ControllerNotifications) {
        NSNotificationCenter.defaultCenter().postNotificationName(message.toRaw(), object: nil, userInfo: [controller : "controller"])
    }
    
    private func restartForViewController(notification: NSNotification) {
        if let controller = notification.userInfo?["controller"] as? UIViewController {
            if controller === self.firstAvailableViewController() {
                self.restartLabel()
            }
        }
    }
    
    private func labelizeForController(notification: NSNotification) {
        if let controller = notification.userInfo?["controller"] as? UIViewController {
            if controller === self.firstAvailableViewController() {
                self.labelize = true
            }
        }
    }
    
    private func animateForController(notification: NSNotification) {
        if let controller = notification.userInfo?["controller"] as? UIViewController {
            if controller === self.firstAvailableViewController() {
                self.labelize = false
            }
        }
    }
    
    private func observedViewControllerChange(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            let fromController = userInfo["UINavigationControllerLastVisibleViewController"] as? UIViewController
            let toController = userInfo["UINavigationControllerNextVisibleViewController"] as? UIViewController
            
            if let ownController = self.firstAvailableViewController() {
                if let fromController = fromController {
                    if ownController === fromController {
                        shutdownLabel()
                    }
                }
                if let fromController = fromController {
                    if ownController === fromController {
                        restartLabel()
                    }
                }
            }
        }
    }
    
    
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
        sublabel = UILabel(frame: self.bounds)
        sublabel.tag = 700
        sublabel.layer.anchorPoint = CGPoint.zeroPoint

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
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "observedViewControllerChange:", name:"UINavigationControllerDidShowViewControllerNotification", object:nil)
        
        // UIApplication state notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "restartLabel", name: UIApplicationDidBecomeActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "shutdownLabel", name: UIApplicationDidEnterBackgroundNotification, object: nil)
        
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
        
        __weak __typeof(&*self)weakSelf = self
        
        __block id animationObserver = nil
        self.orientationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillChangeStatusBarOrientationNotification
            object:nil
            queue:nil
            usingBlock:^(NSNotification *notification){
            weakSelf.orientationWillChange = YES
            [weakSelf returnLabelToOriginImmediately]
            animationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"UIViewAnimationDidStopNotification"
            object:nil
            queue:nil
            usingBlock:^(NSNotification *notification){
            if ([notification.userInfo objectForKey:@"delegate"] == weakSelf.window) {
            weakSelf.orientationWillChange = NO
            [weakSelf restartLabel]
            
            // Remove notification observer
            [[NSNotificationCenter defaultCenter] removeObserver:animationObserver]
            }
            }]
            }]
        */
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        forwardPropertiesToSublabel()
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
            sublabel.setValue(value, forKeyPath: prop)
        }
        
        // Get text
        attributedText = super.attributedText
    }
    
    //
    // MARK: - MarqueeLabel Heavy Lifting
    //

    override public func layoutSubviews() {
        super.layoutSubviews()
        
        updateAndScroll(!self.orientationWillChange)
    }

    override public func willMoveToWindow(newWindow: UIWindow?) {
        if newWindow == nil {
            shutdownLabel()
        }
    }
    
    override public func didMoveToWindow() {
        if self.window != nil {
            updateAndScroll(!self.orientationWillChange)
        }
    }
    
    private func updateAndScroll() {
        updateAndScroll(!self.orientationWillChange)
    }
    
    private func updateAndScroll(shouldBeginScroll: Bool) {
        // Check if scrolling can occur
        if !labelReadyForScroll() {
            return
        }
        
        // Calculate expected size
        let expectedLabelSize = sublabelSize()
        
        // Invalidate intrinsic size
        invalidateIntrinsicContentSize()
        
        // Move label to home
        returnLabelToHome()
        
        // Configure gradient for current condition
        applyGradientMask(fadeLength, animated: true)
        
        // Check if label should scroll
        // Note that the holdScrolling propery does not affect this
        if !labelShouldScroll() {
            // Set text alignment and break mode to act like a normal label
            sublabel.textAlignment = super.textAlignment
            sublabel.lineBreakMode = super.lineBreakMode
            
            let labelFrame = CGRectIntegral(CGRect(x: 0.0, y: 0.0, width: self.bounds.size.width, height: expectedLabelSize.height))
            
            homeLabelFrame = labelFrame
            awayLabelFrame = labelFrame
            
            // Remove an additional sublabels (for continuous types)
            removeSecondarySublabels()
            
            // Set the sublabel frame to own bounds
            sublabel.frame = self.bounds
            
            return
        }
        
        switch self.type {
        case .Continuous:
            homeLabelFrame = CGRectIntegral(CGRectMake(0.0, 0.0, expectedLabelSize.width, expectedLabelSize.height))
            let awayLabelOffset: CGFloat = -(homeLabelFrame.size.width + fadeLength + continuousExtraBuffer)
            awayLabelFrame = CGRectIntegral(CGRectOffset(homeLabelFrame, awayLabelOffset, 0.0))
            
            var sublabels = allSublabels()
            if (sublabels.count < 2) {
                let sublabelFrame = CGRectIntegral(CGRectOffset(homeLabelFrame, -awayLabelOffset, 0.0))
                let secondSublabel = UILabel(frame: sublabelFrame)
                secondSublabel.tag = 701
                secondSublabel.numberOfLines = 1
                secondSublabel.layer.anchorPoint = CGPointMake(0.0, 0.0)
                self.addSubview(secondSublabel)
                sublabels.append(secondSublabel)
            }
            refreshSublabels(sublabels)
            
            // Recompute the animation duration
            animationDuration = {
                if let rate = self.scrollRate {
                    return NSTimeInterval(fabs(awayLabelOffset) / rate)
                } else {
                    return self.scrollDuration ?? 7.0
                }
            }()

            sublabel.frame = homeLabelFrame
        
        case .ContinuousReverse:
            homeLabelFrame = CGRectIntegral(CGRectMake(self.bounds.size.width - expectedLabelSize.width, 0.0, expectedLabelSize.width, expectedLabelSize.height))
            let awayLabelOffset: CGFloat = (homeLabelFrame.size.width + fadeLength + continuousExtraBuffer)
            awayLabelFrame = CGRectIntegral(CGRectOffset(homeLabelFrame, awayLabelOffset, 0.0))
            
            var sublabels = allSublabels()
            if (sublabels.count < 2) {
                let secondSublabel = UILabel(frame: CGRectOffset(homeLabelFrame, -awayLabelOffset, 0.0))
                secondSublabel.tag = 701
                secondSublabel.numberOfLines = 1
                secondSublabel.layer.anchorPoint = CGPointMake(0.0, 0.0)
                self.addSubview(secondSublabel)
                sublabels.append(secondSublabel)
            }
            refreshSublabels(sublabels)
            
            // Recompute the animation duration
            animationDuration = {
                if let rate = self.scrollRate {
                    return NSTimeInterval(fabs(awayLabelOffset) / rate)
                } else {
                    return self.scrollDuration ?? 7.0
                }
                }()
            
            sublabel.frame = homeLabelFrame
        
        case .RightLeft:
            homeLabelFrame = CGRectIntegral(CGRectMake(self.bounds.size.width - expectedLabelSize.width, 0.0, expectedLabelSize.width, expectedLabelSize.height))
            awayLabelFrame = CGRectIntegral(CGRectMake(fadeLength, 0.0, expectedLabelSize.width, expectedLabelSize.height))
            
            // Recompute the animation duration
            animationDuration = {
                if let rate = self.scrollRate {
                    return NSTimeInterval(fabs(self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x) / rate)
                } else {
                    return self.scrollDuration ?? 7.0
                }
                }()
            
            // Set frame and text
            sublabel.frame = homeLabelFrame
            
            // Enforce text alignment for this type
            sublabel.textAlignment = NSTextAlignment.Right
            
        case .LeftRight:
            homeLabelFrame = CGRectIntegral(CGRectMake(0.0, 0.0, expectedLabelSize.width, expectedLabelSize.height))
            awayLabelFrame = CGRectIntegral(CGRectOffset(homeLabelFrame, -expectedLabelSize.width + (self.bounds.size.width - fadeLength), 0.0))
            
            // Recompute the animation duration
            animationDuration = {
                if let rate = self.scrollRate {
                    return NSTimeInterval(fabs(self.awayLabelFrame.origin.x - self.homeLabelFrame.origin.x) / rate)
                } else {
                    return self.scrollDuration ?? 7.0
                }
                }()
            
            // Set frame and text
            sublabel.frame = homeLabelFrame
            
            // Enforce text alignment for this type
            sublabel.textAlignment = NSTextAlignment.Left
            
        default:
            // Something strange happened!
            homeLabelFrame = CGRect.zeroRect
            awayLabelFrame = CGRect.zeroRect
            
            // Do not attempt to scroll
            return
        }
        
        if !tapToScroll && !holdScrolling && shouldBeginScroll {
            beginScroll()
        }
    }
    
    func sublabelSize() -> CGSize {
        // Bound the expected size
        let maximumLabelSize = CGSizeMake(CGFloat.max, CGFloat.max)
        
        // Calculate the expected size
        var expectedLabelSize: CGSize
        if let text = sublabel.attributedText? {
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
        var fitSize = sublabel.sizeThatFits(size)
        fitSize.width += 2.0 * fadeLength
        
        return fitSize
    }
    
    //
    // MARK: - Animation Handling
    //
    
    private func labelShouldScroll() -> Bool {
        // Check for nil string
        if sublabel.text == nil {
            return false
        }
        
        // Check for empty string
        if sublabel.text.isEmpty {
            return false
        }
        
        // Check if the label string fits
        let labelTooLarge = sublabelSize().width > self.bounds.size.width
        return (!labelize && labelTooLarge)
    }
    
    private func labelReadyForScroll() -> Bool {
        // Check if we have a superview
        if superview == nil {
            return false
        }
        
        // Check if we are attached to a window
        if window == nil {
            return false
        }
        
        // Check if our view controller is ready
        let viewController = firstAvailableViewController()
        if viewController != nil {
            if !viewController!.isViewLoaded() {
                return false
            }
        }
        
        // Check if application is in active state
        // Prevents CATransaction completionBlock (which does not receive a "finished" parameter
        // like UIView animations) from looping when the application has been backgrounded
        if UIApplication.sharedApplication().applicationState != .Active {
            return false
        }
        
        return true
    }
    
    private func beginScroll() {
        beginScroll(true)
    }
    
    private func beginScroll(delay: Bool) {
        switch self.type {
        case .LeftRight, .RightLeft:
            scrollAway(animationDuration, delay: animationDelay)
        default:
            scrollContinuous(animationDuration, delay: animationDelay)
        }
    }
    
    private func returnLabelToHome() {
        // Remove any gradient animation
        self.layer.mask?.removeAllAnimations()
        
        // Remove all sublabel position animations
        for sl in allSublabels() {
            sl.layer.removeAllAnimations()
        }
    }
    
    private func awayFromHome() -> Bool {
        if let presentationLayer = sublabel.layer.presentationLayer() as? CALayer {
            return !(presentationLayer.position.x == homeLabelFrame.origin.x)
        }
        
        return false
    }
    
    private func scroll(interval: NSTimeInterval,
                        delay: NSTimeInterval = 0.0,
                        scroller: (interval: NSTimeInterval, delay: NSTimeInterval) -> (),
                        callback: MarqueeLabel -> (interval: NSTimeInterval, delay: NSTimeInterval) -> ()) {
        // Check for conditions which would prevent scrolling
        if !labelReadyForScroll() {
            return
        }
        
        // Remove any animations
        sublabel.layer.removeAllAnimations()
        self.layer.mask?.removeAllAnimations()
        
        // Call pre-animation hook
        labelWillBeginScroll()
        
        // Start animation transactions
        CATransaction.begin()
        CATransaction.setAnimationDuration(interval)
        
        // Create gradient animation, if needed
        if fadeLength != 0.0 {
            let gradientAnimation = keyFrameAnimationForGradient(fadeLength, interval: interval, delay: delay)
            self.layer.mask.addAnimation(gradientAnimation, forKey: "gradient")
        }
        
        
        CATransaction.setCompletionBlock { () -> Void in
            // Call returned home function
            self.labelReturnedToHome(true)
            // Check to ensure that:
            // 1) We don't double fire if an animation already exists
            // 2) The instance is still attached to a window - this completion block is called for
            //    many reasons, including if the animation is removed due to the view being removed
            //    from the UIWindow (typically when the view controller is no longer the "top" view)
            if (self.window != nil && self.sublabel.layer.animationForKey("position") == nil) {
                // Begin again, if conditions met
                if (self.labelShouldScroll() && !self.tapToScroll && !self.holdScrolling) {
                    // Perform completion callback
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
                offset += (self.type == .ContinuousReverse ? -1.0 : 1.0) * (self.homeLabelFrame.size.width + self.fadeLength + self.continuousExtraBuffer)
            }
        }
        
        let callback = MarqueeLabel.scrollContinuous
        
        self.scroll(interval, delay: delay, scroller: scroller, callback: callback)
    }
    
    private func applyGradientMask(fadeLength: CGFloat, animated: Bool) {
        // Check for zero-length fade
        if (fadeLength <= 0.0) {
            removeGradientMask()
            return
        }
        
        let gradientMask = self.layer.mask as CAGradientLayer? ?? CAGradientLayer()

        // Remove any in flight animations
        gradientMask.removeAllAnimations()
        
        gradientMask.bounds = self.layer.bounds
        gradientMask.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds))
        gradientMask.shouldRasterize = true
        gradientMask.rasterizationScale = UIScreen.mainScreen().scale
        let colors: [AnyObject] = [UIColor.clearColor().CGColor, UIColor.blackColor().CGColor, UIColor.blackColor().CGColor, UIColor.clearColor().CGColor]
        gradientMask.colors = colors;
        gradientMask.startPoint = CGPointMake(0.0, CGRectGetMidY(self.frame))
        gradientMask.endPoint = CGPointMake(1.0, CGRectGetMidY(self.frame))
        // Start with default (no fade) locations
        gradientMask.locations = [0.0, 0.0, 1.0, 1.0]
        
        // Set mask
        self.layer.mask = gradientMask
        
        var leadingFadeLength: CGFloat = 0.0
        var trailingFadeLength: CGFloat = fadeLength
        
        // No fade if labelized, or if no scrolling is needed
        if (labelize || !labelShouldScroll()) {
            leadingFadeLength = 0.0
            trailingFadeLength = 0.0
        }
        
        var leftFadeLength, rightFadeLength: CGFloat
        switch (type) {
        case .ContinuousReverse, .RightLeft:
            leftFadeLength = trailingFadeLength
            rightFadeLength = leadingFadeLength
        
        // .MLContinuous, .MLLeftRight
        default:
            leftFadeLength = leadingFadeLength
            rightFadeLength = trailingFadeLength
            break
        }
        
        let leftFadePoint: CGFloat = leftFadeLength/self.bounds.size.width
        let rightFadePoint: CGFloat = rightFadeLength/self.bounds.size.width
        
        let adjustedLocations = [0.0, leftFadePoint, 1.0 - rightFadePoint, 1.0]
        if (animated) {
            // Create animation for gradient change
            let animation = CABasicAnimation(keyPath: "locations")
            animation.fromValue = gradientMask.locations
            animation.toValue = adjustedLocations
            animation.duration = 0.25
            
            gradientMask.addAnimation(animation, forKey: animation.keyPath)
            gradientMask.locations = adjustedLocations
        } else {
            CATransaction.begin()
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            gradientMask.locations = adjustedLocations
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
        let timingFunction = timingFunctionForAnimationCurve(animationCurve)
        
        // Define keyTimes
        switch (type) {
        case .LeftRight, .RightLeft:
            // Calculate total animation duration
            let totalDuration = 2.0 * (delay + interval)
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
            let totalDuration = delay + interval
            
            // Find when the lead label will be totally offscreen
            let offsetDistance = (awayLabelFrame.origin.x - homeLabelFrame.origin.x)
            let startFadeFraction = fabs(sublabel.bounds.size.width / offsetDistance)
            // Find when the animation will hit that point
            let startFadeTimeFraction = timingFunction.durationPercentageForPositionPercentage(startFadeFraction, duration: totalDuration)
            let startFadeTime = delay + NSTimeInterval(startFadeTimeFraction) * interval
            
            keyTimes = [
                0.0,                                        // Initial gradient
                delay/totalDuration,                        // Begin of fade in
                (delay + 0.2)/totalDuration,                // End of fade in, just as scroll away starts
                startFadeTime/totalDuration,                // Begin of fade out, just before scroll home completes
                (startFadeTime + 0.1)/totalDuration,        // End of fade out, as scroll home completes
                1.0                                         // Buffer final value (used on continuous types)
            ]
            break
        }
        
        // Define values
        switch (type) {
        case .ContinuousReverse, .RightLeft:
            values = [
                [0.0, fadeFraction, 1.0, 1.0],                   // Initial gradient
                [0.0, fadeFraction, 1.0, 1.0],                   // Begin of fade in
                [0.0, fadeFraction, 1.0 - fadeFraction, 1.0],    // End of fade in, just as scroll away starts
                [0.0, fadeFraction, 1.0 - fadeFraction, 1.0],    // Begin of fade out, just before scroll home completes
                [0.0, fadeFraction, 1.0, 1.0],                   // End of fade out, as scroll home completes
                [0.0, fadeFraction, 1.0, 1.0]                    // Final "home" value
            ]
            break
        
        // .MLContinuous, .MLLeftRight
        default:
            values = [
            [0.0, 0.0, 1.0 - fadeFraction, 1.0],            // Initial gradient
            [0.0, 0.0, 1.0 - fadeFraction, 1.0],            // Begin of fade in
            [0.0, fadeFraction, 1.0 - fadeFraction, 1.0],   // End of fade in, just as scroll away starts
            [0.0, fadeFraction, 1.0 - fadeFraction, 1.0],   // Begin of fade out, just before scroll home completes
            [0.0, 0.0, 1.0 - fadeFraction, 1.0],            // End of fade out, as scroll home completes
            [0.0, 0.0, 1.0 - fadeFraction, 1.0]             // Final "home" value
            ]
            break
        }
        
        animation.values = values
        animation.keyTimes = keyTimes
        animation.timingFunctions = [timingFunction, timingFunction, timingFunction, timingFunction]
        
        return animation
    }
    
    private func keyFrameAnimationForProperty(property: String, values: [NSValue], interval: NSTimeInterval, delay: NSTimeInterval) -> CAKeyframeAnimation {
        // Create new animation
        let animation = CAKeyframeAnimation(keyPath: property)
        
        // Get timing function
        let timingFunction = timingFunctionForAnimationCurve(animationCurve)
        
        // Calculate times based on marqueeType
        var totalDuration: NSTimeInterval = 0.0
        switch (type) {
        case .LeftRight, .RightLeft:
            //NSAssert(values.count == 5, @"Incorrect number of values passed for MLLeftRight-type animation")
            totalDuration = 2.0 * (delay + interval)
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
            ]
            
            // .Continuous
            // .ContinuousReverse
        default:
            //NSAssert(values.count == 3, @"Incorrect number of values passed for MLContinous-type animation")
            totalDuration = delay + interval
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
        animation.values = values
        
        return animation
    }
    
    private func timingFunctionForAnimationCurve(curve: UIViewAnimationCurve) -> CAMediaTimingFunction {
        var timingFunction: NSString? = nil
        
        switch curve {
        case .EaseIn:
            timingFunction = kCAMediaTimingFunctionEaseIn
        case .EaseInOut:
            timingFunction = kCAMediaTimingFunctionEaseInEaseOut
        case .EaseOut:
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
        applyGradientMask(fadeLength, animated: false)
        
        if labelShouldScroll() && !tapToScroll {
            beginScroll()
        }
    }
    
    public func resetLabel() {
        returnLabelToHome()
        homeLabelFrame = CGRect.nullRect
        awayLabelFrame = CGRect.nullRect
    }
    
    public func shutdownLabel() {
        returnLabelToHome()
    }
    
    public func pauseLabel() {
        // Pause sublabel position animations
        for sl in allSublabels() {
            let labelPauseTime = sl.layer.convertTime(CACurrentMediaTime(), fromLayer: nil)
            sl.layer.speed = 0.0;
            sl.layer.timeOffset = labelPauseTime;
        }
        // Pause gradient fade animation
        let gradientPauseTime = self.layer.mask.convertTime(CACurrentMediaTime(), fromLayer:nil)
        self.layer.mask.speed = 0.0;
        self.layer.mask.timeOffset = gradientPauseTime;
    }
    
    public func unpauseLabel() {
        // Unpause sublabel position animations
        for sl in allSublabels() {
            let labelPausedTime = sl.layer.timeOffset
            sl.layer.speed = 1.0;
            sl.layer.timeOffset = 0.0;
            sl.layer.beginTime = 0.0;
            sl.layer.beginTime = sl.layer.convertTime(CACurrentMediaTime(), fromLayer:nil) - labelPausedTime
        }
        // Unpause gradient fade animation
        let gradientPauseTime = self.layer.mask.timeOffset
        self.layer.mask.speed = 1.0;
        self.layer.mask.timeOffset = 0.0;
        self.layer.mask.beginTime = 0.0;
        self.layer.mask.beginTime = self.layer.mask.convertTime(CACurrentMediaTime(), fromLayer:nil) - gradientPauseTime
    }
    
    private func labelWasTapped(recognizer: UIGestureRecognizer) {
        if labelShouldScroll() {
            beginScroll(true)
        }
    }
    
    public func labelWillBeginScroll() {
        // Default implementation does nothing - override to customize
        return
    }
    
    public func labelReturnedToHome(finished: Bool) {
        // Default implementation does nothing - override to customize
        return
    }
    
    //
    // MARK: - Modified UILabel Functions/Getters/Setters
    //
    

    override public func viewForBaselineLayout() -> UIView {
        // Use subLabel view for handling baseline layouts
        return sublabel
    }

    override public func drawRect(rect: CGRect) {
        // Draw NOTHING to prevent superclass drawing
    }

    public override var text: String! {
        didSet {
            if text == oldValue {
                return
            }
            sublabel.text = text
            self.updateAndScroll()
        }
    }
    
    public override var attributedText: NSAttributedString! {
        didSet {
            if attributedText == oldValue {
                return
            }
            sublabel.attributedText = attributedText
            self.updateAndScroll()
        }
    }
    
    public override var font: UIFont! {
        get {
            return sublabel.font
        }
        
        set {
            if sublabel.font == newValue {
                return
            }
            sublabel.font = newValue
            updateAndScroll()
        }
    }
    
    public override var textColor: UIColor! {
        get {
            return sublabel.textColor
        }
        
        set {
            updateSublabelsForKey("textColor", value: newValue)
        }
    }
    
    public override var backgroundColor: UIColor? {
        get {
            return sublabel.backgroundColor
        }
        
        set {
            updateSublabelsForKey("backgroundColor", value: newValue)
        }
    }
    
    public override var shadowColor: UIColor! {
        get {
            return sublabel.shadowColor
        }
        
        set {
            updateSublabelsForKey("shadowColor", value: newValue)
        }
    }
    
    public override var highlightedTextColor: UIColor! {
        get {
            return sublabel.highlightedTextColor
        }
        
        set {
            updateSublabelsForKey("highlightedTextColor", value: newValue)
        }
    }
    
    public override var highlighted: Bool {
        get {
            return sublabel.highlighted
        }
        
        set {
            updateSublabelsForKey("highlighted", value: newValue)
        }
    }
    
    public override var enabled: Bool {
        get {
            return sublabel.enabled
        }
        
        set {
            updateSublabelsForKey("enabled", value: newValue)
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
            return sublabel.baselineAdjustment
        }
        
        set {
            updateSublabelsForKey("baselineAdjustment", value: newValue.toRaw())
        }
    }
    
    public override func intrinsicContentSize() -> CGSize {
        return sublabel.intrinsicContentSize()
    }
    
    private func refreshSublabels(labels: [UILabel]) {
        for sl in labels {
            sl.attributedText = attributedText
            sl.backgroundColor = backgroundColor
            sl.shadowColor = shadowColor
            sl.shadowOffset = shadowOffset
            sl.textAlignment = textAlignment
        }
    }
    
    private func updateSublabelsForKey(key: String, value: AnyObject?) {
        for sl in allSublabels() {
            sl.setValue(value, forKeyPath: key)
        }
    }
    

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
        for sl in allSublabels() {
            if sl != sublabel {
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
        NSNotificationCenter.defaultCenter().removeObserver(orientationObserver!)
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
                return nil
            }
        }
        return nil
    }
}

extension CAMediaTimingFunction {
    
    func durationPercentageForPositionPercentage(positionPercentage: CGFloat, duration: NSTimeInterval) -> CGFloat {
        // Finds the animation duration percentage that corresponds with the given animation "position" percentage.
        // Utilizes Newton's Method to solve for the parametric Bezier curve that is used by CAMediaAnimation.
        
        let controlPoints = self.controlPoints()
        let epsilon: CGFloat = 1.0 / (100.0 * CGFloat(duration))
        
        // Find the t value that gives the position percentage we want
        let t_found = solveTforY(positionPercentage, epsilon: epsilon, controlPoints: controlPoints)
        
        // With that t, find the corresponding animation percentage
        let durationPercentage = XforCurveAt(t_found, controlPoints: controlPoints)
        
        return durationPercentage
    }
    
    func solveTforY(y_0: CGFloat, epsilon: CGFloat, controlPoints: [CGPoint]) -> CGFloat {
        // Use Newton's Method: http://en.wikipedia.org/wiki/Newton's_method
        // For first guess, use t = y (i.e. if curve were linear)
        var t0 = y_0
        var t1 = y_0
        var f0, df0: CGFloat
        
        for (var i = 0; i < 15; i++) {
            // Base this iteration of t1 calculated from last iteration
            t0 = t1
            // Calculate f(t0)
            f0 = YforCurveAt(t0, controlPoints:controlPoints) - y_0
            // Check if this is close (enough)
            if (fabs(f0) < epsilon) {
                // Done!
                return t0;
            }
            // Else continue Newton's Method
            df0 = derivativeCurveYValueAt(t0, controlPoints:controlPoints)
            // Check if derivative is small or zero ( http://en.wikipedia.org/wiki/Newton's_method#Failure_analysis )
            if (fabs(df0) < 1e-6) {
                break;
            }
            // Else recalculate t1
            t1 = t0 - f0/df0;
        }
        
        // Give up - shouldn't ever get here...I hope
        println("MarqueeLabel: Failed to find t for Y input!")
        return t0
    }
    
    func YforCurveAt(t: CGFloat, controlPoints:[CGPoint]) -> CGFloat {
        let P0 = controlPoints[0]
        let P1 = controlPoints[1]
        let P2 = controlPoints[2]
        let P3 = controlPoints[3]
        
        // Per http://en.wikipedia.org/wiki/Bezier_curve#Cubic_B.C3.A9zier_curves
        let y0 = (pow((1.0 - t),3.0) * P0.y)
        let y1 = (3.0 * pow(1.0 - t, 2.0) * t * P1.y)
        let y2 = (3.0 * (1.0 - t) * pow(t, 2.0) * P2.y)
        let y3 = (pow(t, 3.0) * P3.y)
        
        return y0 + y1 + y2 + y3
    }
    
    func XforCurveAt(t: CGFloat, controlPoints: [CGPoint]) -> CGFloat {
        let P0 = controlPoints[0]
        let P1 = controlPoints[1]
        let P2 = controlPoints[2]
        let P3 = controlPoints[3]
        
        // Per http://en.wikipedia.org/wiki/Bezier_curve#Cubic_B.C3.A9zier_curves
        
        let x0 = (pow((1.0 - t),3.0) * P0.x)
        let x1 = (3.0 * pow(1.0 - t, 2.0) * t * P1.x)
        let x2 = (3.0 * (1.0 - t) * pow(t, 2.0) * P2.x)
        let x3 = (pow(t, 3.0) * P3.x)
        
        return x0 + x1 + x2 + x3
    }
    
    func derivativeCurveYValueAt(t: CGFloat, controlPoints: [CGPoint]) -> CGFloat {
        let P0 = controlPoints[0]
        let P1 = controlPoints[1]
        let P2 = controlPoints[2]
        let P3 = controlPoints[3]
        
        let dy0 = (P0.y + 3.0 * P1.y + 3.0 * P2.y - P3.y) * -3.0
        let dy1 = t * (6.0 * P0.y + 6.0 * P2.y)
        let dy2 = (-3.0 * P0.y + 3.0 * P1.y)

        return dy0 * pow(t, 2.0) + dy1 + dy2
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

