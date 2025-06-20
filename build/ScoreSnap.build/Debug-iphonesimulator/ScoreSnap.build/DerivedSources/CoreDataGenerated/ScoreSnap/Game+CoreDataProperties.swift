//
//  Game+CoreDataProperties.swift
//  
//
//  Created by CHRISTOPHER LAU on 6/20/25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Game {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Game> {
        return NSFetchRequest<Game>(entityName: "Game")
    }

    @NSManaged public var gameDate: Date?
    @NSManaged public var gameEditDate: Date?
    @NSManaged public var gameEditTime: Date?
    @NSManaged public var gameLocation: String?
    @NSManaged public var gameTime: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var isTie: Bool
    @NSManaged public var isWin: Bool
    @NSManaged public var notes: String?
    @NSManaged public var opponentName: String?
    @NSManaged public var opponentScore: Int32
    @NSManaged public var teamScore: Int32
    @NSManaged public var team: Team?

}

extension Game : Identifiable {

}
