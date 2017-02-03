//
//  DateTimePicker.swift
//  DateTimePicker
//
//  Created by Huong Do on 9/16/16.
//  Copyright © 2016 ichigo. All rights reserved.
//

import UIKit

// FIXME: This framework's code is a mess, especially this file. My customizations to it are a mess as well (I was in a hurry and just following the pre-existing style). If I end up supporting this control in my app long-term, then this entire lib will need an overhaul so it's easier to maintain.

@objc open class DateTimePicker: UIView {
    
    let contentHeight: CGFloat = 310
    
    public enum TimeMode: Int {
        case twelveHour = 12
        case twentyFourHour = 24
    }
    
    // public vars
    
    public var timeMode: TimeMode = .twentyFourHour
    
    public var doneButtonAlpha: CGFloat = 0.5 {
        didSet {
            configureView()
        }
    }
    
    public var font: ((CGFloat) -> UIFont) = { UIFont.systemFont(ofSize: $0) } {
        didSet {
            configureView()
        }
    }
    
    public var backgroundViewColor: UIColor = .clear {
        didSet {
            backgroundColor = backgroundViewColor
        }
    }
    
    open var highlightColor = UIColor(red: 0/255.0, green: 199.0/255.0, blue: 194.0/255.0, alpha: 1) {
        didSet {
            todayButton.setTitleColor(highlightColor, for: .normal)
            colonLabel.textColor = highlightColor
        }
    }
    
    public var darkColor = UIColor(red: 0, green: 22.0/255.0, blue: 39.0/255.0, alpha: 1)
    
    public var daysBackgroundColor = UIColor(red: 239.0/255.0, green: 243.0/255.0, blue: 244.0/255.0, alpha: 1)
    
    var didLayoutAtOnce = false
    open override func layoutSubviews() {
        super.layoutSubviews()
        // For the first time view will be layouted manually before show
        // For next times we need relayout it because of screen rotation etc.
        if !didLayoutAtOnce {
            didLayoutAtOnce = true
        } else {
            self.configureView()
        }
    }
    
    public var selectedDate = Date() {
        didSet {
            resetDateTitle()
        }
    }
    
    public var dateFormat = "HH:mm dd/MM/YYYY" {
        didSet {
            resetDateTitle()
        }
    }
    
    public var todayButtonTitle = "Today" {
        didSet {
            todayButton.setTitle(todayButtonTitle, for: .normal)
            let size = todayButton.sizeThatFits(CGSize(width: 0, height: 44.0)).width + 10.0
            todayButton.frame = CGRect(x: contentView.frame.width - size, y: 0, width: size, height: 44)
        }
    }
    public var doneButtonTitle = "DONE" {
        didSet {
            doneButton.setTitle(doneButtonTitle, for: .normal)
        }
    }
    public var completionHandler: ((Date)->Void)?
    
    // private vars
    internal var hourTableView: UITableView!
    internal var minuteTableView: UITableView!
    internal var dayCollectionView: UICollectionView!
    internal var amPMSegmentedControl: UISegmentedControl!
    
    internal enum AMOrPM: Int {
        case am
        case pm
    }
    
    internal var amOrPM: AMOrPM {
        let hour = Calendar.current.dateComponents([.hour], from: self.selectedDate).hour ?? 0
        let amPM: AMOrPM = (hour >= 0 && hour <= 11) ? .am : .pm
        return amPM
    }
    
    private var contentView: UIView!
    private var dateTitleLabel: UILabel!
    private var todayButton: UIButton!
    private var doneButton: UIButton!
    private var colonLabel: UILabel!
    
    private var minimumDate: Date!
    private var maximumDate: Date!
    
    internal let minutesInHour = 60
    internal var calendar: Calendar = .current
    internal var dates: [Date]! = []
    internal var components: DateComponents!
    
