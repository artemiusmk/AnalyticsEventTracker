//
//  Created by Artem M on 6/25/19.
//  Copyright © 2019 Developer. All rights reserved.
//

import UIKit
import AnalyticsEventTracker

class ViewController: UIViewController, AnalyticsEventTrackerDelegate {
    
    var analyticsTracker: AnalyticsEventTracker?
    @IBOutlet weak var connectionButton: UIButton!
    @IBOutlet weak var eventsCountTextField: UITextField!
    
    enum Destination: String, CaseIterable {
        case firebase, crashlytics, appServer
    }
    
    var mockConnection = true
    var updateReachability: ((Bool) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        analyticsTracker = AnalyticsEventTracker(internetReachability: self)
        
        setupMockSenders()
    }
    
    private func setupMockSenders() {
        analyticsTracker?.addDestinationSender(destination: Destination.crashlytics.rawValue, waitTimeSec: 2) { [weak self] (event, success) in
            let sent = self?.networkReachable() ?? false
            self?.printSendStatus(status: sent, event: event, destination: Destination.crashlytics.rawValue)
            success(sent)
        }
        
        analyticsTracker?.addDestinationSender(destination: Destination.firebase.rawValue, waitTimeSec: 2) { [weak self] (event, success) in
            let sent = self?.networkReachable() ?? false
            self?.printSendStatus(status: sent, event: event, destination: Destination.firebase.rawValue)
            success(sent)
        }
        
        analyticsTracker?.addDestinationSender(destination: Destination.appServer.rawValue, waitTimeSec: 2) { [weak self] (event, success) in
            let sent = self?.networkReachable() ?? false
            self?.printSendStatus(status: sent, event: event, destination: Destination.appServer.rawValue)
            success(sent)
        }
    }
    
    private func printSendStatus(status: Bool, event: String, destination: String) {
        if status {
            print("SENT \(event) for \(destination)")
        } else {
            print("SENDING FAILED \(event) for \(destination)")
        }
    }
    
    @IBAction func send(_ sender: Any) {
        if let cnt = Int(eventsCountTextField.text ?? ""), cnt > 0, cnt < 100000 {
            for i in 0..<cnt {
                analyticsTracker?.send(event: "TestEvent\(i)", destinations: Destination.allCases.map { d -> String in d.rawValue })
            }
            return
        }
        eventsCountTextField.text = ""
    }
    
    @IBAction func switchConnection(_ sender: Any) {
        mockConnection = !mockConnection
        updateReachability?(mockConnection)
        connectionButton.setTitle(mockConnection ? "Switch OFF connection" : "Switch ON connection", for: .normal)
    }
    
    func setupNetworkReachability(reachabilityUpdater: @escaping (Bool) -> Void) {
        // Example for Reachability.swift library
        
        /*reachability?.whenUnreachable = { _ in
         reachabilityUpdater(false)
         }
         reachability?.whenReachable = { _ in
         reachabilityUpdater(true)
         }
         
         do {
         try reachability?.startNotifier()
         } catch {
         print("Unable to start notifier")
         }*/
        
        self.updateReachability = reachabilityUpdater
    }
    
    func networkReachable() -> Bool {
        // Example for Reachability.swift library
        
        // return reachability?.connection != .none
        
        return mockConnection
    }
}

