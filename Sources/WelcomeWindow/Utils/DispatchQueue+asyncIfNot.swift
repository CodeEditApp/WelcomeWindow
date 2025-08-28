//
//  DispatchQueue+asyncIfNot.swift
//  WelcomeWindow
//
//  Created by Khan Winter on 8/28/25.
//

import Foundation

extension DispatchQueue {
    /// Dispatch an operation to the main queue if it's not already on it.
    /// - Parameter operation: The operation to enqueue.
    static func mainIfNot(_ operation: @MainActor @escaping () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                operation()
            }
        } else {
            DispatchQueue.main.async(execute: operation)
        }
    }
}
