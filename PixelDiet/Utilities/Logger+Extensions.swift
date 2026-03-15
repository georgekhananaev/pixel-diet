import os

extension Logger {
    static let compression = Logger(subsystem: "com.georgekhananaev.PixelDiet", category: "compression")
    static let batch = Logger(subsystem: "com.georgekhananaev.PixelDiet", category: "batch")
    static let thumbnail = Logger(subsystem: "com.georgekhananaev.PixelDiet", category: "thumbnail")
    static let fileAccess = Logger(subsystem: "com.georgekhananaev.PixelDiet", category: "fileAccess")
}
