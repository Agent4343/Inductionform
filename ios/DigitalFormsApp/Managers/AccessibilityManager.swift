/**
 * AccessibilityManager.swift
 * Accessibility and Dark Mode Support
 *
 * Features:
 * - Dark mode support
 * - Screen reader optimization
 * - Dynamic type support
 * - High contrast mode
 * - Voice over labels
 * - Accessibility announcements
 */

import SwiftUI
import UIKit

// MARK: - Accessibility Manager

class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    @Published var isDarkModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDarkModeEnabled, forKey: "darkModeEnabled")
            applyColorScheme()
        }
    }
    
    @Published var isHighContrastEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHighContrastEnabled, forKey: "highContrastEnabled")
        }
    }
    
    @Published var preferredTextSize: TextSize {
        didSet {
            UserDefaults.standard.set(preferredTextSize.rawValue, forKey: "preferredTextSize")
        }
    }
    
    @Published var isVoiceOverRunning: Bool
    @Published var shouldReduceMotion: Bool
    @Published var shouldReduceTransparency: Bool
    
    enum TextSize: String, CaseIterable {
        case small = "small"
        case medium = "medium"
        case large = "large"
        case extraLarge = "extra_large"
        
        var displayName: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            case .extraLarge: return "Extra Large"
            }
        }
        
        var scaleFactor: CGFloat {
            switch self {
            case .small: return 0.9
            case .medium: return 1.0
            case .large: return 1.2
            case .extraLarge: return 1.4
            }
        }
    }
    
    private init() {
        self.isDarkModeEnabled = UserDefaults.standard.bool(forKey: "darkModeEnabled")
        self.isHighContrastEnabled = UserDefaults.standard.bool(forKey: "highContrastEnabled")
        
        if let sizeRaw = UserDefaults.standard.string(forKey: "preferredTextSize"),
           let size = TextSize(rawValue: sizeRaw) {
            self.preferredTextSize = size
        } else {
            self.preferredTextSize = .medium
        }
        
        self.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        self.shouldReduceMotion = UIAccessibility.isReduceMotionEnabled
        self.shouldReduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        
        setupAccessibilityObservers()
    }
    
    // MARK: - Setup
    
    private func setupAccessibilityObservers() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.shouldReduceMotion = UIAccessibility.isReduceMotionEnabled
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.shouldReduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        }
    }
    
    // MARK: - Color Scheme
    
    func applyColorScheme() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = isDarkModeEnabled ? .dark : .light
            }
        }
    }
    
    // MARK: - Announcements
    
    func announce(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        UIAccessibility.post(notification: priority, argument: message)
    }
    
    func announceScreenChange(to element: Any?) {
        UIAccessibility.post(notification: .screenChanged, argument: element)
    }
    
    // MARK: - Accessibility Helpers
    
    func makeAccessible(
        label: String,
        hint: String? = nil,
        traits: UIAccessibilityTraits? = nil,
        value: String? = nil
    ) -> some View {
        EmptyView()
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits ?? [])
    }
}

// MARK: - Accessibility View Modifiers

extension View {
    func accessibleLabel(_ label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
    
    func accessibleButton(_ label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
    
    func accessibleHeader(_ label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isHeader)
    }
    
    func accessibleFormField(_ label: String, value: String?, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "Empty")
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - Theme Configuration

struct AppTheme {
    static let shared = AppTheme()
    
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared
    
    // MARK: - Colors
    
    var primaryColor: Color {
        accessibilityManager.isHighContrastEnabled ? .blue : .accentColor
    }
    
    var backgroundColor: Color {
        accessibilityManager.isHighContrastEnabled
            ? (accessibilityManager.isDarkModeEnabled ? .black : .white)
            : Color(.systemBackground)
    }
    
    var secondaryBackgroundColor: Color {
        accessibilityManager.isHighContrastEnabled
            ? (accessibilityManager.isDarkModeEnabled ? Color(.darkGray) : Color(.lightGray))
            : Color(.secondarySystemBackground)
    }
    
    var textColor: Color {
        accessibilityManager.isHighContrastEnabled
            ? (accessibilityManager.isDarkModeEnabled ? .white : .black)
            : Color(.label)
    }
    
    var secondaryTextColor: Color {
        accessibilityManager.isHighContrastEnabled
            ? (accessibilityManager.isDarkModeEnabled ? Color(.lightGray) : Color(.darkGray))
            : Color(.secondaryLabel)
    }
    
    // MARK: - Typography
    
    func font(_ style: Font.TextStyle) -> Font {
        let baseFont = Font.system(style)
        return baseFont
    }
    
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let scaledSize = size * accessibilityManager.preferredTextSize.scaleFactor
        return .system(size: scaledSize, weight: weight)
    }
    
    // MARK: - Spacing
    
    var standardPadding: CGFloat {
        16 * accessibilityManager.preferredTextSize.scaleFactor
    }
    
    var compactPadding: CGFloat {
        8 * accessibilityManager.preferredTextSize.scaleFactor
    }
    
    // MARK: - Animation
    
    var standardAnimation: Animation {
        accessibilityManager.shouldReduceMotion ? .none : .default
    }
    
    func animation(_ animation: Animation) -> Animation {
        accessibilityManager.shouldReduceMotion ? .none : animation
    }
}

// MARK: - Accessibility Settings View

import SwiftUI

struct AccessibilitySettingsView: View {
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    
    var body: some View {
        Form {
            Section("Visual") {
                Toggle("Dark Mode", isOn: $accessibilityManager.isDarkModeEnabled)
                    .accessibleLabel("Dark Mode", hint: "Enable dark color scheme")
                
                Toggle("High Contrast", isOn: $accessibilityManager.isHighContrastEnabled)
                    .accessibleLabel("High Contrast", hint: "Increase contrast for better visibility")
                
                Picker("Text Size", selection: $accessibilityManager.preferredTextSize) {
                    ForEach(AccessibilityManager.TextSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .accessibleLabel("Text Size", hint: "Adjust text size throughout the app")
            }
            
            Section("System Settings") {
                HStack {
                    Text("VoiceOver")
                    Spacer()
                    Text(accessibilityManager.isVoiceOverRunning ? "On" : "Off")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("VoiceOver status: \(accessibilityManager.isVoiceOverRunning ? "On" : "Off")")
                
                HStack {
                    Text("Reduce Motion")
                    Spacer()
                    Text(accessibilityManager.shouldReduceMotion ? "On" : "Off")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Reduce Motion status: \(accessibilityManager.shouldReduceMotion ? "On" : "Off")")
                
                HStack {
                    Text("Reduce Transparency")
                    Spacer()
                    Text(accessibilityManager.shouldReduceTransparency ? "On" : "Off")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Reduce Transparency status: \(accessibilityManager.shouldReduceTransparency ? "On" : "Off")")
            } footer: {
                Text("These settings are controlled in System Settings")
                    .font(.caption)
            }
            
            Section("About Accessibility") {
                Text("DigitalForms is designed to be accessible to everyone. We support VoiceOver, Dynamic Type, and other iOS accessibility features.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Accessibility")
    }
}

// MARK: - Example: Accessible Form Field

struct AccessibleFormField: View {
    let label: String
    let fieldType: String
    @Binding var value: String
    let isRequired: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .accessibilityLabel("Required")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label + (isRequired ? ", required" : ""))
            
            TextField(label, text: $value)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(label)
                .accessibilityValue(value.isEmpty ? "Empty" : value)
                .accessibilityHint(isRequired ? "This is a required field" : "Optional field")
        }
    }
}

#Preview {
    NavigationStack {
        AccessibilitySettingsView()
    }
}
