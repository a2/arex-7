import Foundation

protocol ErrorRepresentable: Printable {
    typealias ErrorCode: SignedIntegerType

    static var domain: String { get }
    var code: ErrorCode { get }
    var failureReason: String? { get }
}

func error<T: ErrorRepresentable>(#code: T, underlying: NSError? = nil) -> NSError {
    var userInfo = [NSObject: AnyObject]()
    userInfo[NSLocalizedDescriptionKey] = code.description
    
    if let reason = code.failureReason {
        userInfo[NSLocalizedFailureReasonErrorKey] = reason
    }
    
    if let underlying = underlying {
        userInfo[NSUnderlyingErrorKey] = underlying
    }
    
    return NSError(domain: T.domain, code: numericCast(code.code), userInfo: userInfo)
}
