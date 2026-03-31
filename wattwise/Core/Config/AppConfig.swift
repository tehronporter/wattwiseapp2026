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
    nonisolated(unsafe) static let supabaseURL     = "https://lxjjwodpiaivtkbjrodu.supabase.co"
    nonisolated(unsafe) static let supabaseAnonKey = "sb_publishable_-YEsxkbJAXMt1s9n1ie5LQ_zIFrm9Jx"

    // MARK: - Derived
    nonisolated(unsafe) static let supabaseBaseURL = URL(string: "https://lxjjwodpiaivtkbjrodu.supabase.co")!
    nonisolated(unsafe) static let edgeFunctionURL = URL(string: "https://lxjjwodpiaivtkbjrodu.supabase.co/functions/v1")!

    // MARK: - Feature flags
    // true  = mock services (works offline, no backend required) — use for TestFlight until Edge Functions are deployed
    // false = real Supabase backend (requires Edge Functions deployed at /functions/v1/*)
    nonisolated(unsafe) static let useMockServices = true
}
