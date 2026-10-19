import XCTest
@testable import YetdaCore

final class SecretDetectorTests: XCTestCase {
    private func secrets(_ text: String) -> [String] {
        SecretDetector.secretRanges(in: text).map { String(text[$0]) }
    }

    func test_known_token_formats() {
        let tokens = [
            "sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWx",
            "sk-proj-AbCdEfGhIjKlMnOpQrStUvWx1234",
            "ghp_AbCdEfGhIjKlMnOpQrStUvWxYz0123456789",
            "AKIAIOSFODNN7EXAMPLE",
            "xoxb-1234567890-abcdefghij",
            "AIzaSyA1234567890abcdefghijklmnopqrstuv",
            "sk_live_" + "4eC39HqLyjWDarjtT1zdp7dc",
            "glpat-AbCdEfGhIjKlMnOpQrSt",
            "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.dozjgNryP4J3jVmNHl0w5N",
        ]
        for token in tokens {
            XCTAssertEqual(secrets("key \(token) here"), [token], token)
        }
    }

    func test_assignment_hides_only_the_value() {
        XCTAssertEqual(secrets("DATABASE_PASSWORD=hunter2hunter2"), ["hunter2hunter2"])
        XCTAssertEqual(secrets(#"api_key: "abc123def456""#), ["abc123def456"])
        XCTAssertEqual(secrets("Token = Zx9Qw8Er7Ty6"), ["Zx9Qw8Er7Ty6"])
    }

    func test_key_names_need_a_random_value() {
        XCTAssertEqual(secrets("SESSION_KEY: Zq8Lm2Xv9Rt4Wp7Ks3Hn6Jd1"), ["Zq8Lm2Xv9Rt4Wp7Ks3Hn6Jd1"])
        XCTAssertEqual(secrets("primary key: user_id"), [])
        XCTAssertEqual(secrets("sort key = createdAt"), [])
    }

    func test_ocr_look_alikes_are_matched_and_ranges_map_back() {
        let text = "OPENAI_API_KEY=sk—prоj—Q7wЕrТy8Ui0p9AsDfGh2JkL3Z×CvВn" // Cyrillic о Е Т В, em dashes
        XCTAssertEqual(secrets(text), ["sk—prоj—Q7wЕrТy8Ui0p9AsDfGh2JkL3Z×CvВn"])
    }

    func test_env_assignment_of_a_random_value() {
        XCTAssertEqual(secrets("INTERNAL_SIGNING=Qm9vT3lYcG1Ld2pSa2xNbk9wUXI4"), ["Qm9vT3lYcG1Ld2pSa2xNbk9wUXI4"])
        XCTAssertEqual(secrets("INTERNAL_SIGNING= Qm9vT3lYcG1Ld2pSa2xNbk9wUXI4"), ["Qm9vT3lYcG1Ld2pSa2xNbk9wUXI4"])
        XCTAssertEqual(secrets("NODE_ENV=production"), [])
        XCTAssertEqual(secrets("GIT_SHA=3f2a9c1d8e7b6a5f4e3d"), [])
        XCTAssertEqual(secrets("DATABASE_URL=postgres://app:Sup3rS3cret@db.internal:5432/app"), ["Sup3rS3cret"])
    }

    func test_url_without_credentials_is_left_alone() {
        XCTAssertEqual(secrets("open http://localhost:3000/app"), [])
    }

    func test_connection_string_hides_the_password() {
        XCTAssertEqual(secrets("postgres://app:s3cretPass@db.internal:5432/app"), ["s3cretPass"])
    }

    func test_card_numbers_need_a_valid_checksum() {
        XCTAssertEqual(secrets("card 4242 4242 4242 4242 ok"), ["4242 4242 4242 4242"])
        XCTAssertEqual(secrets("order 1234 5678 9012 3456"), [])
        XCTAssertEqual(secrets("order 9000000000000006"), []) // passes Luhn, no card prefix
        XCTAssertEqual(secrets("amex 3782 822463 10005"), ["3782 822463 10005"])
    }

    func test_bearer_token() {
        XCTAssertEqual(secrets("Authorization: Bearer abc123DEF456ghi789JKL"), ["abc123DEF456ghi789JKL"])
    }

    func test_placeholders_in_secret_fields_are_left_alone() {
        XCTAssertEqual(secrets("token=undefined"), [])
        XCTAssertEqual(secrets("password: required"), [])
        XCTAssertEqual(secrets("secret = ********"), [])
        XCTAssertEqual(secrets("password: correcthorsebattery"), ["correcthorsebattery"])
        XCTAssertEqual(secrets("password: (none)"), [])
        XCTAssertEqual(secrets("token: string;"), [])
        XCTAssertEqual(secrets("api_key=<your-key>"), [])
        XCTAssertEqual(secrets("API_TOKEN=$GITHUB_TOKEN"), [])
        XCTAssertEqual(secrets("password: {{db_password}}"), [])
    }

    /// Real passwords are often plain lowercase words.
    func test_lowercase_word_passwords_are_hidden() {
        XCTAssertEqual(secrets("PGPASSWORD=postgres"), ["postgres"])
        XCTAssertEqual(secrets("password: letmein"), ["letmein"])
        XCTAssertEqual(secrets("DB_PASSWORD=supersecret"), ["supersecret"])
    }

    /// Everyday developer text that must never be hidden.
    func test_no_false_positives_on_common_dev_text() {
        let lines = [
            "id: 550e8400-e29b-41d4-a716-446655440000",
            "TRACE_ID: Ab3xK9mPq2Lw8Rt5Yz1Vc7Nd",
            "request_id=req_01HZX3K9M2P7Q8R4S5T6V",
            "GET https://api.example.com/v1/users?page=2&limit=50 200 OK",
            "Error: ENOENT: no such file or directory, open '/Users/me/app/config.json'",
            "at Object.<anonymous> (/app/src/components/CheckoutButton.tsx:42:17)",
            "NODE_ENV=production PORT=3000 LOG_LEVEL=debug",
            "commit 3f2a9c1d8e7b6a5f4e3d2c1b0a9f8e7d6c5b4a39",
            "sha256:9b2c4f1e8a7d6c5b4a39f8e7d6c5b4a393f2a9c1d8e7b6a5f4e3d2c1b0a9f8e7",
            "Order #1234 5678 9012 3456 shipped",
            "primary key: user_id, sort key: createdAt",
            "keyboard shortcut: ⌘⇧2",
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ",
            "phone +82 10 1234 5678",
            "결제 버튼을 눌렀는데 에러가 납니다",
        ]
        for line in lines {
            XCTAssertEqual(secrets(line), [], line)
        }
    }

    func test_ordinary_text_is_left_alone() {
        XCTAssertEqual(secrets("TypeError: Cannot read properties of undefined (reading 'map')"), [])
        XCTAssertEqual(secrets("commit 3f2a9c1d8e7b6a5f4e3d2c1b0a9f8e7d6c5b4a39"), [])
        XCTAssertEqual(secrets("password field is required"), [])
    }

    func test_candidates_skip_hashes_paths_and_known_secrets() {
        let text = """
        id 3f2a9c1d8e7b6a5f4e3d2c1b0a9f8e7d6c5b4a39 \
        path src/components/CheckoutButton2Form.tsx \
        key ghp_AbCdEfGhIjKlMnOpQrStUvWxYz0123456789 \
        weird Qm9vT3lYcG1Ld2pSa2xNbk9wUXI4
        """
        let found = SecretDetector.candidates(in: text).map { String(text[$0]) }
        XCTAssertEqual(found, ["Qm9vT3lYcG1Ld2pSa2xNbk9wUXI4"])
    }

    func test_redact_replaces_secrets_in_text() {
        XCTAssertEqual(
            SecretDetector.redact("export OPENAI_API_KEY=sk-proj-AbCdEfGhIjKlMnOpQrStUvWx1234"),
            "export OPENAI_API_KEY=[REDACTED]"
        )
    }

    func test_redact_with_explicit_overlapping_ranges() {
        let text = "a secret here"
        let start = text.index(text.startIndex, offsetBy: 2)
        let mid = text.index(start, offsetBy: 3)
        let end = text.index(start, offsetBy: 6)
        XCTAssertEqual(SecretDetector.redact(text, ranges: [start..<mid, start..<end]), "a [REDACTED] here")
        XCTAssertEqual(SecretDetector.redact(text, ranges: []), text)
    }

    func test_luhn() {
        XCTAssertTrue(SecretDetector.passesLuhn("4242424242424242"))
        XCTAssertFalse(SecretDetector.passesLuhn("4242424242424241"))
    }
}
