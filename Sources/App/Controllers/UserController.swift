//
//  File.swift
//
//
//  Created by Mohammad Saghafian on 2022-10-04.
//
import Foundation
import Vapor
import BSON
import MongoKitten
import Meow


class UserController{
    static func routes(_ app: Application){
        app.group("user"){ route in
            
            userExists(route)
            signUpUser(route)
            deleteUser(route)
            sayHello(route)
        }
    }
    
    static func sayHello(_ route: RoutesBuilder){
        route.get("") { req -> String in
                return "hello"
        }
    }
    static func userExists(_ route: RoutesBuilder){
        route.get(":username") { req async -> Response in
            let username : String = req.parameters.get("username")!
            let col = req.mongoDB["user"]
            do{
                let userDoc : Document? = try await col.findOne(["username":username])
                
                let dataString: Data = Data("No user found".utf8)
                print("\(username)")
                if userDoc == nil{
                    print("1")
                    return Response(status: .notFound, body: .init(data: dataString))
                    
                }else{
                    let userID = try BSONDecoder().decode(Id.self, from: userDoc!)
                    
                    return Response(status: .ok, body: .init(stringLiteral: userID.id))
                }
            }catch{
                print("2")
                print("\(error)")
                return Response(status: .badRequest)
                
            }
        }
    }
    
    static func signUpUser(_ route: RoutesBuilder){
        
        route.post { req async -> Response in
            Logger(label: "SignUpUser").info("Post Request sign up user")
            let col = req.mongoDB["user"]
            
            do{
                let binBuf = req.body.data!
                let user : User = try JSONDecoder().decode(User.self, from: binBuf)
                print("\(user.username)")
                
                let user1 = try await col.findOne("username" == user.username)
                
                if user1 != nil{
                    return Response(status: .conflict)
                }else{
                    let userDoc: Document = try BSONEncoder().encode(user)
                    try await col.insert(userDoc)
                    return Response(status: .created, body: .init(string: "created"))
                }
                
            }catch{
                print("\(error)")
                return Response(status: .badRequest)
            }
        }
    }
    
    static func deleteUser(_ route: RoutesBuilder){
        route.delete(":id"){req -> Response in
            do{
                let id : String = req.parameters.get("id")!
                let col = req.mongoDB["user"]
                try await col.deleteOne(where: ["id": id])
                return Response(status: .ok)
            }catch{
                return Response(status: .notFound)
            }
        }
    }
}
