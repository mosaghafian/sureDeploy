//
//  File.swift
//
//
//  Created by Mohammad Saghafian on 2022-10-01.
//

import Foundation
import Vapor
import BSON
import MongoKitten
import Meow

class CommentController{
    static func routes(_ app: RoutesBuilder){
        app.group("comment"){ route in
            delete(route)
            insert(route)
            getHello(route)
            test(route)
        }
    }
    static func test(_ route: RoutesBuilder){
        route.post("test") { req async -> Document in
            do{
                var comment = try req.content.decode(CommentModel.self)
                comment.vote += 100
                let doc = try BSONEncoder().encode(comment)
                return doc
            }catch{
                print("Catch")
                return Document()
            }
        }
    }
    
    static func getHello(_ route: RoutesBuilder){
        route.get("hello") { req -> String in
            return "Hello"
        }
    }
    
    static func insert(_ route: RoutesBuilder){
        route.post("insert", ":discussionID") { req async -> Response in
            do{
                let id : String = req.parameters.get("discussionID")!
                let comment: CommentModel = try req.content.decode(CommentModel.self)
                let bsonComment: Document = try BSONEncoder().encode(comment)

                let col = req.mongoDB["discussion"]
                var discussion : DiscussionModel = try BSONDecoder().decode(DiscussionModel.self, from: try await col.findOne(["id": id])!)
                
                if (discussion.comments != nil){
                    discussion.comments?.append(bsonComment)
                }
                
                try await col.updateOne(where: ["id": id], to: BSONEncoder().encode(discussion))
                
                
                return Response(status: .ok, body: "Comment Inserted")
            }catch{
                return Response(status: .badRequest, body: "Insertion failed ")
            }
        }
    }
    

//    static func updateVote(_ route: RoutesBuilder){
//        route.post("update", "vote", ":discussionID", ":commentID") { req async -> String in
//            do{
//                let id : String = req.parameters.get("discussionID")!
//                let comId: String = req.parameters.get("commentID")!
//                let col = req.mongoDB["discussion"]
//
//
//            //    let one : Int = 1
//                var doc = try await col.findOne(["id": id],as: DiscussionModel.self)
//                print(doc)
//                let array = BSONDecoder().decode(CommentModel.self, from:  doc?.comments)
//                var i = 0
//                print("1")
//                for a in array!{
//                    print("2")
//                    if(a.id == comId){
//                        doc!.comments![i].vote += 1
//                    }
//                    i += 1
//                }
//                let bson : Document = try BSONEncoder().encode(doc!)
//                print("3")
//                col.findOneAndUpdate(where: ["id": id], to: bson)
//                return "success"
//            }catch{
//                print("error \(error)")
//                return "error"
//            }
//        }
//    }
//
    static func delete(_ route: RoutesBuilder){
        route.post("delete", ":discussionID", ":commentID"){ req async -> String in
            do{
                let id : String = req.parameters.get("discussionID")!
                let comId: String = req.parameters.get("commentID")!
                let comment: CommentModel = try req.content.decode(CommentModel.self)
              
                let col = req.mongoDB["discussion"]
                try await col.updateOne(where: ["id": id], to: [
                    "$pull":
                        ["comments": [
                            "id": comId
                        ]]
                ])
                return "success"
            }catch{
                return "error"
            }
        }
    }
    
    
    
}
