//
//  InAppPurchasePlugin.m
//  MFR
//
//  Created by Alex Reynolds on 9/5/13.
//  Copyright (c) 2013 Dulcetta. All rights reserved.
//

#import "InAppPurchasePlugin.h"
#import "NSObject+SBJSON.h"


static NSString * TRANSACTION_ID = @"transactionIdentifier";

@implementation InAppPurchasePlugin

- (CDVPlugin*)initWithWebView:(UIWebView*)theWebView {
    self = [super initWithWebView:theWebView];
    if (self) {
        NSLog(@"INIT IAP PLUGIN");
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        _requests = [[NSMutableDictionary alloc] init];

    }
    return self;
}
-(void)sendOkCallbackForRequest:(NSString *)name withData:(NSDictionary *)data
{
    NSString *matchingCallbackID = [_requests valueForKey:name];
    if (matchingCallbackID){
        [_requests removeObjectForKey:name];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:data];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:matchingCallbackID];
        
    }
}
-(void)sendErrorCallbackForRequest:(NSString *)name withData:(NSDictionary *)data
{    NSString *matchingCallbackID = [_requests valueForKey:name];
    if (matchingCallbackID){
        [_requests removeObjectForKey:name];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:matchingCallbackID];
    }
    
}

#pragma mark - Event Methods
- (void) purchase:(CDVInvokedUrlCommand*)command {
    NSLog(@"Start purchase event");
    NSAssert(command.arguments.count == 1, @"Expected 1 arguments for command %@", command);
    NSString*       name = @"purchase";
    NSDictionary*   data = [command.arguments objectAtIndex:0];
    
    [_requests setObject:command.callbackId forKey:name];
    
    if(data == nil){
        [self sendErrorCallbackForRequest:name withData:nil];
        return;
    }
    
    [self clearTransactionQueue];
    
    // build the iTunes store ID with the productIdentifier
    NSString *pid;
    
    // Replace dulcetta with your company name
    pid = [NSString stringWithFormat:@"com.dulcetta.%@", [data objectForKey:@"productIdentifier"]];
    
    if ([SKPaymentQueue canMakePayments]) {
        
        NSLog(@"IN-APP PURCHASES ENABLED : PID: %@", pid);
        
        _productId = pid;
        [self requestProductInfo:pid];
        
    } else {
        
        // show an error indicating purchases are disabled
        NSLog(@"IN-APP PURCHASES ARE DISABLED");
        [self sendErrorCallbackForRequest:name withData:nil];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"In-App Purchases Disabled"
                                                        message:@"In-App Purchases have been disabled for this device."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}
- (void) finish:(CDVInvokedUrlCommand*)command {
    NSLog(@"Complete trans event");
    NSAssert(command.arguments.count == 1, @"Expected 1 arguments for command %@", command);
    NSString*       name = @"finish";
    
    [_requests setObject:command.callbackId forKey:name];
    NSArray *transactions = [[SKPaymentQueue defaultQueue] transactions];
    
    for(SKPaymentTransaction *trans in transactions ){
        if(trans.transactionState == SKPaymentTransactionStatePurchased){
                [[SKPaymentQueue defaultQueue] finishTransaction: trans];
            NSLog(@"FINISH PURCHASE")

        }
    }
    [self sendOkCallbackForRequest:name withData:@{}];
    

}

-(void) failed:(CDVInvokedUrlCommand*)command {
    // Do something we failed to add the purchase to our server
}


- (void) restore:(CDVInvokedUrlCommand*)command {
    focusLNSLogog(@"restore event");
    NSAssert(command.arguments.count == 1, @"Expected 1 arguments for command %@", command);
    NSString*       name = @"restore";
    
    [_requests setObject:command.callbackId forKey:name];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    
    
    
}

// Transmits the product identifier to Apple to verify that it is still available for purchase
// - fires the productsRequest:didReceiveResponse method when complete
- (void)requestProductInfo:(NSString *)productIdentifier {
    
    NSLog(@"REQUEST PRODUCT INFO: %@", productIdentifier);
    
    // submit the pid to app store
    NSSet *product = [NSSet setWithObject:productIdentifier];
    _request = [[SKProductsRequest alloc] initWithProductIdentifiers:product];
    _request.delegate = self;
    [_request start];
    
}

// finishes any unfinished transactions - used when starting a new purchase
- (void)clearTransactionQueue {
    NSLog(@"CLEAR THE QUEUEU");
    NSArray *transactions = [[SKPaymentQueue defaultQueue] transactions];
    for(SKPaymentTransaction *transaction in transactions){
        NSLog(@"transaction %i", transaction.transactionState);
        if (transaction.transactionState != SKPaymentTransactionStatePurchasing) {
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        }
    }
    
}

#pragma mark - Request Delegate Methods
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Cannot connect to iTunes Store"
                                                    message:@"We are unable to connect to the iTunes Store to make your purchase.  Please try again later."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil, nil];
    [alert show];
}

#pragma mark - Products Request Delegate Methods

