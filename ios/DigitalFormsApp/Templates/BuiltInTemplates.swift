/**
 * BuiltInTemplates.swift
 * Pre-Built Form Templates
 *
 * Ready-to-use templates for common form types
 */

import Foundation

struct BuiltInTemplates {
    static let all: [TemplateDefinition] = [
        safetyInspection,
        incidentReport,
        workOrder,
        visitorSignIn,
        equipmentChecklist,
        timeSheet,
        expenseReport,
        customerFeedback,
        deliveryReceipt,
        maintenanceRequest
    ]

    // MARK: - Safety Inspection

    static let safetyInspection = TemplateDefinition(
        id: "safety-inspection",
        name: "Safety Inspection",
        description: "Workplace safety inspection checklist",
        category: "Safety",
        fields: [
            FieldDefinition(id: "date", type: "date", label: "Inspection Date", required: true),
            FieldDefinition(id: "location", type: "text", label: "Location/Area", required: true),
            FieldDefinition(id: "inspector", type: "text", label: "Inspector Name", required: true),
            FieldDefinition(id: "section1", type: "section", label: "General Safety"),
            FieldDefinition(id: "ppe", type: "yesNo", label: "PPE properly worn?", required: true),
            FieldDefinition(id: "exits", type: "yesNo", label: "Emergency exits clear?", required: true),
            FieldDefinition(id: "extinguishers", type: "yesNo", label: "Fire extinguishers accessible?", required: true),
            FieldDefinition(id: "firstaid", type: "yesNo", label: "First aid kit stocked?", required: true),
            FieldDefinition(id: "section2", type: "section", label: "Housekeeping"),
            FieldDefinition(id: "floors", type: "yesNo", label: "Floors clean and dry?", required: true),
            FieldDefinition(id: "aisles", type: "yesNo", label: "Aisles clear?", required: true),
            FieldDefinition(id: "storage", type: "yesNo", label: "Materials stored properly?", required: true),
            FieldDefinition(id: "section3", type: "section", label: "Equipment"),
            FieldDefinition(id: "equipment_condition", type: "dropdown", label: "Equipment Condition", required: true, options: ["Excellent", "Good", "Fair", "Poor", "Critical"]),
            FieldDefinition(id: "guards", type: "yesNo", label: "Machine guards in place?"),
            FieldDefinition(id: "section4", type: "section", label: "Summary"),
            FieldDefinition(id: "hazards", type: "textarea", label: "Hazards Identified"),
            FieldDefinition(id: "corrective_actions", type: "textarea", label: "Corrective Actions Required"),
            FieldDefinition(id: "photo", type: "photo", label: "Site Photo"),
            FieldDefinition(id: "rating", type: "rating", label: "Overall Safety Rating", required: true),
            FieldDefinition(id: "signature", type: "signature", label: "Inspector Signature", required: true)
        ]
    )

    // MARK: - Incident Report

    static let incidentReport = TemplateDefinition(
        id: "incident-report",
        name: "Incident Report",
        description: "Report workplace incidents and accidents",
        category: "Safety",
        fields: [
            FieldDefinition(id: "incident_date", type: "date", label: "Date of Incident", required: true),
            FieldDefinition(id: "incident_time", type: "time", label: "Time of Incident", required: true),
            FieldDefinition(id: "location", type: "location", label: "Location", required: true),
            FieldDefinition(id: "incident_type", type: "dropdown", label: "Type of Incident", required: true, options: ["Injury", "Near Miss", "Property Damage", "Environmental", "Security", "Other"]),
            FieldDefinition(id: "severity", type: "dropdown", label: "Severity", required: true, options: ["Minor", "Moderate", "Major", "Critical"]),
            FieldDefinition(id: "description", type: "textarea", label: "Description of Incident", required: true),
            FieldDefinition(id: "witnesses", type: "textarea", label: "Witness Names"),
            FieldDefinition(id: "section_injury", type: "section", label: "Injury Details"),
            FieldDefinition(id: "injury_occurred", type: "yesNo", label: "Did injury occur?", required: true),
            FieldDefinition(id: "injury_details", type: "textarea", label: "Injury Details"),
            FieldDefinition(id: "body_part", type: "dropdown", label: "Body Part Affected", options: ["Head", "Neck", "Back", "Arm", "Hand", "Leg", "Foot", "Multiple", "Other"]),
            FieldDefinition(id: "medical_treatment", type: "yesNo", label: "Medical treatment required?"),
            FieldDefinition(id: "section_actions", type: "section", label: "Actions"),
            FieldDefinition(id: "immediate_actions", type: "textarea", label: "Immediate Actions Taken", required: true),
            FieldDefinition(id: "root_cause", type: "textarea", label: "Root Cause Analysis"),
            FieldDefinition(id: "preventive_measures", type: "textarea", label: "Preventive Measures"),
            FieldDefinition(id: "photos", type: "photo", label: "Photos"),
            FieldDefinition(id: "reporter_name", type: "text", label: "Reporter Name", required: true),
            FieldDefinition(id: "reporter_phone", type: "phone", label: "Reporter Phone", required: true),
            FieldDefinition(id: "signature", type: "signature", label: "Reporter Signature", required: true)
        ]
    )

