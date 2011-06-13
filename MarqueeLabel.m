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
//  MarqueeLabel.m
//  

#import "MarqueeLabel.h"

@interface MarqueeLabel()

@property (nonatomic, retain) UILabel *subLabel;
@property (nonatomic, retain) NSString *labelText;
@property (nonatomic) NSTimeInterval scrollSpeed;
@property (nonatomic) float rate;
@property (nonatomic) NSUInteger animationOptions;
@property (nonatomic) CGRect baseLabelFrame;
@property (nonatomic) CGPoint baseLabelOrigin;
@property (nonatomic) CGFloat baseAlpha;
@property (nonatomic) CGFloat baseLeftBuffer;
@property (nonatomic) CGFloat baseRightBuffer;

- (void)scrollLeftWithSpeed:(NSTimeInterval)speed;
- (void)scrollRightWithSpeed:(NSTimeInterval)speed;
- (void)returnLabelToOrigin;   

@end


@implementation MarqueeLabel

@synthesize subLabel, labelText;
@synthesize scrollSpeed, rate;
@synthesize animationOptions, baseLabelFrame, baseLabelOrigin, baseAlpha, baseLeftBuffer, baseRightBuffer;
@synthesize awayFromHome, labelize, animating;

// UILabel properties for pass through WITH modification
@synthesize text;
@dynamic adjustsFontSizeToFitWidth, lineBreakMode, numberOfLines;

// UIView override properties
@synthesize backgroundColor;

// Pass through properties (no modification)
@dynamic baselineAdjustment, enabled, font, highlighted, highlightedTextColor, minimumFontSize;
@dynamic shadowColor, shadowOffset, textAlignment, textColor, userInteractionEnabled;


#pragma mark -
#pragma mark Initialization

- (id)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame andSpeed:7.0 andBuffer:0.0];
}

