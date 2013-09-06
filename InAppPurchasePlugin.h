//
//  InAppPurchasePlugin.h
//  MFR
//
//  Created by Alex Reynolds on 9/5/13.
//  Copyright (c) 2013 Dulcetta. All rights reserved.
//

#import <Cordova/CDVPlugin.h>
#import <StoreKit/StoreKit.h>


@interface InAppPurchasePlugin : CDVPlugin<SKProductsRequestDelegate, SKPaymentTransactionObserver, SKRequestDelegate>{
    @private
    NSMutableDictionary *_requests;
    SKProductsRequest *_request;
    NSString *_productId;
}

@end
