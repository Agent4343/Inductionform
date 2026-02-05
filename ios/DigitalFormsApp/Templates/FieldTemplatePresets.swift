/**
 * FieldTemplatePresets.swift
 * Reusable Field Template Blocks
 *
 * Library of common field presets that can be inserted into forms
 */

import Foundation

struct FieldTemplatePresets {
    
    // MARK: - Personal Information
    
    static var personalInformation: [FieldDefinition] {
        [
            FieldDefinition(id: UUID().uuidString, type: "section", label: "Personal Information"),
            FieldDefinition(id: UUID().uuidString, type: "text", label: "First Name", required: true, placeholder: "Enter first name"),
            FieldDefinition(id: UUID().uuidString, type: "text", label: "Last Name", required: true, placeholder: "Enter last name"),
            FieldDefinition(id: UUID().uuidString, type: "email", label: "Email Address", required: true, placeholder: "name@example.com"),
            FieldDefinition(id: UUID().uuidString, type: "phone", label: "Phone Number", required: true, placeholder: "(555) 123-4567"),
            FieldDefinition(id: UUID().uuidString, type: "date", label: "Date of Birth")
        ]
    }
    
    // MARK: - Address Block
    
    static let addressBlock: [FieldDefinition] = [
        FieldDefinition(id: UUID().uuidString, type: "section", label: "Address"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Street Address", required: true, placeholder: "123 Main St"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Apartment/Unit", placeholder: "Apt 4B"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "City", required: true, placeholder: "Toronto"),
        FieldDefinition(id: UUID().uuidString, type: "dropdown", label: "Province", required: true, options: [
            "AB", "BC", "MB", "NB", "NL", "NS", "NT", "NU", "ON", "PE", "QC", "SK", "YT"
        ]),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Postal Code", required: true, placeholder: "A1A 1A1")
    ]
    
    // MARK: - Emergency Contact
    
