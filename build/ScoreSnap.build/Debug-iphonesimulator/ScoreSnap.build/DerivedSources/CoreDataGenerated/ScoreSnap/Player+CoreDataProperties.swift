//
//  Player+CoreDataProperties.swift
//  
//
//  Created by CHRISTOPHER LAU on 6/20/25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Player {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Player> {
        return NSFetchRequest<Player>(entityName: "Player")
    }

    @NSManaged public var displayOrder: Int32
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var playerColor: String?
    @NSManaged public var sport: String?
    @NSManaged public var teams: NSSet?

}

// MARK: Generated accessors for teams
extension Player {

    @objc(addTeamsObject:)
    @NSManaged public func addToTeams(_ value: Team)

    @objc(removeTeamsObject:)
    @NSManaged public func removeFromTeams(_ value: Team)

    @objc(addTeams:)
    @NSManaged public func addToTeams(_ values: NSSet)

    @objc(removeTeams:)
    @NSManaged public func removeFromTeams(_ values: NSSet)

}

extension Player : Identifiable {

}