    // MARK: - Work Order

    static let workOrder = TemplateDefinition(
        id: "work-order",
        name: "Work Order",
        description: "Maintenance work order request",
        category: "Maintenance",
        fields: [
            FieldDefinition(id: "wo_number", type: "text", label: "Work Order #", required: true),
            FieldDefinition(id: "date_requested", type: "date", label: "Date Requested", required: true),
            FieldDefinition(id: "priority", type: "dropdown", label: "Priority", required: true, options: ["Low", "Medium", "High", "Emergency"]),
            FieldDefinition(id: "work_type", type: "dropdown", label: "Type of Work", required: true, options: ["Repair", "Maintenance", "Installation", "Inspection", "Replacement", "Other"]),
            FieldDefinition(id: "location", type: "text", label: "Location", required: true),
            FieldDefinition(id: "equipment_id", type: "text", label: "Equipment ID"),
            FieldDefinition(id: "equipment_name", type: "text", label: "Equipment Name"),
            FieldDefinition(id: "description", type: "textarea", label: "Work Description", required: true),
            FieldDefinition(id: "materials_needed", type: "textarea", label: "Materials Needed"),
            FieldDefinition(id: "estimated_hours", type: "number", label: "Estimated Hours"),
            FieldDefinition(id: "assigned_to", type: "text", label: "Assigned To"),
            FieldDefinition(id: "due_date", type: "date", label: "Due Date"),
            FieldDefinition(id: "special_instructions", type: "textarea", label: "Special Instructions"),
            FieldDefinition(id: "photo", type: "photo", label: "Photo"),
            FieldDefinition(id: "requestor_name", type: "text", label: "Requestor Name", required: true),
            FieldDefinition(id: "requestor_email", type: "email", label: "Requestor Email", required: true),
            FieldDefinition(id: "signature", type: "signature", label: "Requestor Signature", required: true)
        ]
    )

    // MARK: - Visitor Sign-In

    static let visitorSignIn = TemplateDefinition(
        id: "visitor-signin",
        name: "Visitor Sign-In",
        description: "Visitor registration and safety acknowledgment",
        category: "Administration",
        fields: [
            FieldDefinition(id: "date", type: "date", label: "Date", required: true),
            FieldDefinition(id: "time_in", type: "time", label: "Time In", required: true),
            FieldDefinition(id: "visitor_name", type: "text", label: "Visitor Name", required: true),
            FieldDefinition(id: "company", type: "text", label: "Company/Organization", required: true),
            FieldDefinition(id: "email", type: "email", label: "Email"),
            FieldDefinition(id: "phone", type: "phone", label: "Phone"),
            FieldDefinition(id: "visiting", type: "text", label: "Person Visiting", required: true),
            FieldDefinition(id: "department", type: "text", label: "Department"),
            FieldDefinition(id: "purpose", type: "dropdown", label: "Purpose of Visit", required: true, options: ["Meeting", "Delivery", "Interview", "Contractor Work", "Tour", "Training", "Other"]),
            FieldDefinition(id: "badge_number", type: "text", label: "Badge Number"),
            FieldDefinition(id: "vehicle", type: "text", label: "Vehicle License Plate"),
            FieldDefinition(id: "photo", type: "photo", label: "Visitor Photo"),
            FieldDefinition(id: "section_safety", type: "section", label: "Safety Acknowledgment"),
            FieldDefinition(id: "safety_briefing", type: "checkbox", label: "I have received a safety briefing", required: true),
            FieldDefinition(id: "emergency_procedures", type: "checkbox", label: "I understand emergency procedures", required: true),
            FieldDefinition(id: "escort_required", type: "checkbox", label: "I will remain with my escort"),
            FieldDefinition(id: "signature", type: "signature", label: "Visitor Signature", required: true)
        ]
    )

