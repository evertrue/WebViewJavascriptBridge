//
//  WebViewJavascriptBridgeDelegate.h
//  EverTrue
//
//  Created by PJ Gray on 5/18/12.
//  Copyright (c) 2012 EverTrue. All rights reserved.
//

#import <Foundation/Foundation.h>

@class WebViewJavascriptBridge;

@protocol WebViewJavascriptBridgeDelegate <UIWebViewDelegate>

- (void)javascriptBridge:(WebViewJavascriptBridge *)bridge receivedMessage:(NSString *)message fromWebView:(UIWebView *)webView;

@end
