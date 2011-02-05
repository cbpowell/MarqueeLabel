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
@synthesize baseLabelFrame;
@synthesize baseAlpha;
@synthesize awayFromHome;

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
- (id)initWithFrame:(CGRect)frame andSpeed:(NSTimeInterval)speed {
    
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code.
        
        // Set the containing MarqueeLabel view to clip it's interior, and have a clear background
        [self setClipsToBounds:YES];
        self.backgroundColor = [UIColor redColor];
        self.scrollSpeed = speed;
        
        // Create sublabel
        self.baseLabelFrame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
        UILabel *newLabel = [[UILabel alloc] initWithFrame:self.baseLabelFrame];
        self.subLabel = newLabel;
        
        self.awayFromHome = NO;
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
                        options:UIViewAnimationCurveEaseInOut 
                     animations:^{
                         self.subLabel.frame = startSubLabelFrame;
                     }
                     completion:^(BOOL finished){
                         NSLog(@"Done animating subLabel to the left");
                         [self scrollRightWithSpeed:speed];
                     }];
    NSLog(@"this: %.0f should equal this: %.0f", self.subLabel.frame.origin.x, startSubLabelFrame.origin.x);
    // Set away flag
    
}

- (void)scrollRightWithSpeed:(NSTimeInterval)speed {
    // Perform animation
    [UIView animateWithDuration:speed
                          delay:0.1 
                        options:UIViewAnimationCurveEaseInOut 
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
    
- (void)fadeOutLabel {
    
    self.baseAlpha = self.subLabel.alpha;
    
    [UIView animateWithDuration:1 
                          delay:0.1 
                        options:(UIViewAnimationOptionCurveLinear || UIViewAnimationOptionBeginFromCurrentState) 
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
                        options:(UIViewAnimationOptionCurveLinear || UIViewAnimationOptionBeginFromCurrentState) 
                     animations:^{
                         self.subLabel.alpha = self.baseAlpha;
                     }
                     completion:^(BOOL finished){
                         NSLog(@"Faded in label");
                     }];
    
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
#pragma mark Modified UILabel Getters/Setters

- (void)setText:(NSString *)newText {
    
    NSLog(@"Setting text: %@", newText);
    
    if (newText != self.subLabel.text) {
        NSLog(@"Text different");
        CGSize maximumLabelSize = CGSizeMake(1200, 9999);
        CGSize expectedLabelSize = [newText sizeWithFont:self.subLabel.font
                                       constrainedToSize:maximumLabelSize
                                           lineBreakMode:self.subLabel.lineBreakMode];
        CGRect homeLabelFrame = CGRectMake(baseLabelFrame.origin.x, baseLabelFrame.origin.y, expectedLabelSize.width, expectedLabelSize.height);
        
        
        //if (self.subLabel.frame.origin.x != self.baseLabelFrame.origin.x) {
        if (self.awayFromHome) {
            NSLog(@"Label not at home");
            
            // Store current alpha
            self.baseAlpha = self.subLabel.alpha;
            // Store the max label size
            
            // Fade out quickly
            [UIView animateWithDuration:0.5
                                  delay:0.0 
                                options:(UIViewAnimationOptionCurveLinear || UIViewAnimationOptionBeginFromCurrentState)
                             animations:^{
                                 self.subLabel.alpha = 0.0;
                             }
                             completion:^(BOOL finished){
                                 NSLog(@"Faded out label");
                                 
                                 // Animate move immediately
                                 [UIView animateWithDuration:0
                                                       delay:0
                                                     options:UIViewAnimationOptionBeginFromCurrentState
                                                  animations:^{
                                                      self.subLabel.frame = homeLabelFrame;
                                                  }
                                                  completion:^(BOOL finished){
                                                      NSLog(@"Moved label home");
                                                      // Set text while invisible
                                                      self.subLabel.text = newText;
                                                      // Fade in quickly
                                                      [UIView animateWithDuration:0.5
                                                                            delay:0
                                                                          options:UIViewAnimationOptionCurveLinear
                                                                       animations:^{
                                                                           self.subLabel.alpha = baseAlpha;
                                                                       }
                                                                       completion:^(BOOL finished){
                                                                           NSLog(@"Returned label to visibility");
                                                                           if (self.subLabel.frame.size.width > self.frame.size.width) {
                                                                               
                                                                               // Scroll
                                                                               NSLog(@"Label text too large, scrolling");
                                                                               [self scrollLeftWithSpeed:self.scrollSpeed];
                                                                               
                                                                           }
                                                                       }];
                                                  }];
                             }];
            //end of animation blocks
            
        } else {
            NSLog(@"Label at home");
            // Set text with no animation if already home
            self.subLabel.frame = homeLabelFrame;
            self.subLabel.text = newText;
            
            if (self.subLabel.frame.size.width > self.frame.size.width) {
                
                // Scroll
                NSLog(@"Label text too large, scrolling");
                [self scrollLeftWithSpeed:self.scrollSpeed];
                
            }
            
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

- (void)dealloc {
    [self.subLabel release];
    [super dealloc];
}


@end
