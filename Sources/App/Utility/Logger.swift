//
//  File.swift
//  
//
//  Created by Mohammad Saghafian on 2022-10-15.
//
import Foundation
import Vapor
import MongoKitten
import Meow
import BSON


public class Log{
    public static func info(text: String){
        Logger(label: text).info("\(text) \(Date().ISO8601Format())")
    }
}
