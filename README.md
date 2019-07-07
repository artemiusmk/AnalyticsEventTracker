# AnalyticsEventTracker

AnalyticsEventTracker is a library, that allows you to send events to multiple destinations, like Firebase, GoogleAnalytics or your app server in the same way.

Written in Swift, without any additional libraries

It retries sending after network or others errors, uses CoreData for events storage, so all you events will be send

Library logger is open for customizations

## Example - send event

```swift
enum Destination: String, CaseIterable {
    case googleAnalytics, appServer
}

analyticsTracker.send(event: "TestEvent", destination: Destination.appServer.rawValue)
```

## Example - implement event sender for destination

NOTE: Closure is run on the **background queue**.

```swift
analyticsTracker.addDestinationSender(destination: Destination.googleAnalytics.rawValue) { 
    (event, success) in

    // send to destination

    success(true)
}
```

## Example - implement library delegate to notify about network reachability changes

NOTE: Reachability.swift library is used for this purpose

```swift
let reachability = Reachability()

func setupNetworkReachability(reachabilityUpdater: @escaping (Bool) -> Void) {
    reachability?.whenUnreachable = { _ in
        reachabilityUpdater(false)
    }
    reachability?.whenReachable = { _ in
        reachabilityUpdater(true)
    }
    
    do {
        try reachability?.startNotifier()
    } catch {
        print("Unable to start notifier")
    }
}

func networkReachable() -> Bool {
    return reachability?.connection != .none
}
```
