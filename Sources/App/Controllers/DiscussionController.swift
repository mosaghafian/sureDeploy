//
//  File.swift
//
//
//  Created by Mohammad Saghafian on 2022-09-28.
//

import Foundation
import Vapor
import MongoKitten
import Meow
import BSON

class DiscussionController{
    static func routes(_ app: Application){
        app.group("discussion") { route in
            getADiscussion(route)
            postDiscussion(route)
            get20Discussion(route)
            getADiscussion(route)
            deleteDiscussion(route)
        }
        
    }
    static func get20Discussion(_ route: RoutesBuilder){
        route.get("get", "20") { req async -> [DiscussionModel] in
            let col = req.mongoDB["discussion"]
            do{
                let listOfDis = try await col.find().limit(20).drain()

                var returnList: [DiscussionModel] = []
                for document in listOfDis{
                    returnList.append(try BSONDecoder().decode(DiscussionModel.self, from: document))
                }
                return returnList
            }catch{
                return [DiscussionModel.getADiscussionModel()]
            }
        }
    }
    static func getADiscussion(_ route: RoutesBuilder){
        route.get(":id") { req async -> Response in
            let id = req.parameters.get("id")!
            print("\(id)")
            let col = req.mongoDB["discussion"]
            do{
                let doc : Document = ["id": id]
                let dis = try await col.findOne(doc)
                if let dis = dis {
                    print("works")
                    return try await dis.encodeResponse(status: .accepted, for: req)
                }else{
                    print("nil")
                    return Response(status: .badRequest)
                }
            }catch{
                print("catch")
                return Response(status: .badRequest)
            }
        }
    }
    
    
    static func postDiscussion(_ route: RoutesBuilder){
        route.post { req async -> String in
            print("Request received")
            do{
                print("hello")
                print("\(req)")
                let newDiscussion = try req.content.decode(DiscussionModel.self)
                print("what's up")
                let discussion = req.mongoDB["discussion"]
                print("how are you")
                do{
                    let newDocument: Document = try BSONEncoder().encode(newDiscussion)
                    try await discussion.insert(newDocument)
                }catch{
                    
                }

                return "Inserted"
            }catch{
                return "Error"
            }
          
        }
    }
    
    static func getUserDiscussions(_ route: RoutesBuilder){
        route.get("userDiscussion") { req async -> [Document] in
            let col = req.mongoDB["discussion"]
           
            do{
                let dic = try JSONDecoder().decode(Dictionary<String, String>.self, from: req.body.data!)
                let userID : String = dic["userID"]!
                let query : Document = ["creatorID": userID]
                
                try await col.find(query).drain()
                return [["": ""]]
            }catch{
                return [["": ""]]
            }
        }
    }
    
    static func deleteDiscussion(_ route: RoutesBuilder){
        route.delete(":id") { req async -> String in
            do{
                let id : String = req.parameters.get("id")!
                let col = req.mongoDB["discussion"]
                try await col.deleteOne(where: ["id":id])
                return "success"
            }catch{
                return "error"
            }
        }
    }
}
