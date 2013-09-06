Cordova-inAppPurchase-Plugin
============================

Use this cordova plugin to do inApp purchases.

Add
```xml
<plugin name="ARInAppPurchase" value="InAppPurchasePlugin" onload="true"/>
```
To config.xml to register the plugin with cordova.

To start a purchase via JS
```javascript
window.cordova.exec successCallback, fallCallback, 'ARInAppPurchase', 'purchase', [{productIdentifier: "YOUR Prodct ID"}];
```

If your JS calls an api to update a user then on the success or fail call
```javascript
window.cordova.exec successCallback, fallCallback, 'ARInAppPurchase', 'finish', [{transactionIdentifier: "YOUR transID"}];
// OR on Fail
window.cordova.exec successCallback, fallCallback, 'ARInAppPurchase', 'failed', [{transactionIdentifier: "YOUR transID"}];

```
If using an API it's good to call these methods because they will Finish the transaction when you have updated the user record.
If your app unlocks features via native code then do this in the PuchaseComplete method and finish the transaction there

To connect a restore button for inAppPurchases do
```javascript
window.cordova.exec successCallback, fallCallback, 'ARInAppPurchase', 'restore', [{}];
```
This will return an array of products to the successCallback

Cordova inAppPurchase Plugin
