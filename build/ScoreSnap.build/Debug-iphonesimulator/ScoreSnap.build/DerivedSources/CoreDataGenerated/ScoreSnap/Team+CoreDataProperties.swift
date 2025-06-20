//
//  Team+CoreDataProperties.swift
//  
//
//  Created by CHRISTOPHER LAU on 6/20/25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Team {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Team> {
        return NSFetchRequest<Team>(entityName: "Team")
    }

    @NSManaged public var displayOrder: Int32
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var sport: String?
    @NSManaged public var teamColor: String?
    @NSManaged public var games: NSSet?
    @NSManaged public var player: Player?

}

// MARK: Generated accessors for games
extension Team {

    @objc(addGamesObject:)
    @NSManaged public func addToGames(_ value: Game)

    @objc(removeGamesObject:)
    @NSManaged public func removeFromGames(_ value: Game)

    @objc(addGames:)
    @NSManaged public func addToGames(_ values: NSSet)

    @objc(removeGames:)
    @NSManaged public func removeFromGames(_ values: NSSet)

}

extension Team : Identifiable {

}
