//
//  TockBeepViewController.swift
//  Tock
//
//  Created by Kevin Turner on 7/10/16.
//  Copyright © 2016 Kevin Turner. All rights reserved.
//

import UIKit
import SafariServices
import AVFoundation

class TockBeepViewController: UIViewController, AVSpeechSynthesizerDelegate, UITableViewDelegate, UITableViewDataSource, AVAudioPlayerDelegate, UIViewControllerTransitioningDelegate {
    var wakeUps: [wakeUpTypes:TockWakeUp]?
    var verbals: [wakeUpTypes:[String]] = [:]
    var indexes: [wakeUpTypes] = []
    var tableIndexes: [wakeUpTypes] = []
    var newsArticles: [Int : [NewsItem]] = [Int : [NewsItem]]()
    let synth = AVSpeechSynthesizer()
    var myUtterance = AVSpeechUtterance(string: "")
    var headers: [String] = [String]()
    var index = 0
    var i = 0
    var lastOffset : CGFloat = 0.0
    var paused = false
    var rate = 0.5
    var completedNews = false
    @IBOutlet weak var controlStrip: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var MorningView: UIView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var greetingLabel: UILabel!
    let pop = PopTransitionDelegate()
    
    @IBOutlet weak var playPauseButton: UIButton!
    var greeting = "Afternoon!"
    let userDefaults = UserDefaults.standard
    
    override func viewDidLoad() {
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 140
        tableView.rowHeight = UITableViewAutomaticDimension
        UIDevice.current.isProximityMonitoringEnabled = false
        
        super.viewDidLoad()
        let gradient = CAGradientLayer()
        gradient.frame = view.frame
        gradient.colors = [UIColor(red: 1, green: 0.4393680155, blue: 0.001996452746, alpha: 1).cgColor, UIColor(red: 1, green: 0.7662689211, blue: 0.3382564307, alpha: 1).cgColor]
        
        view.layer.insertSublayer(gradient, below: MorningView.layer)
        
        
        
        let defaultRate = userDefaults.double(forKey: speechSpeedKey)
        if defaultRate != 0 {
            rate = defaultRate
        } else {
            userDefaults.setValue(rate, forKey: speechSpeedKey)
        }
        
       setMorningView()
      
        playGreeting()
        constructVerbals()
        
      
      
    }
    

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func restartButtonPressed(_ sender: Any) {
        self.synth.stopSpeaking(at: AVSpeechBoundary.immediate)
        self.index = 0
        self.i = 0
        wake()
    }
    
  
    @IBAction func playPauseButtonPressed(_ sender: Any) {
        if self.paused {
            self.playPauseButton.setImage(#imageLiteral(resourceName: "pause2.png"), for: .normal)
            self.synth.continueSpeaking()
            self.paused = false
        } else {
            self.playPauseButton.setImage(#imageLiteral(resourceName: "play3.png"), for: .normal)
            self.synth.pauseSpeaking(at: .immediate)
            self.paused = true
        }
    }
    
  
    @IBAction func cancelButtonPressed(_ sender: Any) {
        UIDevice.current.isProximityMonitoringEnabled = true
        self.synth.stopSpeaking(at: AVSpeechBoundary.immediate)
        self.paused = true
        self.performSegue(withIdentifier: "done", sender: self)
    }
    
    func setMorningView(){
        let currentDate = Date()
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let currentComponents = (calendar as NSCalendar?)?.components([.month, .day, .hour], from: currentDate)
        
      
        let currentDay = currentComponents!.day
        let currentHour = currentComponents!.hour
        let currentMonth = currentComponents!.month
        
        self.dateLabel.text = "\(months[currentMonth!-1]), \(currentDay!)"
        
        if currentHour! >= 12 {
            self.greetingLabel.text = "Good Afternoon!"
           self.greeting = "Afternoon!"
        } else {
            self.greetingLabel.text = "Good Morning!"
            self.greeting = "Morning!"
        }
        
    }
    
    func playGreeting(){
        myUtterance = AVSpeechUtterance(string: "Good \(greeting)")
        
        myUtterance.rate = Float(rate)
        synth.delegate = self
        synth.speak(myUtterance)

    }


    func numberOfSections(in tableView: UITableView) -> Int {
//        if let wakeCount = wakeUps?.count {
//            if indexes.contains(.wakeUpTypeNews) {
//                let newsWakeup = wakeUps?[indexes[indexes.index(of: .wakeUpTypeNews)!]] as? NewsTockWakeUp
//                if let news = newsWakeup {
//                    return wakeCount + news.sources.count - 1
//                }
//            }
//            return wakeCount
//        } else {
//            return 0
//        }
        
        return headers.count
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
      
        if offset > 0 {
            let ration = offset/100
           self.MorningView.transform = CGAffineTransform(scaleX: max(1-ration, 0.0), y: max(1-ration, 0.0))
            self.tableView.transform = CGAffineTransform(translationX: 0, y: -min(offset, 100))
            self.controlStrip.transform = CGAffineTransform(translationX: 0, y: -min(offset, 100))
        }
        self.lastOffset = offset
        print("Offset is \(offset)")
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section <= tableIndexes.count - 1{
            if tableIndexes[section] == .wakeUpTypeCal {
                return (wakeUps![tableIndexes[section]] as! CalendarTockWakeUp).eventCount
            } else if tableIndexes[section] == .wakeUpTypeNews {
                return newsArticles[section]!.count
            } else if tableIndexes[section] == .wakeUpTypeReminder {
                return  (wakeUps![tableIndexes[section]] as! RemindersTockWakeUp).reminderCount
            }
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = tableIndexes[indexPath.section]
        let wakeUp = self.wakeUps![type]
        
    if (wakeUp?.fetchSuccess)! {
        switch type {
            case .wakeUpTypeWeather:
                let weatherCell = tableView.dequeueReusableCell(withIdentifier: "weather") as! WeatherCellTableViewCell
                weatherCell.setWakeUp(wakeUp: wakeUp!)
                return weatherCell
                case .wakeUpTypeCal:
                let calCel = tableView.dequeueReusableCell(withIdentifier: "calendar") as! CalCell
                calCel.selectionStyle = .none
                calCel.setWakeUp(wakeUp: wakeUp!, type: .wakeUpTypeCal, index: indexPath.row)
                return calCel
            case .wakeUpTypeTransit:
                let transitCell = tableView.dequeueReusableCell(withIdentifier: "calendar") as! CalCell
                 transitCell.selectionStyle = .none
                transitCell.setWakeUp(wakeUp: wakeUp!, type: .wakeUpTypeTransit, index: indexPath.row)
                return transitCell
            case .wakeUpTypeNews:
                let news = tableView.dequeueReusableCell(withIdentifier: "news") as! NewsCell
                news.selectionStyle = .none
                let newsArt = newsArticles[indexPath.section]
                news.populateCell(news: newsArt![indexPath.row])
                news.selectionStyle = .none
                return news
            case .wakeUpTypeReminder:
                let reminder = tableView.dequeueReusableCell(withIdentifier: "calendar") as! CalCell
                reminder.setWakeUp(wakeUp: wakeUp!, type: .wakeUpTypeReminder, index: indexPath.row)
                reminder.selectionStyle = .none
                return reminder

            }
        } else {
            let failedCell = tableView.dequeueReusableCell(withIdentifier: "failed") as! FailedTableViewCell
            failedCell.setWakeUp(wakeUp!)
            return failedCell
        }
        
    }
//    
//    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        let type = indexes[indexPath.section]
//      
//        if type == .wakeUpTypeCal || type == .wakeUpTypeTransit {
//            return 60
//        } else {
//            return 120
//        }
//    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let sectionLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 25))
        sectionLabel.textColor = UIColor(red: 1, green: 0.4393680155, blue: 0.001996452746, alpha: 1)
        sectionLabel.textAlignment = .center
        
        sectionLabel.font = UIFont(name: "AvenirNext-Regular", size: 15)
    

        sectionLabel.text = headers[section]
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 25))
        headerView.backgroundColor = UIColor.clear
        headerView.addSubview(sectionLabel) 
        headerView.layer.cornerRadius = 10
        headerView.backgroundColor = UIColor.white
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 25.0
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let type = tableIndexes[indexPath.section]
      
        if type == .wakeUpTypeNews {  
            let newsA = newsArticles[indexPath.section]
            let news = newsA![indexPath.row]
            let url = news.url
            if url != nil {
                let safari = SFSafariViewController(url: url!)
                present(safari, animated: true, completion: nil)
            }
         
        } else if type == .wakeUpTypeCal {
            let today = Date()
            let interval = today.timeIntervalSinceReferenceDate
            let url = URL(string: "calshow:\(interval)")
            UIApplication.shared.open(url!, options: [:], completionHandler: nil)
        }
    }
    
