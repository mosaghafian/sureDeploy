//
//  File.swift
//
//
//  Created by Mohammad Saghafian on 2022-10-06.
//

import Foundation
import Vapor
import BSON
import MongoKitten
import Meow

class GroupController{
    static func routes(_ app: Application){
        app.group("group") { route in
            insert(route)
            addUserGroup(route)
        }
    }
    
    
    static func insert(_ route: RoutesBuilder){
        route.post { req async -> Response in
            do{
                var group: Group = try req.content.decode(Group.self)
                
                let msgcol = req.mongoDB["groupMessage"]
                group.messagesID = UUID().uuidString
                
                let col = req.mongoDB["group"]
                
                let groupMessages = GroupMessages(id: group.messagesID!, messages: [])
                let doc: Document = try BSONEncoder().encode(group)
                
                try await col.insert(doc)
                try await msgcol.insertEncoded(groupMessages)
                
                let gr = group
                Task(priority: .background) {
                    do{
                        let colUser: MongoCollection = req.mongoDB["user"]
                        for member in gr.members{
                            var user : User = try await colUser.findOne(["username": member],as: User.self)!
                            
                            user.groups.append(gr.id)
                            let docUser : Document = try BSONEncoder().encode(user)
                            try await colUser.updateOne(where: ["username" : user.id], to: docUser)
                        }
                        print("hello")
                    }catch{

                    }
                }
                print("not task")
                return Response(status: .accepted)
            }catch{
                Logger(label: "insert").error("Creating a new group has failed")
                return Response(status: .badRequest)
            }
            
        }
    }
    
    static func addUserGroup(_ route: RoutesBuilder){
        route.post("user", ":groupID") { req async -> Response in
            do{
                let col = req.mongoDB[""]
                let groupId: String = req.parameters.get("groupID")!
                let newUserID = try req.content.decode(UserID.self)
                
                var group: Group = try await col.findOne(["id": groupId], as: Group.self)!
                
                group.members.append(newUserID.id)
                
                let doc = try BSONEncoder().encode(group)
                try await col.updateOne(where: ["id": groupId], to:  doc)
                
                
                return try await  doc.encodeResponse(status: .accepted, for: req)
            }catch{
                Logger(label: "addUserGroup").error("Adding user to group faild \(error)")
                return Response(status: .badRequest)
            }
        }
    }
}

