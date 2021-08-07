//
//  MarqueeLabelDemoPushController.swift
//  MarqueeLabelDemo
//
//  Created by Charles Powell on 3/26/16.
//
//

import UIKit

class MarqueeLabelDemoPushController: UIViewController {
    @IBOutlet weak var demoLabel: MarqueeLabel!
    @IBOutlet weak var labelLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        demoLabel.type = MarqueeLabel.MarqueeType.allCases.randomElement() ?? .continuous
        // Set label label text
        labelLabel.text = { () -> String in
            switch demoLabel.type {
            case .continuous:
                return "Continuous scrolling"
            case .continuousReverse:
                return "Continuous Reverse scrolling"
            case .left:
                return "Left-Only scrolling"
            case .leftRight:
                return "Left-Right scrolling"
            case .right:
                return "Right-Only scrolling"
            case .rightLeft:
                return "Right-Left scrolling"
            }
        }()
        
        demoLabel.speed = .duration(15)
        demoLabel.animationCurve = .easeInOut
        demoLabel.fadeLength = 10.0
        demoLabel.leadingBuffer = 30.0
        
        let strings = ["When shall we three meet again in thunder, lightning, or in rain? When the hurlyburly's done, When the battle 's lost and won.",
                       "I have no spur to prick the sides of my intent, but only vaulting ambition, which o'erleaps itself, and falls on the other.",
                       "Double, double toil and trouble; Fire burn, and cauldron bubble.",
                       "By the pricking of my thumbs, Something wicked this way comes.",
                       "My favorite things in life don't cost any money. It's really clear that the most precious resource we all have is time.",
                       "Be a yardstick of quality. Some people aren't used to an environment where excellence is expected."]
        
        demoLabel.text = strings[Int(arc4random_uniform(UInt32(strings.count)))]
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.didTap(_:)))
        tapRecognizer.numberOfTapsRequired = 1
        tapRecognizer.numberOfTouchesRequired = 1
        demoLabel.addGestureRecognizer(tapRecognizer)
        demoLabel.isUserInteractionEnabled = true
    }
    
    @objc func didTap(_ recognizer: UIGestureRecognizer) {
        let label = recognizer.view as! MarqueeLabel
        if recognizer.state == .ended {
            label.isPaused ? label.unpauseLabel() : label.pauseLabel()
            // Convert tap points
            let tapPoint = recognizer.location(in: label)
            print("Frame coord: \(tapPoint)")
            guard let textPoint = label.textCoordinateForFramePoint(tapPoint) else {
                return
            }
            print(" Text coord: \(textPoint)")
            
            // Thanks to Toomas Vahter for the basis of the below
            // https://augmentedcode.io/2020/12/20/opening-hyperlinks-in-uilabel-on-ios/
            // Create layout manager
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: label.textLayoutSize())
            textContainer.lineFragmentPadding = 0
            // Create text storage
            guard let text = label.text else { return }
            let textStorage = NSTextStorage(string: "")
            textStorage.setAttributedString(label.attributedText!)
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            textContainer.lineBreakMode = label.lineBreakMode
            textContainer.size = label.textRect(forBounds: CGRect(origin: .zero, size:label.textLayoutSize()), limitedToNumberOfLines: label.numberOfLines).size
            
            let characterIndex = layoutManager.characterIndex(for: textPoint, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            guard characterIndex >= 0, characterIndex != NSNotFound else {
                print("No character at point found!")
                return
            }
            
            let stringIndex = text.index(text.startIndex, offsetBy: characterIndex)
            // Print character under touch point
            print("Character under touch point: \(text[stringIndex])")
        }
    }
    
}
