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
        app.webSocket("chat", ":userID") { req, ws async in
            
        
            let userID: String = req.parameters.get("userID")!
        
            Logger(label: "NewConnection").info("User connected: \(userID) ")
            //
            
            Chats.shared.addNewConnection((userID, ws))
            Chats.shared.updateUser(userID, req, ws)
            
            
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
                    Logger(label: "Chat").error("\(error)")
                }
            }
//            do{
//               // try await ws.send("Hello to sasa")
//                let data = try JSONEncoder().encode(Message(id: UUID().uuidString, date: Date(), group: false, text: "Binary data", authorID: "test1", receiverID: "test1"))
//
//                try await ws.send(raw: data, opcode: .binary)
//                try await ws.send("This is a text")
//            }catch{
//                Logger(label: ".onBinary").error("\(error)")
//            }
            
            ws.onText { ws, text async in
                do{
                    if text == "Hello"{
                        print("Received hello")
                        return
                    }
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
                        Logger(label: "On Text").error("On Text, first catch: \(error)")
                    }
                }catch{
                    
                    Logger(label: "On Text").error("On Text, catch: \(error)")
                }
            }
            
            ws.onPing { ws in
                print("On ping for user \(userID)")
                ws.sendPing()
            }
            
            
        }
    }
}
class Chats{
    static var shared = Chats()
    var dic : [Set<String>: [String: WebSocket]] = [:]
    
    var connectedUser: [String: WebSocket] = [:]
    
    /**
    Important: This funciton needs to be optimized
     */
    func updateUser(_ userID: String, _ req: Request, _ ws: WebSocket){
        Task(priority: .high){
            do{
                // Creating objects to access each collection
                let colUsr = req.mongoDB["user"]
                let colGrp = req.mongoDB["group"]
                let colGrpMSG = req.mongoDB["groupMessage"]
                let colCht = req.mongoDB["chat"]
                let colChtMSG = req.mongoDB["chatMessage"]
                
                let userDoc = try await colUsr.findOne("id" == userID)
                
                
                
                var update : Update = Update(id: UUID().uuidString, date: Date(), chatMessages: [], groupMessages: [])
                var decodedUser: User
                if let userDoc = userDoc{
                     decodedUser = try BSONDecoder().decode(User.self, from: userDoc)
                }else{
                    try await ws.send("User not found!")
                    return
                }
            
                
                if let userDoc = userDoc {
                    
                    
                    if let chats = decodedUser.chats{
                        for chat in chats{
                            let chatObject : Document = try await colCht.findOne("id" == chat)!
                            let decodedChat: Chat = try BSONDecoder().decode(Chat.self, from: chatObject)
                            
                            let chatMSGDoc: Document = try await colChtMSG.findOne("id" == decodedChat.messagesID)!
                            
                            
                            let decodedMSGS: ChatMessages = try BSONDecoder().decode(ChatMessages.self, from: chatMSGDoc)
                            /**
                             Huge optimization can happen here because the query, queries every single messages ever
                            This has to do with my inability to just query messages that after certain date stamp
                             */
                            for message in decodedMSGS.messages{
                                let decodedMSG = try BSONDecoder().decode(Message.self, from: message)
                                if decodedMSG.date > decodedUser.lastOnline{
                                    update.chatMessages.append(decodedMSG)
                                }
                            }

                        }
                    }
                    if let groups = decodedUser.groups{
                        for group in groups{
                            let groupMessages : Document = try await colCht.findOne("id" == group)!
                            
                            let decodedGroup = try BSONDecoder().decode(Group.self, from: groupMessages)
                            
                            let groupMSGDoc: Document = try await colChtMSG.findOne("id" == decodedGroup.messagesID)!
                            
                            let decodedMSGS: ChatMessages = try BSONDecoder().decode(ChatMessages.self, from: groupMSGDoc)
                            
                            for message in decodedMSGS.messages{
                                let decodedMSG = try BSONDecoder().decode(Message.self, from: message)
                                if decodedMSG.date > decodedUser.lastOnline{
                                    update.groupMessages.append(decodedMSG)
                                }
                            }
                            
                            
                        }
                    }
                        
                    
                }else{
                    Logger(label: "updateUser").error("Error finding a user, found nil")
                }
                
                let encodedUpdate = try JSONEncoder().encode(update)
                
                if (!ws.isClosed){
                    //try await ws.send(raw: encodedUpdate, opcode: .binary)
                    Logger(label: "Update").info("sending update \(Date().ISO8601Format())")
                    try await ws.send(raw: encodedUpdate, opcode: .binary)
                }
                
                decodedUser.lastOnline = Date()
                
                
                
                
                try await colUsr.updateOne(where: "id" == decodedUser.id, to: [
                    "$set":[
                        "lastOnline": Date()
                    ]as Document
                ] as Document)
                
            }catch{
                Log.info(text: "Error \(error)")
            }
        }
    }
    
    
    func deleteUserWebSocket(_ username: String){
        connectedUser.removeValue(forKey: username)
    }
    
