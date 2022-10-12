//
//  File.swift
//
//
//  Created by Mohammad Saghafian on 2022-10-08.
//
import Foundation
import Vapor
import MongoKitten
import Meow
import BSON


public struct Update: Content, Primitive, Codable{
    let id: String
    let date: Date
    var chatMessages: [Message]
    var groupMessages: [Message]
}

public struct User: Content, Primitive, Codable{
    let id: String
    var username: String
    var phoneNumber: String?
    var lastOnline: Date
    var chats: [String]?
    var groups: [String]?
}

public struct Message: Codable, Primitive, Content{
    let id: String
    let date: Date
    var group: Bool
    var text: String
    var authorID: String
    var receiverID: String
}

struct Chat: Content, Primitive, Codable{
    let id: String
    var numOfContacts: Int
    var contact1: String
    var contact2: String
    var messagesID: String?
}

struct ChatMessages: Content, Primitive, Codable{
    var id: String
    var messages: [Document]
}

struct GroupMessages: Content, Primitive, Codable{
    var id: String
    var messages: [Document]
}
struct Id: Content, Primitive, Codable{
    let id: String
}

struct DiscussionModel: Content, Primitive, Codable{
    let id: String
    let topic: String
    let text: String
    let creator: String
    let creatorID: String
    let date: String
    var votes: Int
    var rating: Int?
    var category: String?
    var comments: [Document]?
    
    static func getADiscussionModel() -> DiscussionModel{
        return DiscussionModel(id: "", topic: "", text: "", creator: "", creatorID: "", date: "", votes: 0)
    }

}

struct CommentModel: Content, Primitive, Codable{
    let id: String
    let creator: String
    let creatorID: String
    let text: String
    var vote: Int
}

struct Group: Content, Primitive, Codable{
    let id: String
    var admin: String
    var members: [String]
    var messagesID: String?
}

struct UserID: Content, Primitive, Codable{
    let id: String
}

struct Quote: Content{
    let id: Int
    let author: String
    let text: String
    
    static func getAQuote() -> Quote{
        return Quote(id: 1, author:"" , text: "")
    }
}

extension Document: Content{
    
}


