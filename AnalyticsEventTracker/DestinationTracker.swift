//
// Created by Artem M on 2019-06-27.
// Copyright (c) 2019 Developer. All rights reserved.
//

import CoreData

protocol DestinationTrackerDelegate: class {
    func shouldSendEvents() -> Bool
    func removeDestinationFromRecord(id: Int, destination: String)
    func log(error: Error)
}

class DestinationTracker {

    private let workQueue: DispatchQueue
    private let context: NSManagedObjectContext
    private let destination: String
    private let waitTimeSec: UInt32
    private weak var delegate: DestinationTrackerDelegate?
    private let sendToDestination: DestinationSender
    private let workQueueQoS: DispatchQoS = .background
    private let destinationSenderQoS: DispatchQoS.QoSClass = .background
    private let destinationSenderSemaphore = DispatchSemaphore(value: 0)

    public init(
        context: NSManagedObjectContext,
        destination: String,
        waitTimeSec: UInt32 = 0,
        analyticsDelegate: DestinationTrackerDelegate,
        destinationSender: @escaping DestinationSender) {
        
        self.context = context
        self.destination = destination
        self.delegate = analyticsDelegate
        self.sendToDestination = destinationSender
        self.workQueue = DispatchQueue.init(label: "WorkQueue for \(destination)", qos: workQueueQoS)
        if waitTimeSec > 0 {
            self.waitTimeSec = waitTimeSec
        } else {
            self.waitTimeSec = 30
        }

        startTracking()
    }

    private func startTracking() {
        workQueue.async(execute: { [weak self] in

            guard let destination = self?.destination,
                let context = self?.context,
                let destinationSenderQoS = self?.destinationSenderQoS,
                let waitTimeSec = self?.waitTimeSec else {
                return
            }

            func pauseThread() {
                sleep(waitTimeSec)
            }

            var eventSent = false
            var lastProcessedId = 0
            weak var destinationSemaphore = self?.destinationSenderSemaphore

            // send events until the parent class is destroyed
            while true {
                if self == nil {
                    return
                }

                let request: NSFetchRequest<NSFetchRequestResult> = Event.fetchRequest()

                let sortDescriptor = NSSortDescriptor(key: AnalyticsEvent.idKey, ascending: true)
                request.sortDescriptors = [sortDescriptor]
                request.fetchLimit = 10
                request.predicate = NSPredicate(format: "\(AnalyticsEvent.idKey) > %@", lastProcessedId.description)

                do {
                    let result = try context.fetch(request)

                    if result.isEmpty {
                        pauseThread()
                    } else {

                        lastProcessedId = AnalyticsEvent(result.last as! NSManagedObject).id

                        for data in result as! [NSManagedObject] {
                            let event = AnalyticsEvent(data)

                            if !event.destinations.contains(destination) {
                                continue
                            }

                            while !eventSent {
                                
                                // return if the parent class is destroyed
                                guard let shouldSendEvents = self?.delegate?.shouldSendEvents() else {
                                    return
                                }
                                if !shouldSendEvents {
                                    pauseThread()
                                    continue
                                }

                                DispatchQueue.global(qos: .background).async(execute: {
                                    self?.sendToDestination(event.body, { success in
                                        eventSent = success
                                        destinationSemaphore?.signal()
                                    })
                                })
                                destinationSemaphore?.wait()
                                if !eventSent {
                                    sleep(1)
                                }
                            }

                            self?.delegate?.removeDestinationFromRecord(id: event.id, destination: destination)

                            eventSent = false
                        }
                    }
                } catch {
                    self?.delegate?.log(error: error)
                }
            }
        })
    }
    
    deinit {
        // notify workQueue if it's sleeping
        destinationSenderSemaphore.signal()
    }
}
