import Foundation

enum WattWiseContentCatalog {
    static func loadFromBundle() throws -> WattWiseContentPack {
        guard let url = Bundle.main.url(forResource: "WattWiseContentPack", withExtension: "json") else {
            throw AppError.notFound("WattWiseContentPack.json is missing from the app bundle.")
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WattWiseContentPack.self, from: data)
    }
}