    // MARK: - Equipment Checklist

    static let equipmentChecklist = TemplateDefinition(
        id: "equipment-checklist",
        name: "Equipment Checklist",
        description: "Pre-use equipment inspection",
        category: "Operations",
        fields: [
            FieldDefinition(id: "date", type: "date", label: "Date", required: true),
            FieldDefinition(id: "equipment_type", type: "dropdown", label: "Equipment Type", required: true, options: ["Forklift", "Crane", "Vehicle", "Power Tool", "Machine", "Other"]),
            FieldDefinition(id: "equipment_id", type: "text", label: "Equipment ID/Number", required: true),
            FieldDefinition(id: "operator_name", type: "text", label: "Operator Name", required: true),
            FieldDefinition(id: "hour_meter", type: "number", label: "Hour Meter Reading"),
            FieldDefinition(id: "section_visual", type: "section", label: "Visual Inspection"),
            FieldDefinition(id: "damage", type: "yesNo", label: "Any visible damage?"),
            FieldDefinition(id: "leaks", type: "yesNo", label: "Any leaks?"),
            FieldDefinition(id: "tires_wheels", type: "yesNo", label: "Tires/wheels OK?"),
            FieldDefinition(id: "section_safety", type: "section", label: "Safety Features"),
            FieldDefinition(id: "lights", type: "yesNo", label: "Lights working?"),
            FieldDefinition(id: "horn", type: "yesNo", label: "Horn working?"),
            FieldDefinition(id: "brakes", type: "yesNo", label: "Brakes working?"),
            FieldDefinition(id: "seatbelt", type: "yesNo", label: "Seatbelt functional?"),
            FieldDefinition(id: "section_fluids", type: "section", label: "Fluids"),
            FieldDefinition(id: "fuel", type: "dropdown", label: "Fuel Level", options: ["Full", "3/4", "1/2", "1/4", "Empty"]),
            FieldDefinition(id: "oil", type: "yesNo", label: "Oil level OK?"),
            FieldDefinition(id: "coolant", type: "yesNo", label: "Coolant level OK?"),
            FieldDefinition(id: "defects", type: "textarea", label: "Defects Found"),
            FieldDefinition(id: "safe_to_operate", type: "yesNo", label: "Safe to operate?", required: true),
            FieldDefinition(id: "photo", type: "photo", label: "Photo"),
            FieldDefinition(id: "signature", type: "signature", label: "Operator Signature", required: true)
        ]
    )

    // MARK: - Time Sheet

    static let timeSheet = TemplateDefinition(
        id: "timesheet",
        name: "Time Sheet",
        description: "Daily or weekly time tracking",
        category: "HR",
        fields: [
            FieldDefinition(id: "employee_name", type: "text", label: "Employee Name", required: true),
            FieldDefinition(id: "employee_id", type: "text", label: "Employee ID"),
            FieldDefinition(id: "department", type: "text", label: "Department"),
            FieldDefinition(id: "week_ending", type: "date", label: "Week Ending", required: true),
            FieldDefinition(id: "section_hours", type: "section", label: "Hours Worked"),
            FieldDefinition(id: "monday", type: "number", label: "Monday"),
            FieldDefinition(id: "tuesday", type: "number", label: "Tuesday"),
            FieldDefinition(id: "wednesday", type: "number", label: "Wednesday"),
            FieldDefinition(id: "thursday", type: "number", label: "Thursday"),
            FieldDefinition(id: "friday", type: "number", label: "Friday"),
            FieldDefinition(id: "saturday", type: "number", label: "Saturday"),
            FieldDefinition(id: "sunday", type: "number", label: "Sunday"),
            FieldDefinition(id: "total_regular", type: "number", label: "Total Regular Hours"),
            FieldDefinition(id: "total_overtime", type: "number", label: "Total Overtime Hours"),
            FieldDefinition(id: "project_code", type: "text", label: "Project Code"),
            FieldDefinition(id: "notes", type: "textarea", label: "Notes"),
            FieldDefinition(id: "employee_signature", type: "signature", label: "Employee Signature", required: true),
            FieldDefinition(id: "supervisor_signature", type: "signature", label: "Supervisor Signature")
        ]
    )

