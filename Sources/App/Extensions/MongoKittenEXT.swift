//
//  SwiftUIView.swift
//
//
//  Created by Mohammad Saghafian on 2022-09-29.
//

import Foundation
import MongoKitten
import Meow
import Vapor
import BSON

extension Request {
    
    public var mongoDB: MongoDatabase {
        return application.mongoDB
    }
    
    // For Meow users only
    public var meow: MeowDatabase {
        return MeowDatabase(mongoDB)
    }
    
    // For Meow users only
    public func meow<M: ReadableModel>(_ type: M.Type) -> MeowCollection<M> {
        return meow[type]
    }
}

private struct MongoDBStorageKey: StorageKey {
    typealias Value = MongoDatabase
}

extension Application {
    public var mongoDB: MongoDatabase {
        get {
            storage[MongoDBStorageKey.self]!
        }
        set {
            storage[MongoDBStorageKey.self] = newValue
        }
    }
    // For Meow users only
    public var meow: MeowDatabase {
        MeowDatabase(mongoDB)
    }
    
    public func initializeMongoDB(connectionString: String) throws {
        self.mongoDB = try MongoDatabase.lazyConnect(to: connectionString)
    }
}



