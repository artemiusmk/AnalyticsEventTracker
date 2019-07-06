//
// Created by Artem M on 2019-06-27.
// Copyright (c) 2019 Developer. All rights reserved.
//

import CoreData

@objc(Event)
public class Event: NSManagedObject {}

struct AnalyticsEvent {

    static let idKey = "id"
    static let bodyKey = "body"
    static let destinationsKey = "destinations"
    static let entityName = "Event"

    let entity: NSManagedObject

    init(_ context:  NSManagedObjectContext) {
        let entityDescription = NSEntityDescription.entity(forEntityName: AnalyticsEvent.entityName, in: context)
        entity = NSManagedObject(entity: entityDescription!, insertInto: context)
    }

    init(_ entity:  NSManagedObject) {
        self.entity = entity
    }

    var id: Int {
        set {
            entity.setValue(newValue, forKey: AnalyticsEvent.idKey)
        }
        get {
            return entity.value(forKey: AnalyticsEvent.idKey) as! Int
        }
    }

    var body: String {
        set {
            entity.setValue(newValue, forKey: AnalyticsEvent.bodyKey)
        }
        get {
            return entity.value(forKey: AnalyticsEvent.bodyKey) as? String ?? ""
        }
    }

    var destinations: [String] {
        set {
            entity.setValue(newValue, forKey: AnalyticsEvent.destinationsKey)
        }
        get {
            return entity.value(forKey: AnalyticsEvent.destinationsKey) as? [String] ?? []
        }
    }
}