// Parse the response from the app store to see if the specified product is still available
// - if the product is available, continue with the purchase process, otherwise notify the customer
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    
    NSLog(@"PRODUCTS REQUEST RESPONSE RECEIVED");
    
    NSArray *products = response.products;
    
    // we are only sending the one ID at a time so at most one value should be returned
    if ([products count] == 0 || (nil != _productId && [response.invalidProductIdentifiers containsObject:_productId])) {
        
        // the product is not for sale anymore, so notify the customer
        NSLog(@"INVALID PRODUCTS: %@", response.invalidProductIdentifiers);
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subscription Not Available"
                                                        message:@"The subscription you requested is not currently available for purchase."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        
    } else {
        
        SKProduct *prodInfo = [products objectAtIndex:0];
        
        NSLog(@"Product title: %@" , prodInfo.localizedTitle);
        NSLog(@"Product description: %@" , prodInfo.localizedDescription);
        NSLog(@"Product price: %@" , prodInfo.price);
        NSLog(@"Product id: %@" , prodInfo.productIdentifier);
        
        // proceed with the transaction by submitting the product for payment
        [[SKPaymentQueue defaultQueue] addPayment:[SKPayment paymentWithProduct:prodInfo]];
    }
}

#pragma mark - Payment Queue Delegate Methods

// handle progress notifications from SKPaymentQueue transactions
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    
    for (SKPaymentTransaction *transaction in transactions) {
        
        NSLog(@"IAP TRANSACTION [state]:%d [receipt]:%@ [id]:%@", transaction.transactionState, transaction.transactionReceipt, transaction.transactionIdentifier );
        
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self purchaseSuccess:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self purchaseFailed:transaction];
                break;
            case SKPaymentTransactionStatePurchasing:
                break;
            case SKPaymentTransactionStateRestored:
            	// Don't do anything since we user the RestoreComplete delegate method
                NSLog(@"restored");
                break;
            default:
                break;
        }
    }
}

// @desc utility method to convert the receipt data into a base64 string
- (NSString *)Base64EncodedStringFromData:(NSData *)data {
    
    NSUInteger length = [data length];
    NSMutableData *mutableData = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    
    uint8_t *input = (uint8_t *)[data bytes];
    uint8_t *output = (uint8_t *)[mutableData mutableBytes];
    
    for (NSUInteger i = 0; i < length; i += 3) {
        NSUInteger value = 0;
        for (NSUInteger j = i; j < (i + 3); j++) {
            value <<= 8;
            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }
        
        static uint8_t const kAFBase64EncodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        
        NSUInteger idx = (i / 3) * 4;
        output[idx + 0] = kAFBase64EncodingTable[(value >> 18) & 0x3F];
        output[idx + 1] = kAFBase64EncodingTable[(value >> 12) & 0x3F];
        output[idx + 2] = (i + 1) < length ? kAFBase64EncodingTable[(value >> 6)  & 0x3F] : '=';
        output[idx + 3] = (i + 2) < length ? kAFBase64EncodingTable[(value >> 0)  & 0x3F] : '=';
    }
    
    return [[NSString alloc] initWithData:mutableData encoding:NSASCIIStringEncoding];
}

// when the purchase is successful, send callback to JS. Optionally if it were native functionality you can unlock content here
- (void)purchaseSuccess:(SKPaymentTransaction *)transaction {
    
    if(transaction.transactionReceipt == nil){
        [self sendErrorCallbackForRequest:@"purchase" withData:@{@"error": @"No reciept found"}];
        return;
    }
    
    
    NSString *receipt = [self Base64EncodedStringFromData:transaction.transactionReceipt];

    NSDictionary *transactionInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
                                     @"itunes", @"method",
                                     receipt, @"receipt",
                                     transaction.transactionIdentifier, TRANSACTION_ID,
                                     nil];
    
    NSLog(@"IAP SUCCESS - INFO: %@", transactionInfo);
    
    // send the notification to the plugin
    if( [_requests objectForKey:@"purchase"]){
        [self sendOkCallbackForRequest:@"purchase" withData:transactionInfo];
    } else {
        
        NSString* encodedData   = [transactionInfo JSONRepresentation];
        NSString* javascript    = [NSString stringWithFormat:@"MFRAppPlatform.recvInAppPurchase('%@', %@);", @"purchaseSuccess", encodedData];
        [self writeJavascript:javascript];
    }

    
}

// @desc when the purchase fails, only notify the user if it's not cancel-related
// 
- (void)purchaseFailed:(SKPaymentTransaction *)transaction {
    
    NSLog(@"FAIL: %@", transaction.error);
    
        // pass along the error message
    [self sendErrorCallbackForRequest:@"purchase" withData:@{@"error":transaction.error.localizedDescription, @"errorCode":[NSNumber numberWithInt:transaction.error.code]}];

    
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    
}
// @desc after a restore we need to take the transactions and send the data to our JS layer
//
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSLog(@"%@",queue );
    NSLog(@"Restored Transactions are once again in Queue for purchasing %@",[queue transactions]);
    
    NSMutableArray *transactions = [[NSMutableArray alloc] init];
    NSLog(@"received restored transactions: %i", queue.transactions.count);

    for (SKPaymentTransaction *transaction in queue.transactions) {
        NSString *productID = transaction.payment.productIdentifier;
        
        NSString *receipt = [self Base64EncodedStringFromData:transaction.transactionReceipt];
        
        NSDictionary *transactionInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
                                         @"itunes", @"method",
                                         receipt, @"receipt",
                                         transaction.transactionIdentifier, TRANSACTION_ID,
                                         productID, @"productIdentifyer"
                                         nil];
        [transactions addObject:transactionInfo];
        // here put an if/then statement to write files based on previously purchased items
        // example if ([productID isEqualToString: @"youruniqueproductidentifier]){write files} else { nslog sorry}
    }
    [self sendOkCallbackForRequest:@"restore" withData:@{@"transactions" : transactions}];
}

@end
