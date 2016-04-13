//
//  ViewController.swift
//  Demo-tvOS
//
//  Created by toshi0383 on 1/9/16.
//  Copyright © 2016 Charles Powell. All rights reserved.
//

import UIKit

let labels = [
    "Lorem ipsum dolor sit amet.",
    "Lorem ipsum dolor sit amet, consectetur.",
    "Lorem ipsum dolor sit amet, consectetur adipiscing.",
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed id.",
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed id ultricies justo.",
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed id ultricies justo. Praesent eleifend."]

let defaultScrollDuration: CGFloat = 20.0

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet var marqueeTableView: UITableView!
    @IBOutlet var labelTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // MarqueeLabel Tableview
        marqueeTableView.dataSource = self
        marqueeTableView.delegate = self
        
        // Basic UILabel Tableview
        labelTableView.dataSource = self
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return labels.count * 10
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
        cell.cellText = labels[indexPath.row % labels.count]
        return cell
    }
    
    func tableView(tableView: UITableView, didUpdateFocusInContext context: UITableViewFocusUpdateContext, withAnimationCoordinator coordinator: UIFocusAnimationCoordinator) {
        if tableView == marqueeTableView {
            if let previouslyFocusedIndexPath = context.previouslyFocusedIndexPath {
                let previous = tableView.cellForRowAtIndexPath(previouslyFocusedIndexPath) as? MarqueeCell
                previous?.marquee.labelize = true
            }
            if let nextFocusedIndexPath = context.nextFocusedIndexPath {
                let next = tableView.cellForRowAtIndexPath(nextFocusedIndexPath) as? MarqueeCell
                next?.marquee.labelize = false
            }
        }
    }
}

protocol TextCell {
    var cellText: String? { get set }
}

class MarqueeCell: UITableViewCell {
    @IBOutlet var marquee: MarqueeLabel!
    
    override func awakeFromNib() {
        // Perform initial setup
        marquee.labelize = true
        marquee.fadeLength = 7.0
        marquee.speed = .Duration(defaultScrollDuration)
        marquee.lineBreakMode = .ByTruncatingTail
    }
    
    override var cellText: String? {
        get {
            return marquee.text
        }
        set {
            marquee.text = newValue
        }
    }
}

extension UITableViewCell: TextCell {
    var cellText: String? {
        get {
            return textLabel?.text
        }
        set {
            textLabel?.text = newValue
        }
    }
}