    public init(selected: Date? = nil, minimumDate: Date? = nil, maximumDate: Date? = nil) {
        super.init(frame: .zero)
        selectedDate = selected ?? Date()
        self.minimumDate = minimumDate ?? Date(timeIntervalSinceNow: -3600 * 24 * 365 * 20)
        self.maximumDate = maximumDate ?? Date(timeIntervalSinceNow: 3600 * 24 * 365 * 20)
        assert(self.minimumDate.compare(self.maximumDate) == .orderedAscending, "Minimum date should be earlier than maximum date")
        assert(self.minimumDate.compare(self.selectedDate) != .orderedDescending, "Selected date should be later or equal to minimum date")
        assert(self.selectedDate.compare(self.maximumDate) != .orderedDescending, "Selected date should be earlier or equal to maximum date")
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func addToWindow() {
        UIApplication.shared.keyWindow?.addSubview(self)
    }
    
    open override func didMoveToSuperview() {
        self.configureView()
    }
    
    private func configureView() {
        if self.contentView != nil {
            self.contentView.removeFromSuperview()
        }
        let screenSize = UIScreen.main.bounds.size
        self.frame = CGRect(x: 0,
                            y: 0,
                            width: screenSize.width,
                            height: screenSize.height)
        
        // content view
        contentView = UIView(frame: CGRect(x: 0,
                                           y: frame.height,
                                           width: frame.width,
                                           height: contentHeight))
        contentView.layer.shadowColor = UIColor(white: 0, alpha: 0.3).cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: -2.0)
        contentView.layer.shadowRadius = 1.5
        contentView.layer.shadowOpacity = 0.5
        contentView.backgroundColor = .white
        contentView.isHidden = true
        addSubview(contentView)
        
        // title view
        let titleView = UIView(frame: CGRect(origin: CGPoint.zero,
                                             size: CGSize(width: contentView.frame.width, height: 44)))
        titleView.backgroundColor = .white
        contentView.addSubview(titleView)
        
        dateTitleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
        dateTitleLabel.font = font(15)
        dateTitleLabel.textColor = darkColor
        dateTitleLabel.textAlignment = .center
        resetDateTitle()
        titleView.addSubview(dateTitleLabel)
        
        todayButton = UIButton(type: .system)
        todayButton.setTitle(todayButtonTitle, for: .normal)
        todayButton.setTitleColor(highlightColor, for: .normal)
        todayButton.addTarget(self, action: #selector(DateTimePicker.setToday), for: .touchUpInside)
        todayButton.titleLabel?.font = font(15)
        todayButton.isHidden = self.minimumDate.compare(Date()) == .orderedDescending || self.maximumDate.compare(Date()) == .orderedAscending
        let size = todayButton.sizeThatFits(CGSize(width: 0, height: 44.0)).width + 10.0
        todayButton.frame = CGRect(x: contentView.frame.width - size, y: 0, width: size, height: 44)
        titleView.addSubview(todayButton)
        
        // day collection view
        let layout = StepCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        layout.itemSize = CGSize(width: 75, height: 80)
        
        dayCollectionView = UICollectionView(frame: CGRect(x: 0, y: 44, width: contentView.frame.width, height: 100), collectionViewLayout: layout)
        dayCollectionView.backgroundColor = daysBackgroundColor
        dayCollectionView.showsHorizontalScrollIndicator = false
        dayCollectionView.register(DateCollectionViewCell.self, forCellWithReuseIdentifier: "dateCell")
        dayCollectionView.dataSource = self
        dayCollectionView.delegate = self
        
        let inset = (dayCollectionView.frame.width - 75) / 2
        dayCollectionView.contentInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
        contentView.addSubview(dayCollectionView)
        
        // top & bottom borders on day collection view
        let borderTopView = UIView(frame: CGRect(x: 0, y: titleView.frame.height, width: titleView.frame.width, height: 1))
        borderTopView.backgroundColor = darkColor.withAlphaComponent(0.2)
        contentView.addSubview(borderTopView)
        
        let borderBottomView = UIView(frame: CGRect(x: 0, y: dayCollectionView.frame.origin.y + dayCollectionView.frame.height, width: titleView.frame.width, height: 1))
        borderBottomView.backgroundColor = darkColor.withAlphaComponent(0.2)
        contentView.addSubview(borderBottomView)
        
        // done button
        doneButton = UIButton(type: .system)
        doneButton.frame = CGRect(x: 10, y: contentView.frame.height - 10 - 44, width: contentView.frame.width - 20, height: 44)
        doneButton.setTitle(doneButtonTitle, for: .normal)
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.backgroundColor = darkColor.withAlphaComponent(doneButtonAlpha)
        doneButton.titleLabel?.font = font(13)
        doneButton.layer.cornerRadius = 3
        doneButton.layer.masksToBounds = true
        doneButton.addTarget(self, action: #selector(DateTimePicker.dismissView), for: .touchUpInside)
        contentView.addSubview(doneButton)
        
        let tableViewY = borderBottomView.frame.origin.y + 2
        let tableViewWidth: CGFloat = 60
        let tableViewHeight = doneButton.frame.origin.y - borderBottomView.frame.origin.y - 10
        let tableViewRowHeight: CGFloat = 36
        let tableViewSeparatorStyle = UITableViewCellSeparatorStyle.none
        let tableViewContentInset = UIEdgeInsetsMake(tableViewRowHeight / 2, 0, tableViewRowHeight / 2, 0)
        
        // hour table view
        hourTableView = UITableView(frame: CGRect(x: contentView.frame.width / 2 - tableViewWidth,
                                                  y: tableViewY,
                                                  width: tableViewWidth,
                                                  height: tableViewHeight))
        hourTableView.rowHeight = tableViewRowHeight
        hourTableView.contentInset = tableViewContentInset
        hourTableView.showsVerticalScrollIndicator = false
        hourTableView.separatorStyle = tableViewSeparatorStyle
        hourTableView.delegate = self
        hourTableView.dataSource = self
        contentView.addSubview(hourTableView)
        
        // minute table view
        minuteTableView = UITableView(frame: CGRect(x: contentView.frame.width / 2,
                                                    y: tableViewY,
                                                    width: tableViewWidth,
                                                    height: tableViewHeight))
        minuteTableView.rowHeight = tableViewRowHeight
        minuteTableView.contentInset = tableViewContentInset
        minuteTableView.showsVerticalScrollIndicator = false
        minuteTableView.separatorStyle = tableViewSeparatorStyle
        minuteTableView.delegate = self
        minuteTableView.dataSource = self
        contentView.addSubview(minuteTableView)
        
        // colon
        colonLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 10, height: tableViewRowHeight))
        colonLabel.center = CGPoint(x: contentView.frame.width / 2,
                                    y: (doneButton.frame.origin.y - borderBottomView.frame.origin.y - 10) / 2 + borderBottomView.frame.origin.y)
        colonLabel.text = ":"
        colonLabel.font = font(18)
        colonLabel.textColor = highlightColor
        colonLabel.textAlignment = .center
        contentView.addSubview(colonLabel)
        
        // time separators
        let separatorTopView = UIView(frame: CGRect(x: 0, y: 0, width: 90, height: 1))
        separatorTopView.backgroundColor = darkColor.withAlphaComponent(0.2)
        separatorTopView.center = CGPoint(x: contentView.frame.width / 2, y: borderBottomView.frame.origin.y + 36)
        contentView.addSubview(separatorTopView)
        
        let separatorBottomView = UIView(frame: CGRect(x: 0, y: 0, width: 90, height: 1))
        separatorBottomView.backgroundColor = darkColor.withAlphaComponent(0.2)
        separatorBottomView.center = CGPoint(x: contentView.frame.width / 2, y: separatorTopView.frame.origin.y + 36)
        contentView.addSubview(separatorBottomView)
        
        // fill date
        fillDates(fromDate: minimumDate, toDate: maximumDate)
        updateCollectionView(to: selectedDate)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/YYYY"
        for i in 0..<dates.count {
            let date = dates[i]
            if formatter.string(from: date) == formatter.string(from: selectedDate) {
                dayCollectionView.selectItem(at: IndexPath(row: i, section: 0), animated: true, scrollPosition: .centeredHorizontally)
                break
            }
        }
        components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedDate)
        contentView.isHidden = false
        
        
        // am / pm selector
        if timeMode == .twelveHour {
            let rightMostXOfSeparator = separatorTopView.frame.origin.x + separatorTopView.frame.size.width
            let remainingWidthOnRightOfSeparators: CGFloat = frame.size.width - rightMostXOfSeparator
            
            let segmentedControlWidth = remainingWidthOnRightOfSeparators / 1.25
            let segmentedControlHeight = separatorBottomView.frame.origin.y - separatorTopView.frame.origin.y
            
            let segmentedControlXRelativeToSeparators = (remainingWidthOnRightOfSeparators / 2) - (segmentedControlWidth / 2)
            let segmentedControlX = segmentedControlXRelativeToSeparators + rightMostXOfSeparator
            
            amPMSegmentedControl = UISegmentedControl(frame: CGRect(x: segmentedControlX,
                                                                    y: separatorTopView.frame.origin.y,
                                                                    width: segmentedControlWidth,
                                                                    height: segmentedControlHeight))
            amPMSegmentedControl.insertSegment(withTitle: "am", at: 0, animated: false)
            amPMSegmentedControl.insertSegment(withTitle: "pm", at: 1, animated: false)
            amPMSegmentedControl.selectedSegmentIndex = amOrPM.rawValue
            amPMSegmentedControl.tintColor = darkColor
            amPMSegmentedControl.addTarget(self, action: #selector(amPMSegmentedControlTapped), for: .valueChanged)
            contentView.addSubview(amPMSegmentedControl)
        }
        
        resetTime()
        
        // animate to show contentView
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.4, options: .curveEaseIn, animations: {
            self.contentView.frame = CGRect(x: 0,
                                            y: self.frame.height - self.contentHeight,
                                            width: self.frame.width,
                                            height: self.contentHeight)
        }, completion: nil)
    }
    
    func setToday() {
        selectedDate = Date()
        resetTime()
    }
    
    func resetTime() {
        components = calendar.dateComponents([.day, .month, .year, .hour, .minute], from: selectedDate)
        updateCollectionView(to: selectedDate)
        if let hour = components.hour {
            hourTableView.selectRow(at: IndexPath(row: hour + timeMode.rawValue, section: 0), animated: true, scrollPosition: .middle)
        }
        
        if let minute = components.minute {
            let expectedRow = minute == 0 ? 120 : minute + minutesInHour // workaround for issue when minute = 0
            minuteTableView.selectRow(at: IndexPath(row: expectedRow, section: 0), animated: true, scrollPosition: .middle)
        }
        
        if timeMode == .twelveHour {
            amPMSegmentedControl.selectedSegmentIndex = amOrPM.rawValue
        }
    }
    
    private func resetDateTitle() {
        guard dateTitleLabel != nil else {
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        dateTitleLabel.text = formatter.string(from: selectedDate)
        dateTitleLabel.sizeToFit()
        dateTitleLabel.center = CGPoint(x: contentView.frame.width / 2, y: 22)
    }
    
    internal func amPMSegmentedControlTapped(_ sender: UISegmentedControl) {
        guard let selectedAMOrPM = AMOrPM(rawValue: sender.selectedSegmentIndex) else {
            assertionFailure("Invalid selected segment index. This should not happen")
            return
        }
        
        guard let currentHour = components.hour else { return }
        
        let hourDiff = 12
        if selectedAMOrPM == .am {
            components.hour = currentHour - hourDiff
        } else {
            components.hour = currentHour + hourDiff
        }
        
        if let selected = calendar.date(from: components) {
            selectedDate = selected
        }
    }
    
    internal func updateSelectedDate(for tableView: UITableView, at row: Int) {
        // add 24 or 12 to hour and 60 to minute, because datasource now has buffer at top and bottom.
        if tableView == hourTableView {
            var newHour = (row - timeMode.rawValue) % timeMode.rawValue
            if amOrPM == .pm {
                newHour += 12
            }
            components.hour = newHour
        } else if tableView == minuteTableView {
            components.minute = (row - 60) % 60
        }
        
        if let selected = calendar.date(from: components) {
            selectedDate = selected
        }
    }
    
    func fillDates(fromDate: Date, toDate: Date) {
        
        var dates: [Date] = []
        var days = DateComponents()
        
        var dayCount = 0
        repeat {
            days.day = dayCount
            dayCount += 1
            guard let date = calendar.date(byAdding: days, to: fromDate) else {
                break;
            }
            if date.compare(toDate) == .orderedDescending {
                break
            }
            dates.append(date)
        } while (true)
        
        self.dates = dates
        dayCollectionView.reloadData()
        
        if let index = self.dates.index(of: selectedDate) {
            dayCollectionView.selectItem(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .centeredHorizontally)
        }
    }
    
    func updateCollectionView(to currentDate: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/YYYY"
        for i in 0..<dates.count {
            let date = dates[i]
            if formatter.string(from: date) == formatter.string(from: currentDate) {
                let indexPath = IndexPath(row: i, section: 0)
                dayCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: { 
                    self.dayCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
                })
                
                break
            }
        }
    }
    
    func dismissView() {
        UIView.animate(withDuration: 0.3, animations: {
            // animate to show contentView
            self.contentView.frame = CGRect(x: 0,
                                            y: self.frame.height,
                                            width: self.frame.width,
                                            height: self.contentHeight)
        }) { (completed) in
            self.completionHandler?(self.selectedDate)
            self.removeFromSuperview()
        }
    }
}

