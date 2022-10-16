import Foundation
import Vapor
import NIOWebSocket
import BSON
import MongoKitten
import Meow

class DBConfig{
    static var url : String = "mongodb://sasaCompany:Parvardegar1@127.0.0.1:2717/sure"
}

func routes(_ app: Application) throws {
    app.get("get") { req async -> String in
        print("received the request")
        return "It works!"
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }

    app.get("") { req in
        "Welcome to SURE. 1"
    }
//    
//    app.post("user"){ req async -> Response in
//        Logger(label: "SignUpUser").info("Post Request sign up user")
//        let col = req.mongoDB["user"]
//        
//        do{
//            let binBuf = req.body.data!
//            let user : User = try JSONDecoder().decode(User.self, from: binBuf)
//            print("\(user.username)")
//            
//            let user1 = try await col.findOne("id" == user.username)
//            
//            if user1 != nil{
//                return Response(status: .conflict)
//            }else{
//                let userDoc: Document = try BSONEncoder().encode(user)
//                try await col.insert(userDoc)
//                return Response(status: .created, body: .init(string: "created"))
//            }
//            
//        }catch{
//            print("\(error)")
//            return Response(status: .badRequest)
//        }
//    }
//
    /**
     Different routes for different services
     */
    DiscussionController.routes(app)
    ReadingController.routes(app)
    ChatController.routes(app)
    UserController.routes(app)
    CommentController.routes(app)
    GroupController.routes(app)
    ConnectionController.routes(app)
    
}
