import PassKit

@objc(ApplePay)
class ApplePay: UIViewController {
    private var rootViewController: UIViewController = UIApplication.shared.keyWindow!.rootViewController!
    private var request: PKPaymentRequest = PKPaymentRequest()
    private var resolve: RCTPromiseResolveBlock?
    private var didRespond: Bool = false
    private var paymentNetworks: [PKPaymentNetwork]?


    @objc(invokeApplePay:details:)
    private func invokeApplePay(method: NSDictionary, details: NSDictionary) -> Void {
        self.didRespond = false
        self.paymentNetworks = method["supportedNetworks"] as? [PKPaymentNetwork]
        let total = details["total"] as! NSDictionary
        let paymentItem = PKPaymentSummaryItem.init(label: total["label"] as! String, amount: NSDecimalNumber(value: total["amount"] as! Double))
        request.currencyCode = method["currencyCode"] as! String
        request.countryCode = method["countryCode"] as! String
        request.merchantIdentifier = method["merchantIdentifier"] as! String
        request.merchantCapabilities = [PKMerchantCapability.capability3DS, PKMerchantCapability.capabilityDebit]
        request.supportedNetworks = self.paymentNetworks!
        request.paymentSummaryItems = [paymentItem]
        
        if #available(iOS 11.0, *) {
            request.supportedCountries = [method["countryCode"] as! String]
            
            request.requiredBillingContactFields = [
                PKContactField.postalAddress,
                PKContactField.name,
            ]
            request.requiredShippingContactFields = [
                PKContactField.phoneNumber,
                PKContactField.emailAddress,
            ]
        }
    }

    @objc(initApplePay:withRejecter:)
    func initApplePay(resolve: @escaping RCTPromiseResolveBlock, reject:RCTPromiseRejectBlock) -> Void {
        self.resolve = resolve
        if let controller = PKPaymentAuthorizationViewController(paymentRequest: request) {
            controller.delegate = self
            DispatchQueue.main.async {
                // find the current top controller
                let topController = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController
                if topController == nil {
                    self.rootViewController.present(controller, animated: true, completion: nil)
                } else {
                    topController!.present(controller, animated: true, completion: nil)
                }
            }
        }
    }
    
    @objc(canMakePayments:withRejecter:)
    func canMakePayments(resolve: RCTPromiseResolveBlock,reject:RCTPromiseRejectBlock) -> Void {
        let merchantCapabilities: PKMerchantCapability = [PKMerchantCapability.capability3DS, PKMerchantCapability.capabilityDebit]
        let supportedNetworks = self.paymentNetworks!
        
        if PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: supportedNetworks, capabilities: merchantCapabilities) {
            resolve(true)
        } else {
            resolve(false)
        }
    }

    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
}

extension ApplePay: PKPaymentAuthorizationViewControllerDelegate {
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {

        if (self.didRespond == false) {
            self.resolve!("{}")
        }
        controller.dismiss(animated: true, completion: nil)
    }

    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        self.didRespond = true

        if #available(iOS 11.0, *) {
            var jsonPaymentResponse = """
            {
                "token": {
                    "paymentData": \(String(decoding: payment.token.paymentData, as: UTF8.self)),
                    "paymentMethod": {
                        "network": "\(payment.token.paymentMethod.network!.rawValue)",
                        "displayName": "\(payment.token.paymentMethod.displayName!)",
                        "type": "debit"
                    },
                    "transactionIdentifier": "\(payment.token.transactionIdentifier)"
                },
                "billingContact": {
                    "givenName": "\(payment.billingContact?.name?.givenName ?? "")",
                    "familyName": "\(payment.billingContact?.name?.familyName ?? "")",
                    "addressLines": \((payment.billingContact?.postalAddress?.street ?? "").components(separatedBy: "\n")),
                    "administrativeArea": "\(payment.billingContact?.postalAddress?.state ?? "")",
                    "country": "\(payment.billingContact?.postalAddress?.country ?? "")",
                    "countryCode": "\(payment.billingContact?.postalAddress?.isoCountryCode ?? "")",
                    "postalCode": "\(payment.billingContact?.postalAddress?.postalCode ?? "")",
                    "subAdministrativeArea": "\(payment.billingContact?.postalAddress?.subAdministrativeArea ?? "")",
                    "subLocality": "\(payment.billingContact?.postalAddress?.city ?? "")",
                    "locality": "\(payment.billingContact?.postalAddress?.city ?? "")"
                },
                "shippingContact": {
                    "givenName": "\(payment.billingContact?.name?.givenName ?? "")",
                    "familyName": "\(payment.billingContact?.name?.familyName ?? "")",
                    "emailAddress": "\(payment.shippingContact?.emailAddress ?? "")",
                    "phoneNumber": "+1\(payment.shippingContact?.phoneNumber?.stringValue ?? "")",
                    "addressLines": \((payment.billingContact?.postalAddress?.street ?? "").components(separatedBy: "\n")),
                    "administrativeArea": "\(payment.billingContact?.postalAddress?.state ?? "")",
                    "country": "\(payment.billingContact?.postalAddress?.country ?? "")",
                    "countryCode": "\(payment.billingContact?.postalAddress?.isoCountryCode ?? "")",
                    "postalCode": "\(payment.billingContact?.postalAddress?.postalCode ?? "")",
                    "subAdministrativeArea": "\(payment.billingContact?.postalAddress?.subAdministrativeArea ?? "")",
                    "subLocality": "\(payment.billingContact?.postalAddress?.city ?? "")",
                    "locality": "\(payment.billingContact?.postalAddress?.city ?? "")"
                }
            }
            """
            jsonPaymentResponse = jsonPaymentResponse.filter({!"\n\t\r".contains($0)})
            self.resolve!(jsonPaymentResponse)
            
            completion(.success)
        } else {
            self.resolve!("Required iOS 11 and above...")
            completion(.failure)
        }
    }
}
