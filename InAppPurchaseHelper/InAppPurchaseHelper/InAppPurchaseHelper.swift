//
//  InAppPurchaseHelper.swift
//  InAppPurchaseHelper
//
//  Created by Pradeep on 7/31/19.
//  Copyright © 2019 iOSBucket. All rights reserved.
//

import Foundation
import StoreKit

struct Product {
    var price: String?
    var duration: String?
    var durationPeriod: UInt?
    var identifier: String?
    init(price: String?, duration: String?, durationPeriod: UInt?, identifier: String?) {
        self.price = price
        self.duration = duration
        self.durationPeriod = durationPeriod
        self.identifier = identifier
    }
}

struct Result {
    var isSuccess: Bool?
    var message: String?
    init(isSuccess: Bool?, message: String?) {
        self.isSuccess = isSuccess
        self.message = message
    }
}


enum Environment {
    case production
    case sandbox
}

class InAppPurchaseHelper: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    
    static let sharedInstance = InAppPurchaseHelper()
    var productIdentifier: String?
    var restoredProducts: Array<Any>?
    var callbackProducts: ([Product]) -> Void? = {
        responseDic  in
    }
    var callback: (Result) -> Void? = {
        responseDic  in
    }
    var isForPurchase = false
    var callBackResult: NSDictionary?
    var environment: Environment = .sandbox
    
    // Custom Methods
    func requestForProduct(productID: String, callback: @escaping ((Result)->(Void))) {
        self.callback = callback
        isForPurchase = true
        productIdentifier = productID
        let transactions = SKPaymentQueue.default().transactions
        for transaction in transactions {
            SKPaymentQueue.default().finishTransaction(transaction)
        }
        if SKPaymentQueue.canMakePayments() {
            let arrayProducts: Set<String> = [productID]
            let productRequest = SKProductsRequest.init(productIdentifiers: arrayProducts)
            productRequest.delegate = self
            productRequest.start()
        } else {
            let result = Result(isSuccess: false, message: "You are restricted to purchase.")
            self.callback(result)
        }
    }
    
    func requestForProductsPrices(productIDs: [String], callback: @escaping (([Product])->(Void))) {
        self.callbackProducts = callback
        isForPurchase = false
        let transactions = SKPaymentQueue.default().transactions
        for transaction in transactions {
            SKPaymentQueue.default().finishTransaction(transaction)
        }
        if SKPaymentQueue.canMakePayments() {
            let productRequest = SKProductsRequest.init(productIdentifiers: Set(productIDs))
            productRequest.delegate = self
            productRequest.start()
        } else {
            self.callbackProducts([])
        }
    }
    
    func restoreCompletedTransactions(callback: @escaping ((Result)->(Void))) {
        self.callback = callback
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    
    // SKProductRequest Delegate Methods
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let products = response.products
        if products.count > 0 {
            var isExists = false
            var productsArray = [Product]()
            for product in products {
                print("  Available %@ - %@ - %@ - %@", product.productIdentifier, product.localizedTitle, product.localizedDescription, product.price);
                if isForPurchase {
                    if product.productIdentifier == productIdentifier {
                        isExists = true
                        self.purchaseProduct(product: product)
                        break
                    }
                } else {
                    let numberFormatter = NumberFormatter()
                    numberFormatter.locale = product.priceLocale
                    numberFormatter.numberStyle = NumberFormatter.Style.currency
                    let localPrice = numberFormatter.string(from: product.price)

                    if #available(iOS 11.2, *) {
                        guard let duration = product.subscriptionPeriod?.numberOfUnits, let durationPeriod = product.subscriptionPeriod?.unit.rawValue else {
                            return
                        }
                        let product = Product(price: localPrice, duration: "\(duration)", durationPeriod: durationPeriod, identifier: product.productIdentifier)
                        productsArray.append(product)
                    } else {
                        let product = Product(price: localPrice, duration: "", durationPeriod: 0, identifier: product.productIdentifier)
                        productsArray.append(product)
                    }
                }
            }
            if isForPurchase {
                if (!isExists)
                {
                    let result = Result(isSuccess: false, message: "No product available.")
                    self.callback(result)
                }
            } else {
                callbackProducts(productsArray)
            }
        }
        else
        {
            if isForPurchase {
                let result = Result(isSuccess: false, message: "No product available.")
                self.callback(result)
                
            } else {
                callbackProducts([])
            }
        }
        
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Error!",error)
        let result = Result(isSuccess: false, message: error.localizedDescription)
        self.callback(result)
    }
    
    //SKTransaction Observer Delegate Methods
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                self.verifyReceipt { (success) in
                    if success {
                        self.completeTransaction(transaction)
                    } else {
                        self.failedVerifyReceipt(transaction)
                    }
                }
            case .failed:
                self.failedTransaction(transaction)
            case .restored:
                self.restoreTransaction(transaction)
            default:
                break
            }
        }
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        self.restoredProducts = Array()
        for transaction in queue.transactions {
            let productId = transaction.payment.productIdentifier
            self.restoredProducts?.append(productId)
        }
    }
    
    // Private Methods
    
    /**
     *  This function is used to purchase a product.
     *
     *  @param product SKProduct object which got from the SKProductRequest Delegate
     */
    func purchaseProduct(product: SKProduct) {
        if SKPaymentQueue.canMakePayments() {
            let payment = SKPayment.init(product: product)
            SKPaymentQueue.default().add(payment)
            SKPaymentQueue.default().add(self)
        } else {
            let result = Result(isSuccess: false, message: "You are not authorized to purchase from AppStore.")
            self.callback(result)
        }
    }
    
    /**
     *  This method is called when transaction will be completed.
     *
     *  @param transaction SKPaymentTransaction state
     */
    
    func completeTransaction(_ transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
        let result = Result(isSuccess: true, message: "Purchase completed.")
        self.callback(result)
    }
    
    /**
     *  This method is called when transaction will not be completed successfully.
     *
     *  @param transaction SKPaymentTransaction state
     */
    func failedTransaction(_ transaction: SKPaymentTransaction) {
        if let error = transaction.error as NSError?, error.code != SKError.paymentCancelled.rawValue {
            let result = Result(isSuccess: false, message: "Transaction Failed!")
            self.callback(result)
        } else {
            let result = Result(isSuccess: false, message: "Transaction Cancelled")
            self.callback(result)
        }
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    /**
     *  This method is called when receipt verification will be failed.
     *
     *  @param transaction SKPaymentTransaction state
     */
    func failedVerifyReceipt(_ transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
        let result = Result(isSuccess: false, message: "Verify receipt failed.")
        self.callback(result)
    }
    
    /**
     *  This method is called when transaction will restore successfully.
     *
     *  @param transaction SKPaymentTransaction state
     */
    func restoreTransaction(_ transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
        let result = Result(isSuccess: true, message: "Transaction restore successfully.")
        self.callback(result)
    }
    
    /**
     *  This method is used to verify the receipt
     *
     *  @return Yes if receipt is valid otherwise return No
     */
    func verifyReceipt(completionHandler: @escaping ((_ success: Bool) -> Void)) {
        guard let receiptFileURL = Bundle.main.appStoreReceiptURL, let receiptData = NSData(contentsOf: receiptFileURL) else {
            completionHandler(false)
            return
        }
        let recieptString = receiptData.base64EncodedString(options: [])
        
        let jsonDict = ["receipt-data": recieptString, "password": "01a097aa9ca048ff8b51512dd593b384"]
        
        do {
            let requestData = try JSONSerialization.data(withJSONObject: jsonDict, options: JSONSerialization.WritingOptions())
            var urlString: String = ""
            //TODO--- APPSTORE
            switch environment {
            case .production:
                urlString = "https://buy.itunes.apple.com/verifyReceipt"
            case .sandbox:
                urlString = "https://sandbox.itunes.apple.com/verifyReceipt"
            }
            
            guard let url = URL.init(string: urlString) else {
                completionHandler(false)
                return
            }
            
            var request = URLRequest.init(url: url, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: 60.0)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("\(requestData.count)", forHTTPHeaderField: "Content-Length")
            request.httpBody = requestData as Data
            let task = URLSession.shared.dataTask(with: request) { urlData, response, error in
                do  {
                    guard let receivedData = urlData, let jsonResponse = try JSONSerialization.jsonObject(with: receivedData, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: Any] else {
                        completionHandler(false)
                        return
                    }
                    
                    guard let status = jsonResponse["status"] as? Int else {
                        completionHandler(false)
                        return
                    }
                    if status == 0 {
                        guard let tempDicReceipt = jsonResponse["receipt"] else {
                            completionHandler(false)
                            return
                        }
                        print("Receipt Information - %@ ", tempDicReceipt)
                        completionHandler(true)
                    } else {
                        completionHandler(false)
                    }
                } catch let error {
                    debugPrint(error.localizedDescription)
                    completionHandler(false)
                }
            }
            task.resume()
        } catch let error {
            debugPrint(error.localizedDescription)
            completionHandler(false)
        }
    }
}
