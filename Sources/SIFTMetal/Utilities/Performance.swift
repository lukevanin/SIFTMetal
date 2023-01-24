//
//  Performance.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/10.
//

import Foundation
import OSLog


private let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier!, category: "performance")


func measure(name: StaticString, worker: () -> Void) {
    print("\(name): Start")
    let startTime = CFAbsoluteTime()
    let signpostID = signposter.makeSignpostID()
    let state = signposter.beginInterval(name, id: signpostID)
    worker()
    signposter.endInterval(name, state)
    let elapsedTime = CFAbsoluteTime() - startTime
    print("\(name): End: \(String(format: "%0.4f", elapsedTime)) seconds")
}