    // MARK: - Expense Report

    static let expenseReport = TemplateDefinition(
        id: "expense-report",
        name: "Expense Report",
        description: "Business expense reimbursement",
        category: "Finance",
        fields: [
            FieldDefinition(id: "employee_name", type: "text", label: "Employee Name", required: true),
            FieldDefinition(id: "department", type: "text", label: "Department"),
            FieldDefinition(id: "report_date", type: "date", label: "Report Date", required: true),
            FieldDefinition(id: "period_start", type: "date", label: "Period Start", required: true),
            FieldDefinition(id: "period_end", type: "date", label: "Period End", required: true),
            FieldDefinition(id: "section_expenses", type: "section", label: "Expenses"),
            FieldDefinition(id: "expense_type", type: "dropdown", label: "Expense Type", required: true, options: ["Travel", "Meals", "Accommodation", "Transportation", "Supplies", "Other"]),
            FieldDefinition(id: "expense_date", type: "date", label: "Expense Date", required: true),
            FieldDefinition(id: "description", type: "text", label: "Description", required: true),
            FieldDefinition(id: "amount", type: "currency", label: "Amount", required: true),
            FieldDefinition(id: "receipt", type: "photo", label: "Receipt Photo", required: true),
            FieldDefinition(id: "business_purpose", type: "textarea", label: "Business Purpose", required: true),
            FieldDefinition(id: "total_amount", type: "currency", label: "Total Amount"),
            FieldDefinition(id: "employee_signature", type: "signature", label: "Employee Signature", required: true),
            FieldDefinition(id: "approver_signature", type: "signature", label: "Approver Signature")
        ]
    )

    // MARK: - Customer Feedback

    static let customerFeedback = TemplateDefinition(
        id: "customer-feedback",
        name: "Customer Feedback",
        description: "Customer satisfaction survey",
        category: "Customer Service",
        fields: [
            FieldDefinition(id: "date", type: "date", label: "Date", required: true),
            FieldDefinition(id: "customer_name", type: "text", label: "Customer Name"),
            FieldDefinition(id: "email", type: "email", label: "Email"),
            FieldDefinition(id: "phone", type: "phone", label: "Phone"),
            FieldDefinition(id: "order_number", type: "text", label: "Order/Reference Number"),
            FieldDefinition(id: "section_ratings", type: "section", label: "Ratings"),
            FieldDefinition(id: "overall", type: "rating", label: "Overall Satisfaction", required: true),
            FieldDefinition(id: "quality", type: "rating", label: "Product/Service Quality"),
            FieldDefinition(id: "timeliness", type: "rating", label: "Timeliness"),
            FieldDefinition(id: "staff", type: "rating", label: "Staff Helpfulness"),
            FieldDefinition(id: "value", type: "rating", label: "Value for Money"),
            FieldDefinition(id: "section_comments", type: "section", label: "Comments"),
            FieldDefinition(id: "liked", type: "textarea", label: "What did you like?"),
            FieldDefinition(id: "improve", type: "textarea", label: "What could we improve?"),
            FieldDefinition(id: "recommend", type: "yesNo", label: "Would you recommend us?"),
            FieldDefinition(id: "contact_ok", type: "checkbox", label: "May we contact you for follow-up?")
        ]
    )

    // MARK: - Delivery Receipt

