/**
 * CoreDataModel.swift
 * Core Data Model Definitions
 *
 * Note: These are Swift representations of the Core Data model.
 * You need to create the actual .xcdatamodeld file in Xcode.
 *
 * See: setup.sh for automated model generation
 */

import Foundation
import CoreData

// MARK: - LocalForm Entity

@objc(LocalForm)
public class LocalForm: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var remoteId: String?
    @NSManaged public var templateId: UUID?
    @NSManaged public var title: String?
    @NSManaged public var status: String?
    @NSManaged public var fieldsData: Data?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var submittedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var needsSync: Bool
}

extension LocalForm {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocalForm> {
        return NSFetchRequest<LocalForm>(entityName: "LocalForm")
    }
}

// MARK: - LocalTemplate Entity

@objc(LocalTemplate)
public class LocalTemplate: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var remoteId: String?
    @NSManaged public var name: String?
    @NSManaged public var templateDescription: String?
    @NSManaged public var category: String?
    @NSManaged public var fieldsData: Data?
    @NSManaged public var isPublic: Bool
    @NSManaged public var version: Int32
    @NSManaged public var syncedAt: Date?
}

extension LocalTemplate {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocalTemplate> {
        return NSFetchRequest<LocalTemplate>(entityName: "LocalTemplate")
    }
}

// MARK: - LocalSignature Entity

@objc(LocalSignature)
public class LocalSignature: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var formId: UUID?
    @NSManaged public var signerName: String?
    @NSManaged public var signerEmail: String?
    @NSManaged public var signerRole: String?
    @NSManaged public var signatureType: String?
    @NSManaged public var signatureData: String?
    @NSManaged public var documentHash: String?
    @NSManaged public var consentGiven: Bool
    @NSManaged public var consentText: String?
    @NSManaged public var signedAt: Date?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var witnessName: String?
    @NSManaged public var witnessEmail: String?
}

extension LocalSignature {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocalSignature> {
        return NSFetchRequest<LocalSignature>(entityName: "LocalSignature")
    }
}

// MARK: - LocalAttachment Entity

@objc(LocalAttachment)
public class LocalAttachment: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var formId: UUID?
    @NSManaged public var fieldId: String?
    @NSManaged public var fileName: String?
    @NSManaged public var fileType: String?
    @NSManaged public var fileData: Data?
    @NSManaged public var fileUrl: String?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var createdAt: Date?
}

extension LocalAttachment {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocalAttachment> {
        return NSFetchRequest<LocalAttachment>(entityName: "LocalAttachment")
    }
}

// MARK: - Core Data Model XML

/*
 * Create DigitalFormsApp.xcdatamodeld in Xcode with these entities:
 *
 * ENTITY: LocalForm
 * - id: UUID
 * - remoteId: String (optional)
 * - templateId: UUID (optional)
 * - title: String
 * - status: String (default: "draft")
 * - fieldsData: Binary Data
 * - latitude: Double
 * - longitude: Double
 * - createdAt: Date
 * - updatedAt: Date
 * - submittedAt: Date (optional)
 * - syncedAt: Date (optional)
 * - needsSync: Boolean (default: NO)
 *
 * ENTITY: LocalTemplate
 * - id: UUID
 * - remoteId: String (optional)
 * - name: String
 * - templateDescription: String (optional)
 * - category: String (optional)
 * - fieldsData: Binary Data
 * - isPublic: Boolean
 * - version: Integer 32
 * - syncedAt: Date (optional)
 *
 * ENTITY: LocalSignature
 * - id: UUID
 * - formId: UUID
 * - signerName: String
 * - signerEmail: String (optional)
 * - signerRole: String (optional)
 * - signatureType: String
 * - signatureData: String
 * - documentHash: String
 * - consentGiven: Boolean
 * - consentText: String
 * - signedAt: Date
 * - latitude: Double
 * - longitude: Double
 * - witnessName: String (optional)
 * - witnessEmail: String (optional)
 *
 * ENTITY: LocalAttachment
 * - id: UUID
 * - formId: UUID
 * - fieldId: String (optional)
 * - fileName: String
 * - fileType: String (optional)
 * - fileData: Binary Data
 * - fileUrl: String (optional)
 * - thumbnailData: Binary Data (optional)
 * - latitude: Double
 * - longitude: Double
 * - createdAt: Date
 */