extension DateTimePicker: UITableViewDataSource, UITableViewDelegate {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == hourTableView {
            // need triple of origin storage to scroll infinitely
            return timeMode.rawValue * 3
        }
        // need triple of origin storage to scroll infinitely
        return 60 * 3
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "timeCell") ?? UITableViewCell(style: .default, reuseIdentifier: "timeCell")
        
        cell.selectedBackgroundView = UIView()
        cell.textLabel?.textAlignment = tableView == hourTableView ? .right : .left
        cell.textLabel?.font = font(18)
        cell.textLabel?.textColor = darkColor.withAlphaComponent(0.4)
        cell.textLabel?.highlightedTextColor = highlightColor
        
        // add module operation to set value same
        var hourOrMinute = indexPath.row % (tableView == hourTableView ? timeMode.rawValue : minutesInHour)
        if timeMode == .twelveHour && hourOrMinute == 0 {
            hourOrMinute = timeMode.rawValue
        }
        cell.textLabel?.text = String(format: "%02i", hourOrMinute)
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
        updateSelectedDate(for: tableView, at: indexPath.row)
    }
    
    // for infinite scrolling, use modulo operation.
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView != dayCollectionView else {
            return
        }
        let totalHeight = scrollView.contentSize.height
        let visibleHeight = totalHeight / 3.0
        if scrollView.contentOffset.y < visibleHeight || scrollView.contentOffset.y > visibleHeight + visibleHeight {
            let positionValueLoss = scrollView.contentOffset.y - CGFloat(Int(scrollView.contentOffset.y))
            let heightValueLoss = visibleHeight - CGFloat(Int(visibleHeight))
            let modifiedPotisionY = CGFloat(Int( scrollView.contentOffset.y ) % Int( visibleHeight ) + Int( visibleHeight )) - positionValueLoss - heightValueLoss
            scrollView.contentOffset.y = modifiedPotisionY
        }
    }
}

