import Foundation

// MARK: - WattWise App Configuration
//
// The publishable key (anon key) is safe to ship in the iOS binary —
// it is a Supabase-designed public credential subject to Row-Level Security.
//
// The SECRET key is NEVER stored here. It lives only in Supabase Edge Function
// environment variables and in the gitignored .env.local file.

enum AppConfig {
    // MARK: - Supabase
    nonisolated static let supabaseURL     = "https://lxjjwodpiaivtkbjrodu.supabase.co"
    nonisolated static let supabaseAnonKey = "sb_publishable_-YEsxkbJAXMt1s9n1ie5LQ_zIFrm9Jx"

    // MARK: - Derived
    nonisolated static let supabaseBaseURL = URL(string: "https://lxjjwodpiaivtkbjrodu.supabase.co")!
    nonisolated static let edgeFunctionURL = URL(string: "https://lxjjwodpiaivtkbjrodu.supabase.co/functions/v1")!

    // MARK: - Feature flags
    // Production should use the real backend.
    // Mocks stay enabled for tests, previews, and explicit local override.
    nonisolated static let useMockServices: Bool = {
        let processInfo = ProcessInfo.processInfo
        let isPreview = processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let isUnitTest = processInfo.environment["XCTestConfigurationFilePath"] != nil
        let isUITest = processInfo.arguments.contains("UITEST_MODE")
        let forcedMock = processInfo.environment["WATTWISE_USE_MOCK_SERVICES"] == "1"
        return isPreview || isUnitTest || isUITest || forcedMock
    }()
}
