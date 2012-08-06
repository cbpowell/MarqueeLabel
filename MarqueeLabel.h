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
//  MarqueeLabel.h
//  

#import <UIKit/UIKit.h>


// MarqueeLabel types
typedef enum {
    MLLeftRight = 0,    // Scrolls left first, then back right to the original position
    MLRightLeft,        // Scrolls right first, then back left to the original position
    MLContinuous        // Continuously scrolls left (with a pause at the original position if animationDelay is set)
} MarqueeType;

@interface MarqueeLabel : UIView {
    
}

// MarqueeLabel-specific properties

/* animationCurve:
 * The animation curve used in the motion of the labels. Allowable options:
 * UIViewAnimationOptionCurveEaseInOut, UIViewAnimationOptionCurveEaseIn,
 * UIViewAnimationOptionCurveEaseOut, UIViewAnimationOptionCurveLinear
 * Default is UIViewAnimationOptionCurveEaseInOut.
 */
@property (nonatomic, assign) UIViewAnimationOptions animationCurve;


/* awayFromHome:
 * Returns if the label is away from "home", the location where it would be if
 * it were a normal UILabel (although it does take into account the fade lengths,
 * in that "home" is offset by those in order for the edge of the labels not to be
 * faded when at the home location.
 */
@property (nonatomic, assign, readonly) BOOL awayFromHome;


/* labelize:
 * When set to YES, the MarqueeLabel will not move and behave like a normal UILabel
 * Defaults to NO.
 */
@property (nonatomic, assign) BOOL labelize;


/* marqueeType:
 * When set to LeftRight, the label moves from left to right and back from right to left alternatively.
 *
 *      NOTE: LeftRight type is ONLY compatible with a label text alignment of UITextAlignmentLeft. Specifying
 *      LeftRight will change any previously set, non-compatible text alignment to UITextAlignmentLeft.
 *
 * When set to RightLeft, the label moves from right to left and back from left to right alternatively.
 *
 *      NOTE: RightLeft type is ONLY compatibile with a label text alignment of UITextAlignmentRight. Specifying
 *      RightLeft will change any previously set, non-compatible text alignment to UITextAlignmentRight.
 *
 * When set to Continuous, the label slides continuously to the left.
 *
 *      NOTE: MLContinuous does support any text alignment, but will always scroll left.
 *
 * Defaults to LeftRight.
 */
@property (nonatomic, assign) MarqueeType marqueeType;


/* continuousMarqueeSeparator:
 * NString inserted after label's end when marqueeType is Continuous.
 * Defaults to @"       ".
 */
@property (nonatomic, copy) NSString *continuousMarqueeSeparator;


/* fadeLength:
 * Sets the length of fade (from alpha 1.0 to alpha 0.0) at the edges of the
 * MarqueeLabel. Cannot be larger than 1/2 of the frame width (will be santized).
 */
@property (nonatomic, assign) CGFloat fadeLength;


/* animationDelay:
 * Sets how long the label pauses at the "origin" position between scrolling
 */
@property (nonatomic, assign) CGFloat animationDelay;


/* tapToScroll:
 * If YES, when tapped the label will scroll through its cycle once.
 * NOTE: The label will not automatically scroll if this is set to YES!
 * Defaults to NO.
 */
@property (nonatomic, assign) BOOL tapToScroll;


// Read-only properties for state
@property (nonatomic, assign, readonly) BOOL isPaused;


// Class Methods
+ (void)controllerViewAppearing:(UIViewController *)controller;
+ (void)controllerLabelsShouldLabelize:(UIViewController *)controller;
+ (void)controllerLabelsShouldAnimate:(UIViewController *)controller;

// Methods
- (id)initWithFrame:(CGRect)frame rate:(CGFloat)pixelsPerSec andFadeLength:(CGFloat)fadeLength;
- (id)initWithFrame:(CGRect)frame duration:(NSTimeInterval)lengthOfScroll andFadeLength:(CGFloat)fadeLength;

- (void)restartLabel;
- (void)resetLabel;

- (void)pauseLabel;
- (void)unpauseLabel;















/**********************************************
 * These properties silence and/or override
 * the standard UILabel properties, in order
 * to silence compiler warnings. You shouldn't
 * need to mess with these!
 **********************************************/

// UIView Override properties
@property (nonatomic, copy) UIColor *backgroundColor;
@property (nonatomic, copy) NSString *text;

// UILabel properties
@property (nonatomic, assign) BOOL adjustsFontSizeToFitWidth;
@property (nonatomic, assign) UIBaselineAdjustment baselineAdjustment;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, assign, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, strong) UIColor *highlightedTextColor;
@property (nonatomic, assign) UILineBreakMode lineBreakMode;
@property (nonatomic, assign) CGFloat minimumFontSize;
@property (nonatomic, assign) NSInteger numberOfLines;
@property (nonatomic, strong) UIColor *shadowColor;
@property (nonatomic, assign) CGSize shadowOffset;
@property (nonatomic, assign) UITextAlignment textAlignment;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, assign, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;

@end

// Declare UILabel methods as extensions to be passed through with forwardInvocation
@interface UILabel (MarqueeLabel)

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines;
- (void)drawTextInRect:(CGRect)rect;

@end


