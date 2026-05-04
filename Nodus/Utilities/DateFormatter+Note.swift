//
//  DateFormatter+Note.swift
//  Nodus
//
//  Note filenames use a 12-digit local timestamp: yyyyMMddHHmm (e.g. 202604271321).
//

import Foundation

extension DateFormatter {
    /// Parses and formats the note ID prefix in filenames (`YYYYMMDDHHmm` as `yyyyMMddHHmm`).
    /// Locale and calendar are fixed so strings do not vary by user settings.
    /// Time zone uses the user's device local setting.
    static let noteTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter
    }()
}
