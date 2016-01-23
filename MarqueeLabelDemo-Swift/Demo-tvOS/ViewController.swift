//
//  ViewController.swift
//  Demo-tvOS
//
//  Created by toshi0383 on 1/9/16.
//  Copyright © 2016 Charles Powell. All rights reserved.
//

import UIKit

let labels = [
    "Hello Hello Hello World.",
    "Hello Hello Hello Hello Hello World.",
    "Hello Hello Hello Hello Hello Hello World.",
    "Hello Hello Hello Hello Hello Hello Hello World.",
    "Hello Hello Hello Hello Hello Hello Hello World.",
    "Hello Hello Hello Hello Hello Hello Hello World.",
    "Hello Hello Hello Hello Hello Hello Hello World."]

let defaultScrollDuration: CGFloat = 20.0

class ViewController: UIViewController {

    @IBOutlet var marqueeTableView: UITableView!
    @IBOutlet var labelTableview: LabelTableView!


    override func viewDidLoad() {
        super.viewDidLoad()
        // MarqueeLabel Tableview
        marqueeTableView.dataSource = self
        marqueeTableView.delegate = self
        
        // Basic UILabel Tableview
        labelTableview.dataSource = labelTableview
    }

}

typealias CellType = TableViewCell

extension ViewController: UITableViewDataSource {

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return labels.count * 8
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = marqueeTableView.dequeueReusableCellWithIdentifier("Cell") as! CellType!
        cell.marquee.text = labels[indexPath.row % labels.count]
        cell.marquee.labelize = true
        cell.marquee.fadeLength = 7.0
        cell.marquee.scrollDuration = defaultScrollDuration
        cell.marquee.lineBreakMode = .ByTruncatingTail
        return cell
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didUpdateFocusInContext context: UITableViewFocusUpdateContext, withAnimationCoordinator coordinator: UIFocusAnimationCoordinator) {
        if let previouslyFocusedIndexPath = context.previouslyFocusedIndexPath {
            let previous = tableView.cellForRowAtIndexPath(previouslyFocusedIndexPath) as! CellType!
            previous?.marquee.labelize = true
        }
        if let nextFocusedIndexPath = context.nextFocusedIndexPath {
            let next = tableView.cellForRowAtIndexPath(nextFocusedIndexPath) as! CellType!
            next?.marquee.labelize = false
        }
    }
}

class TableViewCell: UITableViewCell {
    @IBOutlet var marquee: MarqueeLabel!
}

class LabelTableView: UITableView {
}

extension LabelTableView: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return labels.count * 8
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.dequeueReusableCellWithIdentifier("Default") as UITableViewCell!
        let ind = indexPath.row % labels.count
        cell.textLabel?.text = labels[ind]
        return cell
    }
}

