//
//  Created by Artem M on 6/24/19.
//  Copyright © 2019 Developer. All rights reserved.
//

import Foundation
import CoreData

public protocol AnalyticsEventTrackerDelegate: class {
    
    // reachabilityUpdater must be called after network reachability changes
    func setupNetworkReachability(reachabilityUpdater: @escaping (Bool) -> Void) -> Void
    
    func networkReachable() -> Bool
    
}

public typealias AnalyticsEventTrackerLogger = (Error) -> Void

public typealias DestinationSender = (String, @escaping (Bool) -> Void) -> Void

public class AnalyticsEventTracker: DestinationTrackerDelegate {
    
    // Needed to prevent runtime error
    final class PersistentContainer: NSPersistentContainer { }
    
    private let coreDataModelName = "CoreDataModels"

    private lazy var writeContext: NSManagedObjectContext = {
        return self.persistentContainer.newBackgroundContext()
    }()
    
    private let writeQueue = DispatchQueue(label: "WriteQueue", qos: .userInitiated)

    private var internetReachable = true
    private let internetReachabilitySemaphore = DispatchSemaphore(value: 1)
    private var destinationTrackers: [String : DestinationTracker] = [:]
    
    public var logger: AnalyticsEventTrackerLogger = { error in
        #if DEBUG
        print(error)
        #endif
    }

    private lazy var persistentContainer: PersistentContainer = {
        let container = PersistentContainer(name: coreDataModelName)
        
        container.loadPersistentStores(completionHandler: { [weak self] (storeDescription, error) in
            if let error = error {
                self?.logger(error)
            }
        })
        return container
    }()

    public init(internetReachability: AnalyticsEventTrackerDelegate) {
        setupReachability(internetReachability)
    }

    private func setupReachability(_ reachabilityDelegate: AnalyticsEventTrackerDelegate) {
        updateInternetReachability(reachabilityDelegate.networkReachable())
        
        reachabilityDelegate.setupNetworkReachability { [weak self] reachable in
            self?.updateInternetReachability(reachable)
        }
    }

    public func addDestinationSender(destination: String, waitTimeSec: UInt32 = 0, sender: @escaping DestinationSender) {
        if destinationTrackers[destination] != nil {
            return
        }

        let tracker = DestinationTracker(
                context: persistentContainer.newBackgroundContext(),
                destination: destination,
                waitTimeSec: waitTimeSec,
                analyticsDelegate: self,
                destinationSender: sender)

        destinationTrackers[destination] = tracker
    }

    public func send(event: String, destination: String) {
        send(event: event, destinations: [destination])
    }

    public func send(event: String, destinations: [String]) {
        writeQueue.async(execute: { [weak self] in
            guard let context = self?.writeContext else {
                return
            }

            var newEvent = AnalyticsEvent(context)
            newEvent.id = Int(Date().timeIntervalSince1970 * 1000)
            newEvent.body = event
            newEvent.destinations = destinations

            do {
                try context.save()
            } catch {
                self?.logger(error)
            }
        })
    }

    private func updateInternetReachability(_ reachable: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.internetReachabilitySemaphore.wait()
            self?.internetReachable = reachable
            self?.internetReachabilitySemaphore.signal()
        }
    }
    
    func shouldSendEvents() -> Bool {
        var result = false
        internetReachabilitySemaphore.wait()
        result = internetReachable
        internetReachabilitySemaphore.signal()
        return result
    }

    func removeDestinationFromRecord(id: Int, destination: String) {
        writeQueue.async(execute: { [weak self] in
            guard let context = self?.writeContext else {
                return
            }

            let request: NSFetchRequest<NSFetchRequestResult> = Event.fetchRequest()
            request.predicate = NSPredicate(format: "\(AnalyticsEvent.idKey) = %@", id.description)

            do {
                let result = try context.fetch(request)

                if result.isEmpty {
                    return
                }

                var event = AnalyticsEvent(result.first as! NSManagedObject)

                if event.destinations.count < 2 {
                    context.delete(event.entity)
                } else {
                    event.destinations.removeAll(where: { d in d == destination })
                    context.refresh(event.entity, mergeChanges: true)
                }

                try context.save()
            } catch {
                self?.logger(error)
            }
        })
    }
    
    func log(error: Error) {
        logger(error)
    }
}

