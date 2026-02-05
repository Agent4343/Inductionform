/**
 * ValidationRules.swift
 * Advanced Field Validation System
 *
 * Supports regex-based validation, custom rules, and conditional validation
 */

import Foundation

// MARK: - Validation Rule

struct ValidationRule: Codable, Identifiable {
    let id: String
    let type: ValidationType
    let pattern: String?
    let message: String
    let min: Double?
    let max: Double?
    
    enum ValidationType: String, Codable {
        case required
        case email
        case phone
        case regex
        case minLength
        case maxLength
        case numeric
        case alphanumeric
        case url
        case postalCode
        case sin // Social Insurance Number
        case date
        case time
        case minValue
        case maxValue
        case custom
    }
    
    init(id: String = UUID().uuidString, type: ValidationType, pattern: String? = nil, message: String, min: Double? = nil, max: Double? = nil) {
        self.id = id
        self.type = type
        self.pattern = pattern
        self.message = message
        self.min = min
        self.max = max
    }
}

// MARK: - Validation Engine

class ValidationEngine {
    
    static let shared = ValidationEngine()
    
    private init() {}
    
    // MARK: - Validation Methods
    
    func validate(value: String?, against rules: [ValidationRule]) -> ValidationResult {
        var errors: [String] = []
        
        for rule in rules {
            let result = validateSingleRule(value: value, rule: rule)
            if !result.isValid {
                errors.append(contentsOf: result.errors)
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    private func validateSingleRule(value: String?, rule: ValidationRule) -> ValidationResult {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        switch rule.type {
        case .required:
            return trimmedValue.isEmpty
                ? ValidationResult(isValid: false, errors: [rule.message])
                : ValidationResult(isValid: true, errors: [])
            
        case .email:
            return validateEmail(trimmedValue, message: rule.message)
            
        case .phone:
            return validatePhone(trimmedValue, message: rule.message)
            
        case .regex:
            guard let pattern = rule.pattern else {
                return ValidationResult(isValid: true, errors: [])
            }
            return validateRegex(trimmedValue, pattern: pattern, message: rule.message)
            
        case .minLength:
            guard let min = rule.min else {
                return ValidationResult(isValid: true, errors: [])
            }
            return trimmedValue.count >= Int(min)
                ? ValidationResult(isValid: true, errors: [])
                : ValidationResult(isValid: false, errors: [rule.message])
            
        case .maxLength:
            guard let max = rule.max else {
                return ValidationResult(isValid: true, errors: [])
            }
            return trimmedValue.count <= Int(max)
                ? ValidationResult(isValid: true, errors: [])
                : ValidationResult(isValid: false, errors: [rule.message])
            
        case .numeric:
            return Double(trimmedValue) != nil
                ? ValidationResult(isValid: true, errors: [])
                : ValidationResult(isValid: false, errors: [rule.message])
            
        case .alphanumeric:
            return validateAlphanumeric(trimmedValue, message: rule.message)
            
        case .url:
            return validateURL(trimmedValue, message: rule.message)
            
        case .postalCode:
            return validateCanadianPostalCode(trimmedValue, message: rule.message)
            
        case .sin:
            return validateSIN(trimmedValue, message: rule.message)
            
        case .minValue:
            guard let min = rule.min, let numValue = Double(trimmedValue) else {
                return ValidationResult(isValid: true, errors: [])
            }
            return numValue >= min
                ? ValidationResult(isValid: true, errors: [])
                : ValidationResult(isValid: false, errors: [rule.message])
            
        case .maxValue:
            guard let max = rule.max, let numValue = Double(trimmedValue) else {
                return ValidationResult(isValid: true, errors: [])
            }
            return numValue <= max
                ? ValidationResult(isValid: true, errors: [])
                : ValidationResult(isValid: false, errors: [rule.message])
            
        case .date, .time, .custom:
            // These require custom implementation
            return ValidationResult(isValid: true, errors: [])
        }
    }
    
    // MARK: - Specific Validators
    
    private func validateEmail(_ value: String, message: String) -> ValidationResult {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        return validateRegex(value, pattern: emailRegex, message: message)
    }
    
    private func validatePhone(_ value: String, message: String) -> ValidationResult {
        // Accept various phone formats: (555) 123-4567, 555-123-4567, 5551234567
        let phoneRegex = #"^(\+?\d{1,2}\s?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}$"#
        return validateRegex(value, pattern: phoneRegex, message: message)
    }
    
    private func validateCanadianPostalCode(_ value: String, message: String) -> ValidationResult {
        // Format: A1A 1A1 or A1A1A1
        let postalCodeRegex = #"^[A-Za-z]\d[A-Za-z]\s?\d[A-Za-z]\d$"#
        return validateRegex(value, pattern: postalCodeRegex, message: message)
    }
    
    private func validateSIN(_ value: String, message: String) -> ValidationResult {
        // Canadian Social Insurance Number: 123-456-789 or 123456789
        let sinRegex = #"^\d{3}-?\d{3}-?\d{3}$"#
        let result = validateRegex(value, pattern: sinRegex, message: message)
        
        if !result.isValid {
            return result
        }
        
        // Luhn algorithm validation
        let digits = value.filter { $0.isNumber }
        if validateLuhn(digits) {
            return ValidationResult(isValid: true, errors: [])
        } else {
            return ValidationResult(isValid: false, errors: ["Invalid SIN number"])
        }
    }
    
    private func validateURL(_ value: String, message: String) -> ValidationResult {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              components.host != nil else {
            return ValidationResult(isValid: false, errors: [message])
        }
        return ValidationResult(isValid: true, errors: [])
    }
    
    private func validateAlphanumeric(_ value: String, message: String) -> ValidationResult {
        let alphanumericRegex = #"^[a-zA-Z0-9]+$"#
        return validateRegex(value, pattern: alphanumericRegex, message: message)
    }
    
    private func validateRegex(_ value: String, pattern: String, message: String) -> ValidationResult {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return ValidationResult(isValid: true, errors: [])
        }
        
        let range = NSRange(location: 0, length: value.utf16.count)
        let matches = regex.firstMatch(in: value, options: [], range: range)
        
        return matches != nil
            ? ValidationResult(isValid: true, errors: [])
            : ValidationResult(isValid: false, errors: [message])
    }
    
    // Luhn algorithm for SIN validation
    private func validateLuhn(_ digits: String) -> Bool {
        var sum = 0
        let reversedDigits = digits.reversed().map { Int(String($0)) ?? 0 }
        
        for (index, digit) in reversedDigits.enumerated() {
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        
        return sum % 10 == 0
    }
}

// MARK: - Validation Result

struct ValidationResult {
    let isValid: Bool
    let errors: [String]
}

// MARK: - Pre-defined Validation Rules

extension ValidationRule {
    
    // Common validation rules
    
    static func required(message: String = "This field is required") -> ValidationRule {
        ValidationRule(type: .required, message: message)
    }
    
    static func email(message: String = "Please enter a valid email address") -> ValidationRule {
        ValidationRule(type: .email, message: message)
    }
    
    static func phone(message: String = "Please enter a valid phone number") -> ValidationRule {
        ValidationRule(type: .phone, message: message)
    }
    
    static func minLength(_ length: Int, message: String? = nil) -> ValidationRule {
        ValidationRule(
            type: .minLength,
            message: message ?? "Must be at least \(length) characters",
            min: Double(length)
        )
    }
    
    static func maxLength(_ length: Int, message: String? = nil) -> ValidationRule {
        ValidationRule(
            type: .maxLength,
            message: message ?? "Must not exceed \(length) characters",
            max: Double(length)
        )
    }
    
    static func numeric(message: String = "Must be a number") -> ValidationRule {
        ValidationRule(type: .numeric, message: message)
    }
    
    static func alphanumeric(message: String = "Must contain only letters and numbers") -> ValidationRule {
        ValidationRule(type: .alphanumeric, message: message)
    }
    
    static func url(message: String = "Please enter a valid URL") -> ValidationRule {
        ValidationRule(type: .url, message: message)
    }
    
    static func postalCode(message: String = "Please enter a valid postal code") -> ValidationRule {
        ValidationRule(type: .postalCode, message: message)
    }
    
    static func sin(message: String = "Please enter a valid SIN") -> ValidationRule {
        ValidationRule(type: .sin, message: message)
    }
    
    static func minValue(_ value: Double, message: String? = nil) -> ValidationRule {
        ValidationRule(
            type: .minValue,
            message: message ?? "Must be at least \(value)",
            min: value
        )
    }
    
    static func maxValue(_ value: Double, message: String? = nil) -> ValidationRule {
        ValidationRule(
            type: .maxValue,
            message: message ?? "Must not exceed \(value)",
            max: value
        )
    }
    
    static func regex(pattern: String, message: String) -> ValidationRule {
        ValidationRule(type: .regex, pattern: pattern, message: message)
    }
}

// MARK: - Field with Validation

extension FormFieldData {
    var validationRules: [ValidationRule] {
        get {
            // For now, return default rules based on type
            // Can be extended to store custom rules in field metadata
            var rules: [ValidationRule] = []
            
            if required {
                rules.append(.required())
            }
            
            switch type {
            case "email":
                rules.append(.email())
            case "phone":
                rules.append(.phone())
            case "number":
                rules.append(.numeric())
            default:
                break
            }
            
            return rules
        }
    }
    
    func validate() -> ValidationResult {
        return ValidationEngine.shared.validate(value: value, against: validationRules)
    }
}
