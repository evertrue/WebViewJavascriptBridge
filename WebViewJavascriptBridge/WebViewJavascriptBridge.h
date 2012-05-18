#import <UIKit/UIKit.h>
#import "WebViewBridge.h"
#import "WebViewJavascriptBridgeDelegate.h"

@interface WebViewJavascriptBridge : WebViewBridge <UIWebViewDelegate> {
    id <WebViewJavascriptBridgeDelegate> _delegate;
}

- (id) initWithDelegate:(id <WebViewJavascriptBridgeDelegate>)delegate;


/* Create a javascript bridge with the given delegate for handling messages */
+ (id)javascriptBridgeWithDelegate:(id <WebViewJavascriptBridgeDelegate>)delegate;

/* Send a message to the web view. Make sure that this javascript bridge is the delegate
 * of the webview before calling this method (see ExampleAppDelegate.m) */
- (void)sendMessage:(NSString *)message toWebView:(UIWebView *)webView;

/* Reset startup messaging queue */
- (void)resetQueue;

@end
