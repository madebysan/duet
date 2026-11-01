#if DEBUG
import SwiftUI
import UIKit

// Debug-only feedback inbox (from the ios-feedback skill). Shake the phone, say what should change,
// and the note is saved with a screenshot and the app's state to Documents/Feedback. On the Mac,
// `scripts/feedback/pull.sh` copies new notes into work/feedback/inbox for an agent to work through
// (docs/feedback-inbox.md). Release builds compile none of this: no shake handler, no files.

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            FeedbackInbox.present(from: self)
        }
        super.motionEnded(motion, with: event)
    }
}

@MainActor
enum FeedbackInbox {
    private static var isPresenting = false

    static var folder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Feedback", isDirectory: true)
    }

    static func present(from window: UIWindow) {
        guard !isPresenting, let root = window.rootViewController else { return }
        // Capture before the sheet covers the screen.
        let screenshot = snapshot(of: window)
        let context = FeedbackContext.collect(in: window)

        var top = root
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }

        isPresenting = true
        let host = UIHostingController(rootView: FeedbackSheet(screenshot: screenshot, context: context))
        host.overrideUserInterfaceStyle = .dark
        top.present(host, animated: true)
    }

    static func sheetDidClose() {
        isPresenting = false
    }

    static func save(text: String, screenshot: UIImage?, context: FeedbackContext) throws -> URL {
        let id = context.id
        let directory = folder.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let note = """
        # \(context.appName) feedback \(id)

        \(text.trimmingCharacters(in: .whitespacesAndNewlines))

        ---
        Build \(context.appVersion) (\(context.build)) · iOS \(context.systemVersion) · \(context.deviceModel)

        """
        try Data(note.utf8).write(to: directory.appendingPathComponent("note.md"), options: .atomic)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(context).write(to: directory.appendingPathComponent("context.json"), options: .atomic)

        if let png = screenshot?.pngData() {
            try png.write(to: directory.appendingPathComponent("screenshot.png"), options: .atomic)
        }
        return directory
    }

    private static func snapshot(of window: UIWindow) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }
}

/// What the app looked like when the note was written, so the request can be found in the code.
struct FeedbackContext: Codable {
    var id: String
    var appName: String
    var createdAt: String
    var appVersion: String
    var build: String
    var systemVersion: String
    var deviceModel: String
    /// View controller chain from the root to the topmost presented one (sheets show up here).
    var presentedControllers: [String]
    /// This app's saved settings (UserDefaults), as text.
    var settings: [String: String]

    @MainActor
    static func collect(in window: UIWindow) -> FeedbackContext {
        let now = Date()
        let idFormatter = DateFormatter()
        idFormatter.locale = Locale(identifier: "en_US_POSIX")
        idFormatter.dateFormat = "yyyyMMdd-HHmmss"

        let info = Bundle.main.infoDictionary ?? [:]
        return FeedbackContext(
            id: idFormatter.string(from: now),
            appName: info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? "App",
            createdAt: ISO8601DateFormatter().string(from: now),
            appVersion: info["CFBundleShortVersionString"] as? String ?? "?",
            build: info["CFBundleVersion"] as? String ?? "?",
            systemVersion: UIDevice.current.systemVersion,
            deviceModel: hardwareModel(),
            presentedControllers: controllerChain(from: window.rootViewController),
            settings: savedSettings()
        )
    }

    private static func hardwareModel() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return "\(simulated) (Simulator)"
        }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { bytes in
            String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    @MainActor
    private static func controllerChain(from root: UIViewController?) -> [String] {
        var chain: [String] = []
        var current = root
        while let controller = current {
            chain.append(String(describing: type(of: controller)))
            current = controller.presentedViewController
        }
        return chain
    }

    private static func savedSettings() -> [String: String] {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let values = UserDefaults.standard.persistentDomain(forName: bundleID) else { return [:] }
        var settings: [String: String] = [:]
        for (key, value) in values {
            switch value {
            case let string as String:
                settings[key] = string.count > 200 ? String(string.prefix(200)) + "…" : string
            case let number as NSNumber:
                settings[key] = number.stringValue
            case let data as Data:
                settings[key] = "<\(data.count) bytes>"
            default:
                settings[key] = String(describing: type(of: value))
            }
        }
        return settings
    }
}

private struct FeedbackSheet: View {
    let screenshot: UIImage?
    let context: FeedbackContext

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    if let screenshot {
                        Image(uiImage: screenshot)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 132)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(.white.opacity(0.15))
                            )
                            .accessibilityLabel("Screenshot of the current screen")
                    }
                    Text("The screenshot and your settings are saved with the note. It stays on this phone until the Mac pulls it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("What should change?")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .accessibilityHidden(true)
                    }
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .accessibilityLabel("What should change?")
                }
                .padding(8)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear { isFocused = true }
        .onDisappear { FeedbackInbox.sheetDidClose() }
    }

    private func save() {
        do {
            _ = try FeedbackInbox.save(text: text, screenshot: screenshot, context: context)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorMessage = "Couldn't save the note: \(error.localizedDescription)"
        }
    }
}
#endif
