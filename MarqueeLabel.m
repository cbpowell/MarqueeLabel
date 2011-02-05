//
//  MarqueeLabel.m
//  
//
//  Created by Charles Powell on 1/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MarqueeLabel.h"


@implementation MarqueeLabel

@synthesize subLabel;
@synthesize scrollSpeed;
@synthesize baseLabelFrame, baseLabelOrigin, baseAlpha;
@synthesize awayFromHome, labelize;

// UILabel properties for pass through WITH modification
@synthesize text;
@dynamic adjustsFontSizeToFitWidth, lineBreakMode, numberOfLines;

// UIView override properties
@synthesize backgroundColor;

// Pass through properties
@dynamic baselineAdjustment, enabled, font, highlighted, highlightedTextColor, minimumFontSize;
@dynamic shadowColor, shadowOffset, textAlignment, textColor, userInteractionEnabled;


#pragma mark -
#pragma mark Initialization

- (id)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame andSpeed:7.0];
}

- (id)initWithFrame:(CGRect)frame andSpeed:(NSTimeInterval)speed {
    
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code.
        
        // Set the containing MarqueeLabel view to clip it's interior, and have a clear background
        [self setClipsToBounds:YES];
        self.backgroundColor = [UIColor redColor];
        self.scrollSpeed = speed;
        self.awayFromHome = NO;
        self.labelize = NO;
        
        
        // Create sublabel
        self.baseLabelOrigin = CGPointMake(0, 0);
        self.baseLabelFrame = CGRectMake(baseLabelOrigin.x, baseLabelOrigin.y, self.bounds.size.width, self.bounds.size.height);
        UILabel *newLabel = [[UILabel alloc] initWithFrame:self.baseLabelFrame];
        self.subLabel = newLabel;
        [self addSubview:self.subLabel];
        [newLabel release];
        
    }
    return self;
}


#pragma mark -
#pragma mark Animation Handlers 

- (void)scrollLeftWithSpeed:(NSTimeInterval)speed {
    
    // Get the start frame
    CGRect startSubLabelFrame = subLabel.frame;
    // Calculate the final frame
    startSubLabelFrame.origin.x = self.frame.size.width - subLabel.frame.size.width;
    
    NSLog(@"self.frame.size.width: %.0f, subLabel.frame.size.width: %.0f", self.frame.size.width, self.subLabel.frame.size.width);
    NSLog(@"startSubLabelFrame origin: %.0f", startSubLabelFrame.origin.x);
    
    // Perform animation
    self.awayFromHome = TRUE;
    [UIView animateWithDuration:speed
                          delay:1.0 
                        options:(UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat)
                     animations:^{
                         self.subLabel.frame = startSubLabelFrame;
                     }
                     completion:nil];
    
}

- (void)scrollRightWithSpeed:(NSTimeInterval)speed {
    // Perform animation
    [UIView animateWithDuration:speed
                          delay:0.1 
                        options:(UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
                         self.subLabel.frame = baseLabelFrame;
                     }
                     completion:^(BOOL finished){
                         NSLog(@"Finished animating right");
                         self.awayFromHome = NO;
                         if (subLabel.frame.size.width > self.frame.size.width) {
                             NSLog(@"subLabel larger, scrolling left again: %.0f, %.0f", subLabel.frame.size.width, self.frame.size.width);
                             [self scrollLeftWithSpeed:speed];
                         }
                     }];
    // Acually commit change
    self.subLabel.frame = baseLabelFrame;
}

- (void)returnLabelToOrigin {
    CGRect homeLabelFrame = CGRectMake(self.baseLabelOrigin.x, self.baseLabelOrigin.y, self.subLabel.frame.size.width, self.subLabel.frame.size.height);
    [UIView animateWithDuration:0
                          delay:0
                        options:(UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction) 
                     animations:^{
                         self.subLabel.frame = homeLabelFrame;
                     }
                     completion:nil];
    self.awayFromHome = NO;
    self.baseLabelFrame = homeLabelFrame;
}
    
    
- (void)fadeOutLabel {
    
    self.baseAlpha = self.subLabel.alpha;
    
    [UIView animateWithDuration:1 
                          delay:0.1 
                        options:(UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction) 
                     animations:^{
                         self.subLabel.alpha = 0.0;
                     }
                     completion:^(BOOL finished){
                         NSLog(@"Faded out label");
                     }];
    
}

- (void)fadeInLabel {
    
    [UIView animateWithDuration:1 
                          delay:0.1 
                        options:(UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
                         self.subLabel.alpha = self.baseAlpha;
                     }
                     completion:^(BOOL finished){
                         NSLog(@"Faded in label");
                     }];
    
}

// Custom labelize mutator to restart scrolling after changing labelize to NO
- (void)setLabelize:(BOOL)function {
    NSLog(@"Setting labelize");
    if (function) {
        
        NSLog(@"Labelize = yes");
        labelize = YES;
        if (self.subLabel) {
            [self returnLabelToOrigin];
        }
        
    } else {
        
        NSLog(@"Labelize = no");
        labelize = NO;
        if (self.subLabel && (self.subLabel.frame.size.width > self.frame.size.width)) {
            [self returnLabelToOrigin];
            [self scrollLeftWithSpeed:self.scrollSpeed];
        }
        
    }
}

