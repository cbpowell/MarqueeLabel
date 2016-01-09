//
//  ViewController.swift
//  Demo-tvOS
//
//  Created by toshi0383 on 1/9/16.
//  Copyright © 2016 Charles Powell. All rights reserved.
//

import UIKit
import MarqueeLabel

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

    @IBOutlet var tableview: UITableView!
    @IBOutlet var defaultTableview: DefaultTableView!
    @IBOutlet weak var marquee1: MarqueeLabel!


    override func viewDidLoad() {
        super.viewDidLoad()
        tableview.dataSource = self
        tableview.delegate = self

        defaultTableview.dataSource = defaultTableview

        marquee1.type = .Continuous
        marquee1.text = labels.last!
        marquee1.scrollDuration = defaultScrollDuration
        marquee1.lineBreakMode = .ByTruncatingHead
    }

}

typealias CellType = TableViewCell

extension ViewController: UITableViewDataSource {

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return labels.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCellWithIdentifier("Cell") as! CellType!
        cell.marquee.text = labels[indexPath.row]
        cell.marquee.fadeLength = 7.0
        cell.marquee.scrollDuration = defaultScrollDuration
        cell.marquee.holdScrolling = true
        cell.marquee.lineBreakMode = NSLineBreakMode(rawValue: indexPath.row % 6)!
        return cell
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didUpdateFocusInContext context: UITableViewFocusUpdateContext, withAnimationCoordinator coordinator: UIFocusAnimationCoordinator) {
        if let previouslyFocusedIndexPath = context.previouslyFocusedIndexPath {
            let previous = tableView.cellForRowAtIndexPath(previouslyFocusedIndexPath) as! CellType!
            previous?.marquee.holdScrolling = true
            previous?.marquee.restartLabel()
            print("\(previouslyFocusedIndexPath.row): stopScrolling")
        }
        if let nextFocusedIndexPath = context.nextFocusedIndexPath {
            let next = tableView.cellForRowAtIndexPath(nextFocusedIndexPath) as! CellType!
            next?.marquee.holdScrolling = false
            print("\(nextFocusedIndexPath.row): startScrolling")
        }
    }
}

class TableViewCell: UITableViewCell {
    @IBOutlet var marquee: MarqueeLabel!
}

class DefaultTableView: UITableView {
}

extension DefaultTableView: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return labels.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.dequeueReusableCellWithIdentifier("Default") as UITableViewCell!
        cell.textLabel?.text = labels[indexPath.row]
        return cell
    }
}

