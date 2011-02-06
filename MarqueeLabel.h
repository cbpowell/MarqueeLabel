//
//  MarqueeLabel.h
//  
//
//  Created by Charles Powell on 1/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface MarqueeLabel : UIView {
    
    @protected
    UILabel *subLabel;
    NSTimeInterval scrollSpeed;
    CGRect baseLabelFrame;
    CGPoint baseLabelOrigin;
    CGFloat baseAlpha;
    CGFloat baseBuffer;
    BOOL awayFromHome;
    
    BOOL labelize;
    
}

@property (nonatomic, retain) UILabel *subLabel;
@property (nonatomic) NSTimeInterval scrollSpeed;
@property (nonatomic) CGRect baseLabelFrame;
@property (nonatomic) CGPoint baseLabelOrigin;
@property (nonatomic) CGFloat baseAlpha;
@property (nonatomic) CGFloat baseBuffer;
@property (nonatomic) BOOL awayFromHome;
@property (nonatomic) BOOL labelize;

// UIView Override properties
@property (nonatomic, copy) UIColor *backgroundColor;

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
@property (nonatomic, copy) NSString *text;
@property (nonatomic) UITextAlignment textAlignment;
@property (nonatomic, retain) UIColor *textColor;
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;

- (id)initWithFrame:(CGRect)frame andSpeed:(NSTimeInterval)speed andBuffer:(CGFloat)buffer;
- (void)scrollLeftWithSpeed:(NSTimeInterval)speed;
- (void)scrollRightWithSpeed:(NSTimeInterval)speed;
- (void)returnLabelToOrigin;
- (void)fadeInLabel;
- (void)fadeOutLabel;

@end


// Declare UILabel methods as extensions to be passed through with forwardInvocation
@interface UILabel (MarqueeLabel)

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines;
- (void)drawTextInRect:(CGRect)rect;

@end


