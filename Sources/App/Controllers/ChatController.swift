//
//  File.swift
//
//
//  Created by Mohammad Saghafian on 2022-09-29.
//
import Foundation
import Vapor
import NIOWebSocket
import BSON
import MongoKitten
import Meow

class ChatController {
    
    static func routes(_ app: Application){
        chat(app)
    }
    static func chat(_ app: Application){
        app.webSocket("chat", ":username") { req, ws async in
            
            let username: String = req.parameters.get("username")!
        
            Logger(label: "NewConnection").info("User connected: \(username) ")
            //
            
            Chats.shared.addNewConnection((username, ws))
            
            Chats.shared.updateUser(username, req)
            ws.onBinary { ws, data async in
                do{
                    let message = try JSONDecoder().decode(Message.self, from: data)
                    if(message.group){
                        
                        let col = req.mongoDB["group"]
                        let colMSG = req.mongoDB["groupMessage"]
                        await Chats.shared.sendMessageGroup(message, col, colMSG)
                    }else{
                        let col = req.mongoDB["chat"]
                        let colMSG = req.mongoDB["chatMessage"]
                        let colUsr = req.mongoDB["user"]
                        await Chats.shared.sendMessage(message, col, colMSG, colUsr)
                    }
                    
                }catch{
                    print("Error json decoding for data coming from \(username)")
                    Logger(label: "Chat").error("\(error)")
                }
            }
            do{
               // try await ws.send("Hello to sasa")
                let data = try JSONEncoder().encode(Message(id: UUID().uuidString, date: Date(), group: false, text: "Binary data", authorID: "test1", receiverID: "test1"))
                
                try await ws.send(raw: data, opcode: .binary)
                try await ws.send("This is a text")
            }catch{
                print("\(error)")
            }
            
            ws.onText { ws, text async in
                do{
                    let message = try JSONDecoder().decode(Message.self, from: text.data(using: .utf8)!)
                    do{
                        if(message.group){
                            let col = req.mongoDB["group"]
                            let colMSG = req.mongoDB["groupMessage"]
                            print("group routing ***** ")
                            await Chats.shared.sendMessageGroup(message, col, colMSG)
                        }else{
                            
                            let col = req.mongoDB["chat"]
                            let colMSG = req.mongoDB["chatMessage"]
                            let colUsr = req.mongoDB["user"]
                            await Chats.shared.sendMessage(message, col, colMSG, colUsr)
                        }
                    }catch{
                        print("Error json decoding for data coming from \(username)")
                    }
                }catch{
                    print("Error json decoding from \(username)")
                    print("\(error)")
                }
            }
            
            ws.onPing { ws in
                print("On ping for user \(username)")
            }
            
            
        }
    }
}
class Chats{
    static var shared = Chats()
    var dic : [Set<String>: [String: WebSocket]] = [:]
    
    var connectedUser: [String: WebSocket] = [:]
    
    
    func updateUser(_ username: String, _ req: Request){
        Task(priority: .high){
            do{
                // Creating objects to access each collection
                let colUsr = req.mongoDB["user"]
                let colGrp = req.mongoDB["group"]
                let colGrpMSG = req.mongoDB["groupMessage"]
                let colCht = req.mongoDB["chat"]
                let colChtMSG = req.mongoDB["chatMessage"]
                let user = try await colUsr.findOne("username" == username)
                
                
                
            }catch{
                Logger(label: "updateUser").log(level: .warning, "Failed updating the user")
            }
        }
    }
    
    
    func deleteUserWebSocket(_ username: String){
        connectedUser.removeValue(forKey: username)
        print(connectedUser)
    }
    
    func sendMessageGroup(_ message: Message, _ col: MongoCollection, _ colMSG: MongoCollection )async{
        do{
            
            let group = try await col.findOne(["username": message.receiverID] ,as: Group.self)!
            let msgDoc = try BSONEncoder().encode(message)
            try await colMSG.updateOne(where: "id" == group.messagesID, to:
                                        [
                                            "$push":[
                                                "messages": msgDoc
                                            ]
                                        ])
            
            for member in group.members{
                
                let webSocket = connectedUser[member];
                
                print("members of group \(member)")
                print("socket of that member \(webSocket?.isClosed)")
                if let socket = webSocket{
                    print(message)
                    let data = try JSONEncoder().encode(message);
                    if(socket.isClosed){
                        connectedUser.removeValue(forKey: member)
                    }else{
                        print("****** Sending the message ->")
                        if(member != message.authorID){
                            print("sending message to \(member)")
                            try await socket.send(raw: data, opcode: WebSocketOpcode.binary)
                        }
                    }
                }else{
                    
                }
            }
            
        }catch{
            Logger(label: "Sending gourp message").error("\(error)")
        }
    }
    
