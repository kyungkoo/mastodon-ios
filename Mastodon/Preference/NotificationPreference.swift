//
//  NotificationPreference.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-4-26.
//

import UIKit
import MastodonExtension

extension UserDefaults {
    
    @objc dynamic var notificationBadgeCount: Int {
        get {
            register(defaults: [#function: 0])
            return integer(forKey: #function)
        }
        set { self[#function] = newValue }
    }

}
