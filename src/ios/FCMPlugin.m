#include <sys/types.h>
#include <sys/sysctl.h>
#import "AppDelegate+FCMPlugin.h"
#import <UserNotifications/UserNotifications.h>
#import <Cordova/CDV.h>
#import "FCMPlugin.h"
#import "Firebase.h"
#import <WebKit/WebKit.h>

@interface FCMPlugin () {}
@end

@implementation FCMPlugin

static BOOL notificatorReceptorReady = NO;
static BOOL appInForeground = YES;

static NSString *notificationCallback = @"FCMPlugin.onNotificationReceived";
static NSString *tokenRefreshCallback = @"FCMPlugin.onTokenRefreshReceived";
static NSString *apnsTokenRefreshCallback = @"FCMPlugin.onAPNSTokenRefreshReceived";
static NSString *apnsToken = nil;
static NSString *fcmToken = nil;
static FCMPlugin *fcmPluginInstance;

+ (FCMPlugin *) fcmPlugin {
    return fcmPluginInstance;
}

+ (void) setInitialAPNSToken:(NSString *)token
{
    NSLog(@"setInitialAPNSToken token: %@", token);
    apnsToken = token;
}

+ (void) setInitialFCMToken:(NSString *)token
{
    NSLog(@"setInitialFCMToken token: %@", token);
    fcmToken = token;
}

- (void) ready:(CDVInvokedUrlCommand *)command
{
    NSLog(@"Cordova view ready");
    fcmPluginInstance = self;
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)registerForRemoteNotifications:(CDVInvokedUrlCommand*)command
{
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_9_x_Max) {
    // iOS 9 or earlier Disable the deprecation warnings.
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UIUserNotificationType allNotificationTypes =
        (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    #pragma clang diagnostic pop
    } else {
    // iOS 10 or later
    #if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
        __weak FCMPlugin* weakSelf = self;
        UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:authOptions completionHandler:^(BOOL granted, NSError * _Nullable error) {
             CDVPluginResult *result = nil;
            
            if (granted) {
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
                [weakSelf runOnMainThread:^{
                    [[UIApplication sharedApplication] registerForRemoteNotifications];
                }];
            } else {
                NSLog(@"User Notification permission denied: %@", error.localizedDescription);
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:NO];
            }
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }];
    #endif
    }
}

// HAS PERMISSION //
- (void) hasPermission:(CDVInvokedUrlCommand *)command
{
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    __block CDVPluginResult *commandResult;
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings){
        switch (settings.authorizationStatus) {
            case UNAuthorizationStatusAuthorized: {
                NSLog(@"has push permission: true");
                commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
                break;
            }
            case UNAuthorizationStatusDenied: {
                NSLog(@"has push permission: false");
                commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:NO];
                break;
            }
            default: {
                NSLog(@"has push permission: unknown");
                commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                break;
            }
        }
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
    }];
}

// GET TOKEN //
- (void) getToken:(CDVInvokedUrlCommand *)command 
{
    NSLog(@"get Token");
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:fcmToken];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

// GET APNS TOKEN //
- (void) getAPNSToken:(CDVInvokedUrlCommand *)command 
{
    NSLog(@"get APNS Token");
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:apnsToken];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

// CLEAR ALL NOTIFICATONS //
- (void)clearAllNotifications:(CDVInvokedUrlCommand *)command
{
  [self.commandDelegate runInBackground:^{
    NSLog(@"clear all notifications");
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

// UN/SUBSCRIBE TOPIC //
- (void) subscribeToTopic:(CDVInvokedUrlCommand *)command 
{
    NSString* topic = [command.arguments objectAtIndex:0];
    NSLog(@"subscribe To Topic %@", topic);
    [self.commandDelegate runInBackground:^{
        if(topic != nil)[[FIRMessaging messaging] subscribeToTopic:topic];
        CDVPluginResult* pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:topic];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void) unsubscribeFromTopic:(CDVInvokedUrlCommand *)command 
{
    NSString* topic = [command.arguments objectAtIndex:0];
    NSLog(@"unsubscribe From Topic %@", topic);
    [self.commandDelegate runInBackground:^{
        if(topic != nil)[[FIRMessaging messaging] unsubscribeFromTopic:topic];
        CDVPluginResult* pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:topic];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void) registerNotification:(CDVInvokedUrlCommand *)command
{
    NSLog(@"view registered for notifications");
    
    notificatorReceptorReady = YES;
    NSData* lastPush = [AppDelegate getLastPush];
    if (lastPush != nil) {
        [FCMPlugin.fcmPlugin notifyOfMessage:lastPush];
    }
    
    CDVPluginResult* pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) notifyOfMessage:(NSData *)payload
{
    NSString *JSONString = [[NSString alloc] initWithBytes:[payload bytes] length:[payload length] encoding:NSUTF8StringEncoding];
    NSString * notifyJS = [NSString stringWithFormat:@"%@(%@);", notificationCallback, JSONString];
	[self runJS:notifyJS];
}

-(void) notifyFCMTokenRefresh:(NSString *)token
{
    NSLog(@"notifyFCMTokenRefresh token: %@", token);
    fcmToken = token;
    NSString * notifyJS = [NSString stringWithFormat:@"%@('%@');", tokenRefreshCallback, token];
	[self runJS:notifyJS];
}

-(void) notifyAPNSTokenRefresh:(NSString *)token
{
    NSLog(@"notifyAPNSTokenRefresh token: %@", token);
    apnsToken = token;
    NSString * notifyJS = [NSString stringWithFormat:@"%@('%@');", apnsTokenRefreshCallback, token];
	[self runJS:notifyJS];
}

- (void)runJS:(NSString *)jsCode {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.webView respondsToSelector:@selector(evaluateJavaScript:completionHandler:)]) {
            [(WKWebView *)self.webView evaluateJavaScript:jsCode completionHandler:nil];
        } else {
            [self.webViewEngine evaluateJavaScript:jsCode completionHandler:nil];
        }
    });
}

-(void) appEnterBackground
{
    NSLog(@"Set state background");
    appInForeground = NO;
}

-(void) appEnterForeground
{
    NSLog(@"Set state foreground");
    NSData* lastPush = [AppDelegate getLastPush];
    if (lastPush != nil) {
        [FCMPlugin.fcmPlugin notifyOfMessage:lastPush];
    }
    appInForeground = YES;
}

-(void)runOnMainThread:(void (^)(void))block {
    if ([NSThread isMainThread]) {
      block();
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            block();
        });
    }
}

@end
