//
//  Revenue.swift
//
//
//  Created by Marvin Liu on 12/8/22.
//

import Foundation

public class Revenue {
    enum Property: String {
        case REVENUE_PRODUCT_ID = "$productId"
        case REVENUE_QUANTITY = "$quantity"
        case REVENUE_PRICE = "$price"
        case REVENUE_TYPE = "$revenueType"
        case REVENUE_RECEIPT = "$receipt"
        case REVENUE_RECEIPT_SIG = "$receiptSig"
        case REVENUE = "$revenue"
    }

    private var _productId: String?
    var productId: String? {
        set(value) {
            if value != nil && !value!.isEmpty {
                _productId = value
            }
        }
        get {
            return _productId
        }
    }

    private var _quantity: Int = 1
    var quantity: Int {
        set(value) {
            if value > 0 {
                _quantity = value
            }
        }
        get {
            return _quantity
        }
    }

    private var _price: Double?
    var price: Double? {
        set(value) {
            if value != nil {
                _price = value
            }
        }
        get {
            return _price
        }
    }

    private var _revenue: Double?
    var revenue: Double? {
        set(value) {
            if value != nil {
                _revenue = value
            }
        }
        get {
            return _revenue
        }
    }

    var revenueType: String?

    var receipt: String?

    var receiptSig: String?

    var properties: [String: Any?]?

    func setReceipt(receipt: String, receiptSignature: String) -> Revenue {
        self.receipt = receipt
        self.receiptSig = receiptSignature
        return self
    }
    
    func isValid() -> Bool {
        return price == nil
    }
    
    func toRevenueEvent() -> RevenueEvent {
        let event = RevenueEvent()
        var eventProperties = properties ?? [String: Any?]()
        if productId != nil {
            eventProperties[Property.REVENUE_PRODUCT_ID.rawValue] = productId
        }
        eventProperties[Property.REVENUE_QUANTITY.rawValue] = quantity
        if price != nil {
            eventProperties[Property.REVENUE_PRICE.rawValue] = price
        }
        if revenueType != nil {
            eventProperties[Property.REVENUE_TYPE.rawValue] = price
        }
        if receipt != nil {
            eventProperties[Property.REVENUE_RECEIPT.rawValue] = receipt
        }
        if receiptSig != nil {
            eventProperties[Property.REVENUE_RECEIPT_SIG.rawValue] = receiptSig
        }
        if revenue != nil {
            eventProperties[Property.REVENUE.rawValue] = revenue
        }
        event.eventProperties = eventProperties
        return event
    }
}