extension DateTimePicker: UICollectionViewDataSource, UICollectionViewDelegate {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dates.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "dateCell", for: indexPath) as! DateCollectionViewCell
        
        let date = dates[indexPath.item]
        cell.populateItem(date: date, highlightColor: highlightColor, darkColor: darkColor)
        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        //workaround to center to every cell including ones near margins
        if let cell = collectionView.cellForItem(at: indexPath) {
            let offset = CGPoint(x: cell.center.x - collectionView.frame.width / 2, y: 0)
            collectionView.setContentOffset(offset, animated: true)
        }
        
        // update selected dates
        let date = dates[indexPath.item]
        let dayComponent = calendar.dateComponents([.day, .month, .year], from: date)
        components.day = dayComponent.day
        components.month = dayComponent.month
        components.year = dayComponent.year
        if let selected = calendar.date(from: components) {
            selectedDate = selected
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        alignScrollView(scrollView)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            alignScrollView(scrollView)
        }
    }
    
    func alignScrollView(_ scrollView: UIScrollView) {
        if let collectionView = scrollView as? UICollectionView {
            let centerPoint = CGPoint(x: collectionView.center.x + collectionView.contentOffset.x, y: 50)
            if let indexPath = collectionView.indexPathForItem(at: centerPoint) {
                // automatically select this item and center it to the screen
                // set animated = false to avoid unwanted effects
                collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .top)
                if let cell = collectionView.cellForItem(at: indexPath) {
                    let offset = CGPoint(x: cell.center.x - collectionView.frame.width / 2, y: 0)
                    collectionView.setContentOffset(offset, animated: false)
                }
                
                // update selected date
                let date = dates[indexPath.item]
                let dayComponent = calendar.dateComponents([.day, .month, .year], from: date)
                components.day = dayComponent.day
                components.month = dayComponent.month
                components.year = dayComponent.year
                if let selected = calendar.date(from: components) {
                    selectedDate = selected
                }
            }
        } else if let tableView = scrollView as? UITableView {
            let relativeOffset = CGPoint(x: 0, y: tableView.contentOffset.y + tableView.contentInset.top )
            // change row from var to let.
            let row = round(relativeOffset.y / tableView.rowHeight)
            tableView.selectRow(at: IndexPath(row: Int(row), section: 0), animated: true, scrollPosition: .middle)
            
            updateSelectedDate(for: tableView, at: Int(row))
        }
    }
}