    static let deliveryReceipt = TemplateDefinition(
        id: "delivery-receipt",
        name: "Delivery Receipt",
        description: "Proof of delivery document",
        category: "Logistics",
        fields: [
            FieldDefinition(id: "delivery_date", type: "date", label: "Delivery Date", required: true),
            FieldDefinition(id: "delivery_time", type: "time", label: "Delivery Time", required: true),
            FieldDefinition(id: "order_number", type: "text", label: "Order Number", required: true),
            FieldDefinition(id: "tracking_number", type: "text", label: "Tracking Number"),
            FieldDefinition(id: "section_sender", type: "section", label: "Sender"),
            FieldDefinition(id: "sender_name", type: "text", label: "Sender Name", required: true),
            FieldDefinition(id: "sender_address", type: "textarea", label: "Sender Address"),
            FieldDefinition(id: "section_recipient", type: "section", label: "Recipient"),
            FieldDefinition(id: "recipient_name", type: "text", label: "Recipient Name", required: true),
            FieldDefinition(id: "recipient_address", type: "textarea", label: "Delivery Address", required: true),
            FieldDefinition(id: "section_items", type: "section", label: "Items"),
            FieldDefinition(id: "item_description", type: "textarea", label: "Item Description", required: true),
            FieldDefinition(id: "quantity", type: "number", label: "Quantity", required: true),
            FieldDefinition(id: "condition", type: "dropdown", label: "Condition", required: true, options: ["Good", "Damaged", "Partial"]),
            FieldDefinition(id: "damage_notes", type: "textarea", label: "Damage Notes"),
            FieldDefinition(id: "photo", type: "photo", label: "Delivery Photo"),
            FieldDefinition(id: "location", type: "location", label: "GPS Location"),
            FieldDefinition(id: "recipient_signature", type: "signature", label: "Recipient Signature", required: true),
            FieldDefinition(id: "driver_name", type: "text", label: "Driver Name", required: true),
            FieldDefinition(id: "driver_signature", type: "signature", label: "Driver Signature", required: true)
        ]
    )

    // MARK: - Maintenance Request

    static let maintenanceRequest = TemplateDefinition(
        id: "maintenance-request",
        name: "Maintenance Request",
        description: "Facility maintenance request",
        category: "Facilities",
        fields: [
            FieldDefinition(id: "request_date", type: "date", label: "Request Date", required: true),
            FieldDefinition(id: "requester_name", type: "text", label: "Requester Name", required: true),
            FieldDefinition(id: "department", type: "text", label: "Department"),
            FieldDefinition(id: "contact_phone", type: "phone", label: "Contact Phone", required: true),
            FieldDefinition(id: "contact_email", type: "email", label: "Contact Email"),
            FieldDefinition(id: "location", type: "text", label: "Location/Room", required: true),
            FieldDefinition(id: "category", type: "dropdown", label: "Category", required: true, options: ["Electrical", "Plumbing", "HVAC", "Structural", "Cleaning", "Landscaping", "Other"]),
            FieldDefinition(id: "priority", type: "dropdown", label: "Priority", required: true, options: ["Low", "Medium", "High", "Emergency"]),
            FieldDefinition(id: "description", type: "textarea", label: "Description of Issue", required: true),
            FieldDefinition(id: "when_noticed", type: "date", label: "When was this noticed?"),
            FieldDefinition(id: "safety_hazard", type: "yesNo", label: "Is this a safety hazard?"),
            FieldDefinition(id: "preferred_time", type: "text", label: "Preferred Service Time"),
            FieldDefinition(id: "photo", type: "photo", label: "Photo of Issue"),
            FieldDefinition(id: "signature", type: "signature", label: "Requester Signature", required: true)
        ]
    )
}

// MARK: - Template Definition

struct TemplateDefinition: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String
    let fields: [FieldDefinition]
}

struct FieldDefinition {
    let id: String
    let type: String
    let label: String
    var required: Bool = false
    var options: [String]? = nil
    var placeholder: String? = nil

    func toFormFieldData(order: Int) -> FormFieldData {
        FormFieldData(
            id: id,
            type: type,
            label: label,
            required: required,
            options: options,
            placeholder: placeholder,
            order: order
        )
    }
}

// MARK: - Template Manager

class TemplateManager {
    static let shared = TemplateManager()

    func loadBuiltInTemplate(id: String) -> [FormFieldData]? {
        guard let template = BuiltInTemplates.all.first(where: { $0.id == id }) else {
            return nil
        }

        return template.fields.enumerated().map { index, field in
            field.toFormFieldData(order: index)
        }
    }

    func getAllTemplates() -> [TemplateDefinition] {
        return BuiltInTemplates.all
    }

    func getTemplatesByCategory(_ category: String) -> [TemplateDefinition] {
        return BuiltInTemplates.all.filter { $0.category == category }
    }

    func getCategories() -> [String] {
        let categories = Set(BuiltInTemplates.all.map { $0.category })
        return Array(categories).sorted()
    }
}