    static let emergencyContact: [FieldDefinition] = [
        FieldDefinition(id: UUID().uuidString, type: "section", label: "Emergency Contact"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Contact Name", required: true, placeholder: "Full name"),
        FieldDefinition(id: UUID().uuidString, type: "dropdown", label: "Relationship", required: true, options: [
            "Spouse", "Parent", "Sibling", "Child", "Friend", "Other"
        ]),
        FieldDefinition(id: UUID().uuidString, type: "phone", label: "Contact Phone", required: true, placeholder: "(555) 123-4567"),
        FieldDefinition(id: UUID().uuidString, type: "email", label: "Contact Email", placeholder: "name@example.com")
    ]
    
    // MARK: - Employment Information
    
    static let employmentInformation: [FieldDefinition] = [
        FieldDefinition(id: UUID().uuidString, type: "section", label: "Employment Information"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Employee ID", placeholder: "EMP12345"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Job Title", required: true, placeholder: "Position title"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Department", required: true),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Manager/Supervisor", placeholder: "Supervisor name"),
        FieldDefinition(id: UUID().uuidString, type: "date", label: "Start Date", required: true)
    ]
    
    // MARK: - Payment Information
    
    static let paymentInformation: [FieldDefinition] = [
        FieldDefinition(id: UUID().uuidString, type: "section", label: "Payment Information"),
        FieldDefinition(id: UUID().uuidString, type: "dropdown", label: "Payment Method", required: true, options: [
            "Credit Card", "Debit Card", "Bank Transfer", "Cash", "Check"
        ]),
        FieldDefinition(id: UUID().uuidString, type: "currency", label: "Amount", required: true),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Transaction Reference"),
        FieldDefinition(id: UUID().uuidString, type: "date", label: "Payment Date", required: true)
    ]
    
    // MARK: - Vehicle Information
    
    static let vehicleInformation: [FieldDefinition] = [
        FieldDefinition(id: UUID().uuidString, type: "section", label: "Vehicle Information"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Make", placeholder: "Toyota"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Model", placeholder: "Camry"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Year", placeholder: "2023"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "License Plate", required: true, placeholder: "ABC 123"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "VIN", placeholder: "Vehicle Identification Number"),
        FieldDefinition(id: UUID().uuidString, type: "dropdown", label: "Color", options: [
            "White", "Black", "Silver", "Gray", "Red", "Blue", "Green", "Yellow", "Other"
        ])
    ]
    
    // MARK: - Health & Safety
    
    static let healthAndSafety: [FieldDefinition] = [
        FieldDefinition(id: UUID().uuidString, type: "section", label: "Health & Safety"),
        FieldDefinition(id: UUID().uuidString, type: "yesNo", label: "Safety training completed?", required: true),
        FieldDefinition(id: UUID().uuidString, type: "date", label: "Training Completion Date"),
        FieldDefinition(id: UUID().uuidString, type: "multiSelect", label: "Certifications", options: [
            "First Aid", "CPR", "WHMIS", "Fall Protection", "Confined Space", "Forklift", "Other"
        ]),
        FieldDefinition(id: UUID().uuidString, type: "yesNo", label: "Medical restrictions?"),
        FieldDefinition(id: UUID().uuidString, type: "textarea", label: "Restriction details (if any)")
    ]
    
    // MARK: - Equipment Details
    
    static let equipmentDetails: [FieldDefinition] = [
        FieldDefinition(id: UUID().uuidString, type: "section", label: "Equipment Details"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Equipment ID/Serial", required: true, placeholder: "EQ-12345"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Equipment Name", required: true),
        FieldDefinition(id: UUID().uuidString, type: "dropdown", label: "Equipment Type", options: [
            "Machinery", "Tool", "Vehicle", "Computer", "Safety Equipment", "Other"
        ]),
        FieldDefinition(id: UUID().uuidString, type: "dropdown", label: "Condition", required: true, options: [
            "Excellent", "Good", "Fair", "Poor", "Non-Functional"
        ]),
        FieldDefinition(id: UUID().uuidString, type: "date", label: "Last Maintenance Date"),
        FieldDefinition(id: UUID().uuidString, type: "photo", label: "Equipment Photo")
    ]
    
    // MARK: - Approval Section
    
    static let approvalSection: [FieldDefinition] = [
        FieldDefinition(id: UUID().uuidString, type: "section", label: "Approval"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Approved By", placeholder: "Approver name"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Approver Title", placeholder: "Job title"),
        FieldDefinition(id: UUID().uuidString, type: "date", label: "Approval Date"),
        FieldDefinition(id: UUID().uuidString, type: "signature", label: "Approver Signature", required: true)
    ]
    
    // MARK: - Witness Section
    
    static let witnessSection: [FieldDefinition] = [
        FieldDefinition(id: UUID().uuidString, type: "section", label: "Witness"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Witness Name", placeholder: "Full name"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Witness Company/Organization"),
        FieldDefinition(id: UUID().uuidString, type: "email", label: "Witness Email"),
        FieldDefinition(id: UUID().uuidString, type: "signature", label: "Witness Signature")
    ]
    
    // MARK: - Location & GPS
    
    static let locationAndGPS: [FieldDefinition] = [
        FieldDefinition(id: UUID().uuidString, type: "section", label: "Location"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Site/Facility Name", required: true),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Building/Area"),
        FieldDefinition(id: UUID().uuidString, type: "text", label: "Room/Location"),
        FieldDefinition(id: UUID().uuidString, type: "location", label: "GPS Coordinates")
    ]
    
    // MARK: - All Presets Registry
    
    static let all: [FieldPreset] = [
        FieldPreset(id: "personal-info", name: "Personal Information", icon: "person.fill", fields: personalInformation),
        FieldPreset(id: "address", name: "Address Block", icon: "house.fill", fields: addressBlock),
        FieldPreset(id: "emergency-contact", name: "Emergency Contact", icon: "phone.circle.fill", fields: emergencyContact),
        FieldPreset(id: "employment", name: "Employment Information", icon: "briefcase.fill", fields: employmentInformation),
        FieldPreset(id: "payment", name: "Payment Information", icon: "creditcard.fill", fields: paymentInformation),
        FieldPreset(id: "vehicle", name: "Vehicle Information", icon: "car.fill", fields: vehicleInformation),
        FieldPreset(id: "health-safety", name: "Health & Safety", icon: "cross.case.fill", fields: healthAndSafety),
        FieldPreset(id: "equipment", name: "Equipment Details", icon: "wrench.and.screwdriver.fill", fields: equipmentDetails),
        FieldPreset(id: "approval", name: "Approval Section", icon: "checkmark.seal.fill", fields: approvalSection),
        FieldPreset(id: "witness", name: "Witness Section", icon: "person.2.fill", fields: witnessSection),
        FieldPreset(id: "location", name: "Location & GPS", icon: "location.fill", fields: locationAndGPS)
    ]
}

// MARK: - Field Preset Model

struct FieldPreset: Identifiable {
    let id: String
    let name: String
    let icon: String
    let fields: [FieldDefinition]
    
    func toFormFieldData(startingOrder: Int) -> [FormFieldData] {
        fields.enumerated().map { index, field in
            field.toFormFieldData(order: startingOrder + index)
        }
    }
}
