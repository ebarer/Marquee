//
//  WikidataWrapper.swift
//  MovieTracker
//
//  Awards and the Rotten Tomatoes slug, keyed on the `wikidata_id` TMDB returns in `external_ids`.
//

import Foundation

enum WikidataWrapper {
    private static let sparqlURL = "https://query.wikidata.org/sparql"
    private static let apiURL = "https://www.wikidata.org/w/api.php"

    // Wikidata rejects requests that don't identify the client.
    private static let userAgent = "Marquee/1.0 (https://github.com/ebarer/MovieTracker)"

    // "Group of awards": the Wikidata class marking an award series rather than a single category.
    private static let awardSeriesClass = "Q107655869"

    static func awards(qid: String) async throws -> AwardsDigest {
        guard isEntityID(qid) else { return AwardsDigest() }
        let response: SPARQLResponse = try await sparql(awardsQuery(qid: qid))
        let awards = response.results.bindings.compactMap { row -> Award? in
            guard let category = row["catLabel"]?.value, !category.isEmpty else { return nil }
            // An unlabelled series resolves to its raw Q-id, which is noise in a header.
            var series = row["seriesLabel"]?.value
            if let label = series, label.isEmpty || isEntityID(label) { series = nil }
            return Award(category: category,
                         series: series,
                         year: Int(row["year"]?.value ?? ""),
                         isWin: row["won"]?.value == "true")
        }
        return AwardsDigest(awards: awards)
    }

    // One property off one entity doesn't warrant a query-service hit, so read `wbgetclaims`.
    static func rottenTomatoesID(qid: String) async throws -> String? {
        guard isEntityID(qid) else { return nil }
        var components = URLComponents(string: apiURL)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "wbgetclaims"),
            URLQueryItem(name: "entity", value: qid),
            URLQueryItem(name: "property", value: "P1258"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else { return nil }
        let response: ClaimsResponse = try await get(url)
        return response.claims?["P1258"]?.first?.mainsnak.datavalue?.value
    }

    // Guards the value interpolated into the SPARQL query below; anything but a bare entity id is rejected.
    private static func isEntityID(_ value: String) -> Bool {
        value.count > 1 && value.first == "Q" && value.dropFirst().allSatisfy(\.isNumber)
    }
}

// MARK: - Queries

private extension WikidataWrapper {
    // P166 is "award received", P1411 "nominated for", P585 the ceremony date.
    // A category reaches its series through either "part of" or "instance of"; Wikidata uses both.
    static func awardsQuery(qid: String) -> String {
        """
        SELECT DISTINCT ?catLabel ?seriesLabel ?year ?won WHERE {
          { wd:\(qid) p:P166 ?statement . BIND(true AS ?won) }
          UNION
          { wd:\(qid) p:P1411 ?statement . BIND(false AS ?won) }
          ?statement ps:P166|ps:P1411 ?cat .
          OPTIONAL { ?statement pq:P585 ?date . BIND(YEAR(?date) AS ?year) }
          OPTIONAL {
            ?cat (wdt:P361|wdt:P31) ?series .
            ?series wdt:P31 wd:\(awardSeriesClass) .
          }
          SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
        }
        LIMIT 300
        """
    }

    static func sparql<T: Decodable>(_ query: String) async throws -> T {
        var components = URLComponents(string: sparqlURL)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else {
            throw FetchError.noData("Couldn't build Wikidata query URL.")
        }
        return try await get(url)
    }

    static func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw FetchError.decode("Couldn't decode Wikidata response: \(error)")
        }
    }
}

// MARK: - Responses

private extension WikidataWrapper {
    struct SPARQLResponse: Decodable {
        var results: Results

        struct Results: Decodable {
            var bindings: [[String: Binding]]
        }

        /// SPARQL JSON reports every value as a string, booleans and years included.
        struct Binding: Decodable {
            var value: String
        }
    }

    struct ClaimsResponse: Decodable {
        var claims: [String: [Claim]]?

        struct Claim: Decodable {
            var mainsnak: Snak
        }

        struct Snak: Decodable {
            var datavalue: DataValue?
        }

        struct DataValue: Decodable {
            var value: String
        }
    }
}
