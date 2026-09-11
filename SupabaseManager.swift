//
//  SupabaseManager.swift
//  AFTR
//
//  Created by Wilgot Lucaci on 2026-08-26.
//

import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: SharedConfig.supabaseURL)!,
            supabaseKey: SharedConfig.supabaseKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    // Keychain access group shared with the AFTRWidgets
                    // extension, so the Live Activity's End Night button
                    // can read this same session and call the backend.
                    storage: KeychainLocalStorage(
                        accessGroup: SharedConfig.keychainAccessGroup
                    )
                )
            )
        )
    }
}