    func sendMessage(_ msg: Message, _ col: MongoCollection, _ colMSG: MongoCollection, _ colUsr: MongoCollection) async {
       // let start = CFAbsoluteTimeGetCurrent()
        // run your work
        Task(priority: .medium) {
            do{
                let receiverSocket = connectedUser[msg.receiverID]
                if let socket = receiverSocket{
                    print("Sending this message \(msg)")
                    let data =  try JSONEncoder().encode(msg);
                    if(socket.isClosed){
                        connectedUser.removeValue(forKey: msg.receiverID)
                    }
                    var chat = try await col.findOne(["contact1": msg.authorID, "contact2": msg.receiverID], as: Chat.self);
                    let msgDoc = try BSONEncoder().encode(msg)
                    //print("UNDER MSGDOC")
                    if chat != nil{
                        try await colMSG.updateOne(where: "id" == chat?.messagesID, to: [
                            "$push": [
                                "messages": msgDoc
                            ]
                        ])
                        if(!socket.isClosed){
                            try await socket.send(raw: data, opcode: WebSocketOpcode.binary);
                        }
                        return;
                    }
                    chat = try await col.findOne(["contact1": msg.receiverID, "contact2": msg.authorID],as: Chat.self);
                    if chat != nil{
                        try await colMSG.updateOne(where: "id" == chat?.messagesID, to: [
                            "$push": [
                                "messages": msgDoc
                            ]
                        ])
                        if(!socket.isClosed){
                            try await socket.send(raw: data, opcode: WebSocketOpcode.binary);
                        }
                        return;
                    }
                    
                    
                    let newChat = Chat(id: UUID().uuidString, numOfContacts: 2, contact1: msg.authorID, contact2: msg.receiverID, messagesID: UUID().uuidString)
                    let docNewChat = try BSONEncoder().encode(newChat)
                    try await col.insert(docNewChat)
                    let newChatMessages = ChatMessages(id: newChat.messagesID!, messages: [msgDoc])
                    let docChatMessages = try BSONEncoder().encode(newChatMessages)
                    try await colMSG.insert(docChatMessages)
                    
                    let res = try await colUsr.updateOne(where: "username" == newChat.contact1, to: [
                        "$push": [
                            "chats":  newChat.id
                        ]
                    ])
                    print("\(res)")
                    try await colUsr.updateOne(where: "username" == newChat.contact2, to: [
                        "$push": [
                            "chats": newChat.id
                        ]
                    ])
                    if(!socket.isClosed){
                        try await socket.send(raw: data, opcode: WebSocketOpcode.binary);
                    }
                }else{
                    
                        
                        print("contact1: \(msg.authorID), contact2: \(msg.receiverID)")
                        var chat = try await col.findOne(["contact1": msg.authorID, "contact2": msg.receiverID], as: Chat.self);
                        let msgDoc = try BSONEncoder().encode(msg)
                        if chat != nil{
                            try await colMSG.updateOne(where: "id" == chat?.messagesID, to: [
                                "$push": [
                                    "messages": msgDoc
                                ]
                            ])
                            print("return 1")
                            
                            return;
                        }
                        chat = try await col.findOne(["contact1": msg.receiverID, "contact2": msg.authorID],as: Chat.self);
                        
                        if chat != nil{
                            try await colMSG.updateOne(where: "id" == chat?.messagesID, to: [
                                "$push": [
                                    "messages": msgDoc
                                ]
                            ])
                            return;
                        }
                        let newChat = Chat(id: UUID().uuidString, numOfContacts: 2, contact1: msg.authorID, contact2: msg.receiverID, messagesID: UUID().uuidString)
                        let docNewChat = try BSONEncoder().encode(newChat)
                        try await col.insert(docNewChat)
                        let newChatMessages = ChatMessages(id: newChat.messagesID!, messages: [msgDoc])
                        let docChatMessages = try BSONEncoder().encode(newChatMessages)
                        try await colMSG.insert(docChatMessages)
                        
                        let res = try await colUsr.updateOne(where: "id" == newChat.contact1, to: [
                            "$push": [
                                "chats":  newChat.id
                            ]
                        ])
                        print("\(res)")
                        try await colUsr.updateOne(where: "id" == newChat.contact2, to: [
                            "$push": [
                                "chats": newChat.id
                            ]
                        ])
                        print("\(res)")
                        
                        Logger(label: "sendingMessage").info("Failed to send a live message, no receiver id found")
                    }
                
            }catch{
                Logger(label: "sendingMessage").warning("Catch block of sending a message \(error)")
            }
        }
       // let diff = CFAbsoluteTimeGetCurrent() - start
       // r print("Took \(diff) seconds")
    }
    
