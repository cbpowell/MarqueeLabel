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


@interface MarqueeLabel : UIView {
    
}

// MarqueeLabel-specific properties

/* animationCurve:
 * The animation curve used in the motion of the labels. Allowable options:
 * UIViewAnimationOptionCurveEaseInOut, UIViewAnimationOptionCurveEaseIn,
 * UIViewAnimationOptionCurveEaseOut, UIViewAnimationOptionCurveLinear
 * Default is UIViewAnimationOptionCurveEaseInOut.
 */
@property (nonatomic) UIViewAnimationOptions animationCurve;


/* awayFromHome:
 * Returns if the label is away from "home", the location where it would be if
 * it were a normal UILabel (although it does take into account the fade lengths,
 * in that "home" is offset by those in order for the edge of the labels not to be
 * faded when at the home location.
 */
@property (nonatomic, readonly) BOOL awayFromHome;


/* labelize:
 * When set to YES, the MarqueeLabel will not move and behave like a normal UILabel
 * Defaults to NO.
 */
@property (nonatomic) BOOL labelize;


/* fadeLength:
 * Sets the length of fade (from alpha 1.0 to alpha 0.0) at the edges of the
 * MarqueeLabel. Cannot be larger than 1/2 of the frame width (will be santized).
 */
@property (nonatomic) CGFloat fadeLength;

- (id)initWithFrame:(CGRect)frame rate:(float)pixelsPerSec andFadeLength:(float)fadeLength;
- (id)initWithFrame:(CGRect)frame duration:(NSTimeInterval)lengthOfScroll andFadeLength:(float)fadeLength;

- (void)restartLabel;











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
@property (nonatomic) BOOL adjustsFontSizeToFitWidth;
@property (nonatomic) UIBaselineAdjustment baselineAdjustment;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, retain) UIFont *font;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, retain) UIColor *highlightedTextColor;
@property (nonatomic) UILineBreakMode lineBreakMode;
@property (nonatomic) CGFloat minimumFontSize;
@property (nonatomic) NSInteger numberOfLines;
@property (nonatomic, retain) UIColor *shadowColor;
@property (nonatomic) CGSize shadowOffset;
@property (nonatomic) UITextAlignment textAlignment;
@property (nonatomic, retain) UIColor *textColor;
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;

@end

// Declare UILabel methods as extensions to be passed through with forwardInvocation
@interface UILabel (MarqueeLabel)

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines;
- (void)drawTextInRect:(CGRect)rect;

@end


