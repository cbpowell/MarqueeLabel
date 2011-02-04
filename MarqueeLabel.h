//
//  MarqueeLabel.h
//  
//
//  Created by Charles Powell on 1/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface MarqueeLabel : UIView {
    
    UILabel *subLabel;
    CGRect baseLabelFrame;
    
    BOOL loopLabel;
    
}

@property (nonatomic, retain) UILabel *subLabel;
@property (nonatomic) CGRect baseLabelFrame;

// UILabel properties
@property(nonatomic) BOOL adjustsFontSizeToFitWidth;
@property(nonatomic) UIBaselineAdjustment baselineAdjustment;
@property(nonatomic, getter=isEnabled) BOOL enabled;
@property(nonatomic, retain) UIFont *font;
@property(nonatomic, getter=isHighlighted) BOOL highlighted;
@property(nonatomic, retain) UIColor *highlightedTextColor;
@property(nonatomic) UILineBreakMode lineBreakMode;
@property(nonatomic) CGFloat minimumFontSize;
@property(nonatomic) NSInteger numberOfLines;
@property(nonatomic, retain) UIColor *shadowColor;
@property(nonatomic) CGSize shadowOffset;
@property(nonatomic, copy) NSString *text;
@property(nonatomic) UITextAlignment textAlignment;
@property(nonatomic, retain) UIColor *textColor;
@property(nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;

-(void) scrollWithLoop:(BOOL)loop andSpeed:(NSInteger)speed;
-(void) scrollLeft;
-(void) scrollRight;

@end


// Declare UILabel methods as extensions to be passed through with forwardInvocation
@interface UILabel (MarqueeLabel)

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines;
- (void)drawTextInRect:(CGRect)rect;

@end


