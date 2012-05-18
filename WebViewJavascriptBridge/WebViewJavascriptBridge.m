#import "WebViewJavascriptBridge.h"

@interface WebViewJavascriptBridge ()

@property (nonatomic,strong) NSMutableArray *startupMessageQueue;

- (void)_flushMessageQueueFromWebView:(UIWebView *)webView;
- (void)_doSendMessage:(NSString*)message toWebView:(UIWebView *)webView;

@end

@implementation WebViewJavascriptBridge

@synthesize startupMessageQueue = _startupMessageQueue;

static NSString *MESSAGE_SEPARATOR = @"__wvjb_sep__";
static NSString *CUSTOM_PROTOCOL_SCHEME = @"webviewjavascriptbridge";
static NSString *QUEUE_HAS_MESSAGE = @"queuehasmessage";

+ (id)javascriptBridgeWithDelegate:(id <WebViewJavascriptBridgeDelegate>)delegate {
    WebViewJavascriptBridge* bridge = [[[WebViewJavascriptBridge alloc] initWithDelegate:delegate] autorelease];
	[bridge resetQueue];
    return bridge;
}

- (id) initWithDelegate:(id <WebViewJavascriptBridgeDelegate>)delegate {
    
	self = [super init];
    
    if (self) {
        _delegate = delegate;
    }
    
	return self;
}


- (void)dealloc {
    _delegate = nil;
    [_startupMessageQueue release];

    [super dealloc];
}

- (void)sendMessage:(NSString *)message toWebView:(UIWebView *)webView {
    if (self.startupMessageQueue) { [self.startupMessageQueue addObject:message]; }
    else { [self _doSendMessage:message toWebView: webView]; }
}

- (void)resetQueue {
    self.startupMessageQueue = [[[NSMutableArray alloc] init] autorelease];
}

- (void)_doSendMessage:(NSString *)message toWebView:(UIWebView *)webView {
    message = [message stringByReplacingOccurrencesOfString:@"\\n" withString:@"\\\\n"];
    message = [message stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    message = [message stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"WebViewJavascriptBridge._handleMessageFromObjC('%@');", message]];
}

- (void)_flushMessageQueueFromWebView:(UIWebView *)webView {
    NSString *messageQueueString = [webView stringByEvaluatingJavaScriptFromString:@"WebViewJavascriptBridge._fetchQueue();"];
    NSArray* messages = [messageQueueString componentsSeparatedByString:MESSAGE_SEPARATOR];
    for (id message in messages) {
        [_delegate javascriptBridge:self receivedMessage:message fromWebView:webView];
    }
}

#pragma mark UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSString *js = [NSString stringWithFormat:@";(function() {"
        "if (window.WebViewJavascriptBridge) { return; };"
        "var _readyMessageIframe,"
        "     _sendMessageQueue = [],"
        "     _receiveMessageQueue = [],"
        "     _MESSAGE_SEPERATOR = '%@',"
        "     _CUSTOM_PROTOCOL_SCHEME = '%@',"
        "     _QUEUE_HAS_MESSAGE = '%@';"
        ""
        "function _createQueueReadyIframe(doc) {"
        "     _readyMessageIframe = doc.createElement('iframe');"
        "     _readyMessageIframe.style.display = 'none';"
        "     doc.documentElement.appendChild(_readyMessageIframe);"
        "}"
        ""
        "function _sendMessage(message) {"
        "     _sendMessageQueue.push(message);"
        "     _readyMessageIframe.src = _CUSTOM_PROTOCOL_SCHEME + '://' + _QUEUE_HAS_MESSAGE;"
        "};"
        ""
        "function _fetchQueue() {"
        "     var messageQueueString = _sendMessageQueue.join(_MESSAGE_SEPERATOR);"
        "     _sendMessageQueue = [];"
        "     return messageQueueString;"
        "};"
        ""
        "function _setMessageHandler(messageHandler) {"
        "     if (WebViewJavascriptBridge._messageHandler) { return alert('WebViewJavascriptBridge.setMessageHandler called twice'); }"
        "     WebViewJavascriptBridge._messageHandler = messageHandler;"
        "     var receivedMessages = _receiveMessageQueue;"
        "     _receiveMessageQueue = null;"
        "     for (var i=0; i<receivedMessages.length; i++) {"
        "         messageHandler(receivedMessages[i]);"
        "     }"
        "};"
        ""
        "function _handleMessageFromObjC(message) {"
        "     if (_receiveMessageQueue) { _receiveMessageQueue.push(message); }"
        "     else { WebViewJavascriptBridge._messageHandler(message); }"
        "};"
        ""
        "window.WebViewJavascriptBridge = {"
        "     setMessageHandler: _setMessageHandler,"
        "     sendMessage: _sendMessage,"
        "     _fetchQueue: _fetchQueue,"
        "     _handleMessageFromObjC: _handleMessageFromObjC"
        "};"
        ""
        "var doc = document;"
        "_createQueueReadyIframe(doc);"
        "var readyEvent = doc.createEvent('Events');"
        "readyEvent.initEvent('WebViewJavascriptBridgeReady');"
        "doc.dispatchEvent(readyEvent);"
        ""
        "})();",
        MESSAGE_SEPARATOR,
        CUSTOM_PROTOCOL_SCHEME,
        QUEUE_HAS_MESSAGE];
    
    if (![[webView stringByEvaluatingJavaScriptFromString:@"typeof WebViewJavascriptBridge == 'object'"] isEqualToString:@"true"]) {
        [webView stringByEvaluatingJavaScriptFromString:js];
    }
    
    for (id message in self.startupMessageQueue) {
        [self _doSendMessage:message toWebView: webView];
    }

    self.startupMessageQueue = nil;

    if(_delegate != nil && [_delegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [_delegate webViewDidFinishLoad:webView];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if(_delegate != nil && [_delegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [_delegate webView:webView didFailLoadWithError:error];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSURL *url = [request URL];
    if (![[url scheme] isEqualToString:CUSTOM_PROTOCOL_SCHEME]) {
        if (_delegate != nil && [_delegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
            return [_delegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
        }
        return YES;
    }

    if ([[url host] isEqualToString:QUEUE_HAS_MESSAGE]) {
        [self _flushMessageQueueFromWebView: webView];
    } else {
        NSLog(@"WebViewJavascriptBridge: WARNING: Received unknown WebViewJavascriptBridge command %@://%@", CUSTOM_PROTOCOL_SCHEME, [url path]);
    }

    return NO;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    if(_delegate != nil && [_delegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [_delegate webViewDidStartLoad:webView];
    }
}

@end
