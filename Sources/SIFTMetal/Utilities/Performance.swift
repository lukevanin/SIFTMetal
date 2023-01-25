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
    let signpostID = signposter.makeSignpostID()
    let state = signposter.beginInterval(name, id: signpostID)
    worker()
    signposter.endInterval(name, state)
}
