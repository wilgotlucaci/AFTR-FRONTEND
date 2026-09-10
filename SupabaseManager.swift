import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(
                string: "https://vdwpzritssipffhsbsxs.supabase.co"
            )!,
            supabaseKey: "sb_publishable_uFSh2-phxWKDJabl3qNKjA_euxjq8Cd"
        )
    }
}//
//  SupabaseManager.swift
//  AFTR
//
//  Created by Wilgot Lucaci on 2026-08-26.
//