#pragma mark -
#pragma mark Modified UILabel Getters/Setters

- (void)setText:(NSString *)newText {
      
    if (newText != self.subLabel.text) {
        
        CGSize maximumLabelSize = CGSizeMake(1200, 1200);
        CGSize expectedLabelSize = [newText sizeWithFont:self.subLabel.font
                                       constrainedToSize:maximumLabelSize
                                           lineBreakMode:self.subLabel.lineBreakMode];
        CGRect homeLabelFrame = CGRectMake(baseLabelOrigin.x, baseLabelOrigin.y, expectedLabelSize.width, expectedLabelSize.height);
        
        if (!self.labelize) {
            
            if (self.awayFromHome) {
                NSLog(@"Label not at home, and not labelized");
                
                // Store current alpha
                self.baseAlpha = self.subLabel.alpha;
                
                // Fade out quickly
                [UIView animateWithDuration:0.2
                                      delay:0.0 
                                    options:(UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction)
                                 animations:^{
                                     self.subLabel.alpha = 0.0;
                                 }
                                 completion:^(BOOL finished){
                                     
                                     // Animate move immediately
                                     [self returnLabelToOrigin];
                                     
                                     // Set text while invisible
                                     self.subLabel.text = newText;
                                     self.subLabel.frame = homeLabelFrame;
                                     
                                     // Fade in quickly
                                     [UIView animateWithDuration:0.2
                                                           delay:0.0
                                                         options:(UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction)
                                                      animations:^{
                                                          self.subLabel.alpha = baseAlpha;
                                                      }
                                                      completion:^(BOOL finished){
                                                          self.awayFromHome = NO;
                                                          
                                                          if (self.subLabel.frame.size.width > self.frame.size.width) {
                                                              // Scroll
                                                              [self scrollLeftWithSpeed:self.scrollSpeed];
                                                          }
                                                      }];
                                        }];
                //end of animation blocks
                
            } else {
                NSLog(@"Label at home, not labelized");
                // Label at home, animate text change
                
                // Store current alpha
                self.baseAlpha = self.subLabel.alpha;
                
                // Fade out quickly
                [UIView animateWithDuration:0.2
                                      delay:0.0 
                                    options:(UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction)
                                 animations:^{
                                     self.subLabel.alpha = 0.0;
                                 }
                                 completion:^(BOOL finished){
                                     
                                     // Set text while invisible
                                     self.subLabel.frame = homeLabelFrame;
                                     NSLog(@"homeLabelFrame: %.0f, %.0f, %.0f, %.0f", homeLabelFrame.origin.x, homeLabelFrame.origin.y, homeLabelFrame.size.width, homeLabelFrame.size.height);
                                     self.subLabel.text = newText;
                                     NSLog(@"Setting new text");
                                     // Fade in quickly
                                     [UIView animateWithDuration:0.2
                                                           delay:0.0
                                                         options:(UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction)
                                                      animations:^{
                                                          self.subLabel.alpha = 1.0;
                                                      }
                                                      completion:^(BOOL finished){
                                                          self.awayFromHome = NO;
                                                          NSLog(@"Finished setting text and animations, option to scroll");
                                                          if (self.subLabel.frame.size.width > self.frame.size.width) {
                                                              // Scroll
                                                              NSLog(@"Scrolling");
                                                              [self scrollLeftWithSpeed:self.scrollSpeed];
                                                          }
                                                      }];
                                 }];
                // end of animation block
            }
                
        } else {
            // Currently labelized
            NSLog(@"Currently labelized");
            self.subLabel.frame = homeLabelFrame;
            self.subLabel.text = newText;
            
        }
        
        self.baseLabelFrame = homeLabelFrame;
        
    }
    
}

- (NSString *)text {
    
    return self.subLabel.text;
    
}

#pragma mark -
#pragma mark Overridden UIView properties

- (void)setBackgroundColor:(UIColor *)newColor {
    
    if (newColor != self.subLabel.backgroundColor) {
        
        self.subLabel.backgroundColor = newColor;
    }
    
}

- (UIColor *)backgroundColor {
    
    return self.subLabel.backgroundColor;
    
}

#pragma mark -
#pragma mark UILabel Message Forwarding

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [UILabel instanceMethodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    if ([subLabel respondsToSelector:[anInvocation selector]]) {
        [anInvocation invokeWithTarget:subLabel];
    } else {
        NSLog(@"MarqueeLabel does not recognize the selector");
        [super forwardInvocation:anInvocation];
    }
}

- (id)valueForUndefinedKey:(NSString *)key {
    return [subLabel valueForKey:key];
}

- (void) setValue:(id)value forUndefinedKey:(NSString *)key {
    [subLabel setValue:value forKey:key];
}

#pragma mark -

- (void)dealloc {
    [self.subLabel release];
    [super dealloc];
}


@end