    func addNewConnection(_ userWebSocket: (String, WebSocket)) {
        let isUserInDictionary = connectedUser.contains { (key: String, value: WebSocket) in
            return key == userWebSocket.0
        }
        if (isUserInDictionary){
            connectedUser.updateValue(userWebSocket.1, forKey: userWebSocket.0)
        }else{
            connectedUser[userWebSocket.0] = userWebSocket.1
        }
        Logger(label: "add new Connection").info("The content of connectedUser")
        print(connectedUser)
    }
    
    //    func publishMessage(_ text: String, _ userID: String, _ contactID: String, _ ws: WebSocket, _ req: Request) {
    //        for (Set, Pairs) in dic{
    //            if Set.contains(userID) && Set.contains(contactID){
    //                for socket in Pairs{
    //                    if (socket.key != userID){
    //                        socket.value.send(text)
    //                    }
    //                }
    //            }
    //        }
    
    //        Task(priority: .background){
    //            do{
    //                let d = Date.now
    //
    //                let col = req.mongoDB["chat"]
    //                let doc : Document = ["listOfContacts": [userID, contactID]]
    //                let doc2 : Document = ["listOfContacts": [contactID, userID]]
    //                var chatDoc: Document? = try await col.findOne(doc)
    //                var chatDoc2: Document? = try await col.findOne(doc2)
    //                let newMsg: Document = try BSONEncoder().encode(Message(id: UUID().uuidString,  date: Date.now.ISO8601Format(), chatID: UUID().uuidString, text: text, authorID: userID))
    //                if chatDoc == nil && chatDoc2 == nil{
    //                    try await col.insert(BSONEncoder().encode(Chat(id: UUID().uuidString, numOfContacts: 2, listOfContacts: [userID, contactID], listOfMessages: [newMsg])))
    //                }else{
    //                    if chatDoc != nil {
    //                        print("\(userID)")
    //                        var chat: Chat = try BSONDecoder().decode(Chat.self, from: chatDoc!)
    //                        chat.listOfMessages.append(newMsg)
    //                        chatDoc = try BSONEncoder().encode(chat)
    //                        try await col.updateOne(where: doc, to: chatDoc!)
    //                        print("\(userID)")
    //                    }else{
    //                        print("\(userID)")
    //                        var chat: Chat = try BSONDecoder().decode(Chat.self, from: chatDoc2!)
    //                        chat.listOfMessages.append(newMsg)
    //                        chatDoc2 = try BSONEncoder().encode(chat)
    //                        try await col.updateOne(where: doc2, to: chatDoc2!)
    //                        print("\(userID)")
    //                    }
    //                }
    //                Logger(label:"Time of Task").info("\(Date.now.timeIntervalSince(d))")
    //            }catch{
    //                print("\(error)")
    //            }
    //            print("End of the task")
    //        }
    //
    //        print("hello")
    //    }
    
    func addChat(_ username: String, _ contactID: String, _ ws: WebSocket){
        var aSet: Set<String>  = Set()
        aSet.insert(username)
        aSet.insert(contactID)
        
        if (dic[aSet] == nil){
            dic[aSet] = [username: ws]
        }else{
            var innerDic = dic[aSet]!
            innerDic[username] = ws
            print(username)
            dic[aSet]! = innerDic
            
        }
    }
}
