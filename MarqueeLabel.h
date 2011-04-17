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
    
    @protected
    UILabel *subLabel;
    NSString *labelText;
    NSTimeInterval scrollSpeed;
    float rate;
    NSUInteger animationOptions;
    CGRect baseLabelFrame;
    CGPoint baseLabelOrigin;
    CGFloat baseAlpha;
    CGFloat baseLeftBuffer;
    CGFloat baseRightBuffer;
    BOOL awayFromHome;
    BOOL labelize;
    BOOL animating;
    
}

// External MarqueeLabel properties
@property (nonatomic) BOOL awayFromHome;
@property (nonatomic) BOOL labelize;
@property (nonatomic) BOOL animating;

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

- (id)initWithFrame:(CGRect)frame andSpeed:(NSTimeInterval)lengthOfScroll andBuffer:(CGFloat)buffer;
- (id)initWithFrame:(CGRect)frame andRate:(float)pixelsPerSec andBufer:(CGFloat)buffer;

@end


// Declare UILabel methods as extensions to be passed through with forwardInvocation
@interface UILabel (MarqueeLabel)

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines;
- (void)drawTextInRect:(CGRect)rect;

@end


