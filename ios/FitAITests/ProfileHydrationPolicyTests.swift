import XCTest
@testable import FitAI

final class ProfileHydrationPolicyTests: XCTestCase {
    func testEmptyLocalNicknameTakesServerNickname() {
        XCTAssertEqual(
            RemoteProfileIdentityPolicy.nickname(
                local: "",
                server: "Mac QA"
            ),
            "Mac QA"
        )
    }

    func testLocalNicknameWinsOverServer() {
        XCTAssertEqual(
            RemoteProfileIdentityPolicy.nickname(
                local: "本地昵称",
                server: "Mac QA"
            ),
            "本地昵称"
        )
    }

    func testWhitespaceLocalNicknameTakesServerNickname() {
        XCTAssertEqual(
            RemoteProfileIdentityPolicy.nickname(
                local: "   ",
                server: "Mac QA"
            ),
            "Mac QA"
        )
    }

    func testServerOnboardedHydratesLocalFlag() {
        XCTAssertTrue(
            RemoteProfileIdentityPolicy.isOnboarded(
                local: false,
                server: true
            )
        )
        XCTAssertFalse(
            RemoteProfileIdentityPolicy.isOnboarded(
                local: false,
                server: false
            )
        )
    }

    func testLocalOnboardedFlagIsNeverClearedByServer() {
        XCTAssertTrue(
            RemoteProfileIdentityPolicy.isOnboarded(
                local: true,
                server: false
            )
        )
    }
}