    func constructVerbals(){
        print("the number of wakeups is \(wakeUps?.count)")
        if wakeUps != nil{
            let types = WakeUpManager().getWakeUpTypes()
            for type in types! {
                let wake = wakeUpTypes(rawValue: type)!
                
                indexes.append(wake)
                switch wake {
                case .wakeUpTypeCal:
                    headers.append("Events Today")
                     tableIndexes.append(wake)
                    break
                case .wakeUpTypeTransit:
                    headers.append("Transit Time")
                         tableIndexes.append(wake)
                    break
                case .wakeUpTypeWeather:
                    headers.append("Weather")
                        tableIndexes.append(wake)
                break
                case .wakeUpTypeNews:
                    let newsWake = wakeUps![.wakeUpTypeNews] as! NewsTockWakeUp
                  
                        print("The news wake is \(newsWake.newsItems.count)")
                    for newsArr in newsWake.newsItems {
                        tableIndexes.append(wake)
                        headers.append(newsNameForType(type: newsTypes(rawValue: newsArr[0].source)!))
                        newsArticles[tableIndexes.count-1] = newsArr
                        
                    }
                    
                    break
                case .wakeUpTypeReminder:
                        headers.append("Reminders")
                    break
                    

                }
            }
            for (wakeUpType, wakeUp) in wakeUps! {
                print("the thing to verbalize is \(wakeUp.stringsToVerbalize())")
               
                verbals[wakeUpType] = wakeUp.stringsToVerbalize()
            }
            
            print ("the total is \(verbals.count) all verbals \(verbals)")
            
            
        }
    }
    
    func wake(){
        let verbals = self.verbals[indexes[index]]
        print("type is \(indexes[index].rawValue)")
       
      
        
        let verbal = verbals?[i]
        print("verbal \(verbal)")
            if verbal != nil && verbal! != "" {
                myUtterance = AVSpeechUtterance(string: verbal!)
                print("the thing to utter is \(verbal)")
                myUtterance.rate = Float(rate)
                synth.delegate = self
                synth.speak(myUtterance)
                
            }
        
    
    
         i += 1
        print("i is \(i) verbals count is \(verbals?.count)")
        if i == verbals?.count {
            if indexes[index] == .wakeUpTypeNews {
                self.completedNews = true
            }
            i = 0
            index += 1
        }
        
        
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "done" {
            let destVC = segue.destination
            destVC.transitioningDelegate = self
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {

        if index < verbals.count && !paused{
        
            
                wake()
            
        }
    }
    
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return UnwindPopTransition()
    }
    
    
}
