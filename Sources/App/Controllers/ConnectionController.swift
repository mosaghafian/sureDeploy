//
//  File.swift
//  
//
//  Created by Mohammad Saghafian on 2022-10-13.
//

import Foundation
import Vapor
import NIOWebSocket
import BSON
import MongoKitten
import Meow


class ConnectionController{
    static func routes(_ app: Application){
        app.group("connection") { route in
            checkConnection(route)
        }
    }
    
    static func checkConnection(_ route: RoutesBuilder){
        Task(priority: .medium){
            route.get { req -> Response in
                return Response(status: .accepted)
            }
        }
    }
}
