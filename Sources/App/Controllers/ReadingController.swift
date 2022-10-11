//
//  File.swift
//
//
//  Created by Mohammad Saghafian on 2022-09-29.
//

import Foundation
import Vapor
import BSON
import MongoKitten
import Meow

class ReadingController {
    static func routes(_ app: Application){
        app.group("reading") { route in
            insert(route)
            getQuotes(route)
            getNumQuotes(route)
            get20Quotes(route)
        }
    }
    
    static func get20Quotes(_ route: RoutesBuilder){
        route.get("getQuotes") { req async -> [Document] in
            let col = req.mongoDB["quote"]
            
            do{
                let listOfQuote = try await col.find().limit(20).drain()
                
                let list = try await AggregateBuilderPipeline(stages: [Sample(20)], collection: col).drain()
                
                
                
                
                
                var returnList : [Quote] = []
                
                for quote in listOfQuote{
                    returnList.append(try BSONDecoder().decode(Quote.self, from: quote))
                    
                }
                return listOfQuote
            }catch{
                
                return []
            }
        }
    }
    
    static func insert(_ route: RoutesBuilder){
        route.post("insert") { req async -> String in
            return ""
        }
    }
    
    static func getQuotes(_ route: RoutesBuilder){
        route.get("quotes") { req -> String in
            return ""
        }
    }
    
    static func getNumQuotes(_ route: RoutesBuilder){
        route.get("getNumQuotes"){ req async -> Int in
            req.logger.info("getNumQuotes")
            do{
                let count = try await req.mongoDB["quote"].count()
                return count
            }catch{
                return 0
            }
        }
    }
    
    
    
    
    
}
