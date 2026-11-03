import XCTest
@testable import FitAI

final class CoachChatPolicyTests: XCTestCase {
    func testFreeUsersAlwaysUseServerAgent() {
        XCTAssertEqual(
            CoachChatPolicy.transport(hasPro: false, remoteEnabled: true),
            .agent
        )
        XCTAssertEqual(
            CoachChatPolicy.transport(hasPro: false, remoteEnabled: false),
            .agent
        )
    }

    func testOnlyProUsersWithRemoteOffUseLocalReplies() {
        XCTAssertEqual(
            CoachChatPolicy.transport(hasPro: true, remoteEnabled: true),
            .agent
        )
        XCTAssertEqual(
            CoachChatPolicy.transport(hasPro: true, remoteEnabled: false),
            .local
        )
    }

    func testQuotaCardShowsOnlyForFreeUsersWithoutQuota() {
        XCTAssertTrue(
            CoachChatPolicy.shouldShowQuotaCard(
                hasPro: false,
                remaining: 0,
                exhausted: false
            )
        )
        XCTAssertTrue(
            CoachChatPolicy.shouldShowQuotaCard(
                hasPro: false,
                remaining: 2,
                exhausted: true
            )
        )
        XCTAssertFalse(
            CoachChatPolicy.shouldShowQuotaCard(
                hasPro: false,
                remaining: 2,
                exhausted: false
            )
        )
        XCTAssertFalse(
            CoachChatPolicy.shouldShowQuotaCard(
                hasPro: false,
                remaining: nil,
                exhausted: false
            )
        )
        XCTAssertFalse(
            CoachChatPolicy.shouldShowQuotaCard(
                hasPro: true,
                remaining: 0,
                exhausted: true
            )
        )
    }
}
