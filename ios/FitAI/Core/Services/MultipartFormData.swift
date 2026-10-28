import Foundation

/// Small multipart encoder shared by single- and multi-image uploads.
///
/// Keeping boundary/header assembly here means upload endpoints only describe
/// fields and files, not byte-level CRLF rules.
struct MultipartFormData {
    let boundary: String
    private(set) var body = Data()

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func appendField(name: String, value: String) {
        body.append(contentsOf: Data("--\(boundary)\r\n".utf8))
        body.append(contentsOf: Data(
            "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8
        ))
        body.append(contentsOf: Data(value.utf8))
        body.append(contentsOf: Data("\r\n".utf8))
    }

    mutating func appendFile(
        _ data: Data,
        field: String,
        filename: String,
        mimeType: String = "image/jpeg"
    ) {
        body.append(contentsOf: Data("--\(boundary)\r\n".utf8))
        body.append(contentsOf: Data(
            "Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(filename)\"\r\n".utf8
        ))
        body.append(contentsOf: Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(contentsOf: Data("\r\n".utf8))
    }

    func finalized() -> Data {
        var result = body
        result.append(contentsOf: Data("--\(boundary)--\r\n".utf8))
        return result
    }
}