- (id)initWithFrame:(CGRect)frame andRate:(float)pixelsPerSec andBufer:(CGFloat)buffer {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code.
        
        // Set the containing MarqueeLabel view to clip it's interior, and have a clear background
        [self setClipsToBounds:YES];
        self.backgroundColor = [UIColor redColor];
        self.scrollSpeed = 0;
        self.rate = pixelsPerSec;
        self.animationOptions = (UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat);
        self.awayFromHome = NO;
        self.labelize = NO;
        self.baseLeftBuffer = buffer;
        self.baseRightBuffer = buffer;
        self.labelText = nil;
        
        // Create sublabel
        self.baseLabelOrigin = CGPointMake(self.baseLeftBuffer, 0);
        self.baseLabelFrame = CGRectMake(self.baseLabelOrigin.x, self.baseLabelOrigin.y, (self.bounds.size.width - self.baseRightBuffer), self.bounds.size.height);
        UILabel *newLabel = [[UILabel alloc] initWithFrame:self.baseLabelFrame];
        self.subLabel = newLabel;
        [self addSubview:self.subLabel];
        [newLabel release];
        
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame andSpeed:(NSTimeInterval)lengthOfScroll andBuffer:(CGFloat)buffer {
    
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code.
        
        // Set the containing MarqueeLabel view to clip it's interior, and have a clear background
        [self setClipsToBounds:YES];
        self.backgroundColor = [UIColor redColor];
        self.scrollSpeed = (NSTimeInterval)lengthOfScroll;
        self.rate = 0.0;
        self.animationOptions = (UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat);
        self.awayFromHome = NO;
        self.labelize = NO;
        self.baseLeftBuffer = buffer;
        self.baseRightBuffer = buffer;
        self.labelText = nil;
        
        // Create sublabel
        self.baseLabelOrigin = CGPointMake(self.baseLeftBuffer, 0);
        self.baseLabelFrame = CGRectMake(self.baseLabelOrigin.x, self.baseLabelOrigin.y, (self.bounds.size.width - self.baseRightBuffer), self.bounds.size.height);
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
    
    // Determine if the label needs to scroll (if label frame is larger than enclosing frame)
    if ((self.subLabel.frame.size.width - self.baseRightBuffer) > self.frame.size.width) {
        
        // Calculate the destination frame
        CGRect finalSubLabelFrame = self.subLabel.frame;
        finalSubLabelFrame.origin.x = self.frame.size.width - self.subLabel.frame.size.width;
        
        // Calculate duration
        NSTimeInterval animationDuration = (self.rate > 0.0 ? (fabs(finalSubLabelFrame.origin.x) / self.rate) : self.scrollSpeed);
        
        // Perform animation
        //NSLog(@"Scrolling left: %@", self.labelText);
        self.awayFromHome = YES;
        [UIView animateWithDuration:animationDuration
                              delay:1.0 
                            options:self.animationOptions
                         animations:^{self.subLabel.frame = finalSubLabelFrame;}
                         completion:^(BOOL finished) {
                             //NSLog(@"Done scrolling left: %@", self.labelText);
                             //[self scrollRightWithSpeed:speed];
                             
                         }];
    } else {
        //NSLog(@"Not scrolling (%f < %f)", (self.subLabel.frame.size.width - self.baseRightBuffer), self.frame.size.width);
    }
    
}

- (void)scrollRightWithSpeed:(NSTimeInterval)speed {
    
    // Calculate the destination frame
    CGRect returnLabelFrame = CGRectMake(self.baseLabelOrigin.x, 0, self.subLabel.frame.size.width, self.subLabel.frame.size.height);
    // Perform animation
    //NSLog(@"Scrolling right");
    [UIView animateWithDuration:speed
                          delay:0.2
                        options:(UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{self.subLabel.frame = returnLabelFrame;}
                     completion:^(BOOL finished){
                         //NSLog(@"Done scrolling right: %@", self.labelText);
                         self.awayFromHome = NO;
                         if ((self.subLabel.frame.size.width - self.baseRightBuffer) > self.frame.size.width) {
                             
                             [self scrollLeftWithSpeed:speed];
                         }
                         
                     }];
}

- (void)returnLabelToOrigin {
    
    [UIView animateWithDuration:0
                          delay:0
                        options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState) 
                     animations:^{
                         self.subLabel.frame = self.baseLabelFrame;
                     }
                     completion:^(BOOL finished){
                         self.awayFromHome = NO;
                         //NSLog(@"Returned label home: %@", self.labelText);
                     }];
}

// Custom labelize mutator to restart scrolling after changing labelize to NO
- (void)setLabelize:(BOOL)function {

    if (function) {
        
        labelize = YES;
        if (self.subLabel) {
            [self returnLabelToOrigin];
        }
        
    } else {
        
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
    
    if (newText != self.labelText) {
        
        // Set labelText to incoming newText
        self.labelText = newText;
        
        // Calculate label size
        CGSize maximumLabelSize = CGSizeMake(9999, self.frame.size.height);
        CGSize expectedLabelSize = [self.labelText sizeWithFont:self.subLabel.font
                                       constrainedToSize:maximumLabelSize
                                           lineBreakMode:self.subLabel.lineBreakMode];
        CGRect newBaseLabelFrame = CGRectMake(self.baseLabelOrigin.x, self.baseLabelOrigin.y, (expectedLabelSize.width + self.baseRightBuffer), expectedLabelSize.height);
        self.baseLabelFrame = newBaseLabelFrame;
        
        if (!self.labelize) {
            
            if (self.awayFromHome | (self.subLabel.frame.origin.x != self.baseLabelOrigin.x)) {

                //NSLog(@"Label not at home: %@", self.labelText);
                // Store current alpha
                self.baseAlpha = self.subLabel.alpha;

                // 
                [UIView animateWithDuration:0.1
                                      delay:0.0 
                                    options:(UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState)
                                 animations:^{self.subLabel.alpha = 0.0;}
                                 completion:^(BOOL finished){
                                     
                                     // Animate move immediately
                                     [self returnLabelToOrigin];
                                     
                                     // Set frame and text while invisible
                                     self.subLabel.frame = newBaseLabelFrame;
                                     self.subLabel.text = self.labelText;
                                     
                                     // Fade in quickly
                                     [UIView animateWithDuration:0.1
                                                           delay:0.0
                                                         options:(UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState)
                                                      animations:^{ self.subLabel.alpha = self.baseAlpha; }
                                                      completion:^(BOOL finished){
                                                          //NSLog(@"Starting scroll: %@", self.labelText);
                                                          [self scrollLeftWithSpeed:self.scrollSpeed];
                                                      }];
                                 }];
                      
                //end of animation blocks
                
            } else {
                //NSLog(@"2. At home: %@", self.labelText);
                // Label at home, animate text change
                
                // Store current alpha
                self.baseAlpha = self.subLabel.alpha;
                
                // Fade out quickly
                [UIView animateWithDuration:0.2
                                      delay:0.0 
                                    options:(UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState)
                                 animations:^{
                                     self.subLabel.alpha = 0.0;
                                 }
                                 completion:^(BOOL finished){
                                     
                                     // Set text while invisible
                                     self.subLabel.frame = newBaseLabelFrame;
                                     //NSLog(@"homeLabelFrame: %.0f, %.0f, %.0f, %.0f", homeLabelFrame.origin.x, homeLabelFrame.origin.y, homeLabelFrame.size.width, homeLabelFrame.size.height);
                                     self.subLabel.text = self.labelText;
                                     //NSLog(@"Setting new text");
                                     // Fade in quickly
                                     [UIView animateWithDuration:0.2
                                                           delay:0.0
                                                         options:(UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState)
                                                      animations:^{
                                                          self.subLabel.alpha = 1.0;
                                                      }
                                                      completion:^(BOOL finished){
                                                          self.awayFromHome = NO;
                                                          //NSLog(@"Finished setting text and animations, option to scroll");
                                                          if (self.subLabel.frame.size.width > self.frame.size.width) {
                                                              // Scroll
                                                              //NSLog(@"Starting scroll: %@", self.labelText);
                                                              [self scrollLeftWithSpeed:self.scrollSpeed];
                                                          }
                                                      }];
                                 }]; // end of animation block
            }
                
        } else {
            
            // Currently labelized
            self.subLabel.frame = newBaseLabelFrame;
            self.subLabel.text = self.labelText;
            
        }
    }
}

- (NSString *)text {
    
    return self.labelText;
    
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
#pragma mark Custom Getters and Setters


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
    [labelText release];
    [subLabel release];
    [super dealloc];
}


@end
