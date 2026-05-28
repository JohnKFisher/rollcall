import XCTest
@testable import RollCall

final class RosterCSVImportTests: XCTestCase {
    private var temp: RollCallTemporaryDirectory!
    private let service = PackageService()

    override func setUpWithError() throws {
        temp = try RollCallTemporaryDirectory()
    }

    override func tearDown() {
        temp = nil
    }

    func testParseRosterCSVAcceptsHeaderRowsAndTrimsValues() async throws {
        let url = try temp.write(
            """
            name, number
             Alex Ramirez , 12
            Jordan Lee,4
            """,
            to: "roster.csv"
        )

        let rows = try await service.parseRosterCSV(from: url)

        XCTAssertEqual(rows, [
            ParsedRosterRow(name: "Alex Ramirez", number: "12"),
            ParsedRosterRow(name: "Jordan Lee", number: "4"),
        ])
    }

    func testParseRosterCSVAcceptsSimpleRowsWithoutHeader() async throws {
        let url = try temp.write(
            """
            Alex Ramirez,12
            Casey Morgan
            """,
            to: "simple.csv"
        )

        let rows = try await service.parseRosterCSV(from: url)

        XCTAssertEqual(rows, [
            ParsedRosterRow(name: "Alex Ramirez", number: "12"),
            ParsedRosterRow(name: "Casey Morgan", number: ""),
        ])
    }

    func testParseRosterCSVKeepsQuotedCommasInsideNames() async throws {
        let url = try temp.write(
            """
            name,number
            "Ramirez, Alex",12
            """,
            to: "quoted.csv"
        )

        let rows = try await service.parseRosterCSV(from: url)

        XCTAssertEqual(rows, [ParsedRosterRow(name: "Ramirez, Alex", number: "12")])
    }

    func testParseRosterCSVRejectsEmptyOrNamelessFiles() async throws {
        let emptyURL = try temp.write("\n\n", to: "empty.csv")
        let namelessURL = try temp.write("name,number\n,12", to: "nameless.csv")

        await XCTAssertThrowsErrorAsync(try await service.parseRosterCSV(from: emptyURL)) { error in
            XCTAssertAppError(error, is: .invalidCSV)
        }
        await XCTAssertThrowsErrorAsync(try await service.parseRosterCSV(from: namelessURL)) { error in
            XCTAssertAppError(error, is: .invalidCSV)
        }
    }

    func testPendingRosterImportCountsExistingAndImportedDuplicates() {
        let existing = [
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12"),
        ]
        let pending = PendingRosterImport(
            sourceName: "roster.csv",
            rows: [
                RollCallTestFixtures.player(id: RollCallTestFixtures.jordanID, name: " alex ramirez ", number: " 12 "),
                RollCallTestFixtures.player(id: RollCallTestFixtures.caseyID, name: "Casey Morgan", number: "9"),
                RollCallTestFixtures.player(id: UUID(), name: "Casey Morgan", number: "9"),
            ]
        )

        XCTAssertEqual(pending.duplicateCount(comparedTo: existing), 2)
        XCTAssertEqual(
            PendingRosterImport.duplicateMessage(count: 2),
            "2 possible duplicate players found by matching name and number."
        )
    }
}

func XCTAssertAppError(
    _ error: Error,
    is expected: AppError,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let appError = error as? AppError else {
        return XCTFail("Expected AppError, got \(error)", file: file, line: line)
    }

    switch (appError, expected) {
    case (.invalidCSV, .invalidCSV),
         (.invalidImport, .invalidImport),
         (.unsupportedImportVersion, .unsupportedImportVersion),
         (.unsupportedSavedStateVersion, .unsupportedSavedStateVersion):
        return
    default:
        XCTFail("Expected \(expected), got \(appError)", file: file, line: line)
    }
}

func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
