import Foundation

enum AppFormat {
    static func time(_ date: Date?) -> String {
        guard let date else { return "" }
        return timeFormatter.string(from: date)
    }

    static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func elapsed(since date: Date?) -> String {
        guard let date else { return "" }
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        if minutes < 1 { return "только что" }
        if minutes < 60 { return "\(minutes) мин" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours < 24 {
            return remainder == 0 ? "\(hours) ч" : "\(hours) ч \(remainder) мин"
        }
        let days = hours / 24
        return "\(days) \(plural(days, "день", "дня", "дней"))"
    }

    static func guests(_ count: Int) -> String {
        "\(count) \(plural(count, "гость", "гостя", "гостей"))"
    }

    static func items(_ count: Int) -> String {
        "\(count) \(plural(count, "позиция", "позиции", "позиций"))"
    }

    static func plural(_ number: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod10 = abs(number) % 10
        let mod100 = abs(number) % 100
        if mod10 == 1 && mod100 != 11 { return one }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return few }
        return many
    }

    static func versionString() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}