    func sendMessageGroup(_ message: Message, _ col: MongoCollection, _ colMSG: MongoCollection )async{
        do{
            
            let group = try await col.findOne(["username": message.receiverID] ,as: Group.self)!
            let msgDoc = try BSONEncoder().encode(message)
            try await colMSG.updateOne(where: "id" == group.messagesID, to:
                                        [
                                            "$push":[
                                                "messages": msgDoc
                                            ] as Document
                                        ] as Document
            )
            
            for member in group.members{
                
                let webSocket = connectedUser[member];
                
                
                
                if let socket = webSocket{
                
                    let data = try JSONEncoder().encode(message);
                    if(socket.isClosed){
                        connectedUser.removeValue(forKey: member)
                    }else{
                        
                        if(member != message.authorID){
                            Log.info(text: "Sending message")
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
    
    func sendMessage(_ msg: Message, _ colCHT: MongoCollection, _ colMSG: MongoCollection, _ colUsr: MongoCollection) async {
       // let start = CFAbsoluteTimeGetCurrent()
        // run your work
        Task(priority: .medium) {
            do{
                let receiverSocket = connectedUser[msg.receiverID]
                if let socket = receiverSocket{
                    
                    let data =  try JSONEncoder().encode(msg);
                    if(socket.isClosed){
                        connectedUser.removeValue(forKey: msg.receiverID)
                    }
                    /*
                     Is is the first combination
                     */
                    var chat = try await colCHT.findOne(["contact1": msg.authorID, "contact2": msg.receiverID], as: Chat.self);
                    let msgDoc = try BSONEncoder().encode(msg)
                    //print("UNDER MSGDOC")
                    if chat != nil{
                        try await colMSG.updateOne(where: "id" == chat?.messagesID, to: [
                            "$push": [
                                "messages": msgDoc
                            ] as Document
                        ] as Document
                        )
                        if(!socket.isClosed){
                            Log.info(text: "Send message: \(msg)")
                            try await socket.send(raw: data, opcode: WebSocketOpcode.binary);
                        }
                        return;
                    }
                    /*
                     Is it the second combination
                     */
                    chat = try await colCHT.findOne(["contact1": msg.receiverID, "contact2": msg.authorID],as: Chat.self);
                    if chat != nil{
                        try await colMSG.updateOne(where: "id" == chat?.messagesID, to: [
                            "$push": [
                                "messages": msgDoc
                            ] as Document
                        ] as Document
                        )
                        if(!socket.isClosed){
                            Log.info(text: "Send message: \(msg)")
                            try await socket.send(raw: data, opcode: WebSocketOpcode.binary);
                        }
                        return;
                    }
                    /*
                     There is no chat
                     */
                    let newChat = Chat(id: UUID().uuidString, numOfContacts: 2, contact1: msg.authorID, contact2: msg.receiverID, messagesID: UUID().uuidString)
                    let docNewChat = try BSONEncoder().encode(newChat)
                    try await colCHT.insert(docNewChat)
                    let newChatMessages = ChatMessages(id: newChat.messagesID!, messages: [msgDoc])
                    let docChatMessages = try BSONEncoder().encode(newChatMessages)
                    try await colMSG.insert(docChatMessages)
                    
                    print("socket, contact1: \(newChat.contact1)")
                    try await colUsr.updateOne(where: "id" == newChat.contact1, to: [
                        "$push": [
                            "chats":  newChat.id
                        ] as Document
                    ] as Document
                    )
                    
                    print("socket, contact2: \(newChat.contact2)")
                    try await colUsr.updateOne(where: "id" == newChat.contact2, to: [
                        "$push": [
                            "chats": newChat.id
                        ]as Document
                    ]as Document
                    )
                    if(!socket.isClosed){
                        Log.info(text: "Send message \(msg)")
                        try await socket.send(raw: data, opcode: WebSocketOpcode.binary);
                    }
                    Logger(label: "There is a socket").info("There is no chat but the socket is open")
                }else{
                        var chat = try await colCHT.findOne(["contact1": msg.authorID, "contact2": msg.receiverID], as: Chat.self);
                        let msgDoc = try BSONEncoder().encode(msg)
                        if chat != nil{
                            try await colMSG.updateOne(where: "id" == chat?.messagesID, to: [
                                "$push": [
                                    "messages": msgDoc
                                ]
                            ])
                            
                            return;
                        }
                        chat = try await colCHT.findOne(["contact1": msg.receiverID, "contact2": msg.authorID],as: Chat.self);
                        
                        if chat != nil{
                            try await colMSG.updateOne(where: "id" == chat?.messagesID, to: [
                                "$push": [
                                    "messages": msgDoc
                                ]as Document
                            ]as Document)
                            return;
                        }
                        let newChat = Chat(id: UUID().uuidString, numOfContacts: 2, contact1: msg.authorID, contact2: msg.receiverID, messagesID: UUID().uuidString)
                        let docNewChat = try BSONEncoder().encode(newChat)
                        try await colCHT.insert(docNewChat)
                        let newChatMessages = ChatMessages(id: newChat.messagesID!, messages: [msgDoc])
                        let docChatMessages = try BSONEncoder().encode(newChatMessages)
                        try await colMSG.insert(docChatMessages)
                        print("no socket, contact1: \(newChat.contact1)")
                        try await colUsr.updateOne(where: "id" == newChat.contact1, to: [
                            "$push": [
                                "chats":  newChat.id
                            ]as Document
                        ]as Document)
                    
                        print("no socket, contact1: \(newChat.contact2)")
                        try await colUsr.updateOne(where: "id" == newChat.contact2, to: [
                            "$push": [
                                "chats": newChat.id
                            ]as Document
                        ]as Document)
                        Logger(label: "sendingMessage").info("Failed to send a live message, no receiver id found")
                    }
                Logger(label: "There is no socket").info("There is no chat but socket closed")
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
