import Foundation

protocol APIResultEnvelope {
    var status: Int? { get }
    var success: Bool? { get }
}
