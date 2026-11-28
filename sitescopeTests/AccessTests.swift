import XCTest

#if canImport(sitescopeCore)
    @testable import sitescopeCore
#else
    @testable import sitescope
#endif

/// The permission table in docs/DATABASE_API.md, as the app reads it to show or hide controls.
final class AccessTests: XCTestCase {
    func testEachLevelUnlocksExactlyItsRowsOfThePermissionTable() {
        let none = AccessLevel.none
        XCTAssertFalse(none.canView || none.canContribute || none.canManage || none.isAdmin)

        let external = AccessLevel.external
        XCTAssertTrue(external.canView)
        XCTAssertFalse(external.canContribute, "Externals cannot create or edit rooms")

        let member = AccessLevel.member
        XCTAssertTrue(member.canContribute)
        XCTAssertFalse(member.canManage, "Members cannot delete rooms or grant access")

        let responsible = AccessLevel.responsible
        XCTAssertTrue(responsible.canManage)
        XCTAssertFalse(responsible.isAdmin, "Only admins hand over a project")

        XCTAssertTrue(AccessLevel.admin.canManage && AccessLevel.admin.isAdmin)
    }

    func testUnknownServerLevelGivesNoRights() {
        XCTAssertEqual(AccessLevel(serverValue: 7), AccessLevel.none)
        XCTAssertEqual(AccessLevel(serverValue: -1), AccessLevel.none)
        XCTAssertEqual(AccessLevel(serverValue: 2), .member)
    }

    /// A `rooms` row of today's hosted design (dimensions, no scan or description, T-029) still decodes; columns the
    /// app no longer uses are ignored and the coordinate system is tied to the room.
    func testDesignRoomRowDecodesWithoutARColumns() throws {
        let id = UUID()
        let row = Data(
            """
            {"id":"\(id)","house_id":"\(UUID())","project_id":"\(UUID())","name":"Kitchen","height":2.5,
             "length":4,"width":3.5,"area":14,"status":"in_progress","responsible_id":"\(UUID())",
             "created_by":"\(UUID())","created_by_org":null,"created_at":"2026-11-27T12:00:00Z"}
            """.utf8)
        let room = try JSONDecoder().decode(Room.self, from: row)
        XCTAssertEqual(room.description, "")
        XCTAssertNil(room.map_path)
        XCTAssertEqual(room.coordinate_id, id, "Without a stored coordinate system the room id stays stable")
        XCTAssertNoThrow(try room.validate())
    }

    func testScopeListsOnlyGrantsMadeExactlyThere() {
        let project = Project(name: "Site")
        let house = House(project_id: project.id, name: "House A")
        func grant(house: UUID?, room: UUID?) -> AccessGrant {
            AccessGrant(
                id: UUID(), user_id: UUID(), role: .member, project_id: project.id, house_id: house, room_id: room,
                user: nil)
        }
        let onProject = grant(house: nil, room: nil)
        let onHouse = grant(house: house.id, room: nil)
        XCTAssertTrue(AccessScope.project(project).contains(onProject))
        XCTAssertFalse(AccessScope.project(project).contains(onHouse))
        XCTAssertTrue(AccessScope.house(project, house).contains(onHouse))
    }
}
