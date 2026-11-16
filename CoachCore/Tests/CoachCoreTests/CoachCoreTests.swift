import Testing
@testable import CoachCore

@Test func packageBuildsAndExposesSchemaVersion() {
    #expect(CoachCore.schemaVersion >= 1)
}
