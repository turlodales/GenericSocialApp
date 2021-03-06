/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAInboxUI.h"
#import "UAInboxUtils.h"
#import "UAInboxMessageListController.h"
#import "UAInboxMessageViewController.h"

#import "UAInboxMessageList.h"
#import "UAInboxPushHandler.h"

#import "UALandingPageOverlayController.h"
#import "UAUtils.h"

@interface UAInboxUI ()

@property (nonatomic, strong) UIViewController *rootViewController;
@property (nonatomic, strong) UAInboxMessageListController *messageListController;
@property (nonatomic, strong) UAInboxAlertHandler *alertHandler;
@property (nonatomic, assign) BOOL isVisible;

@end

@implementation UAInboxUI

SINGLETON_IMPLEMENTATION(UAInboxUI)


- (id)init {
    self = [super init];
    if (self) {
        NSString* path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"UAInboxLocalization.bundle"];
        self.localizationBundle = [NSBundle bundleWithPath:path];
        
        self.useOverlay = NO;
        self.isVisible = NO;
        
        self.alertHandler = [[UAInboxAlertHandler alloc] init];
    }
    
    return self;
}

- (void)createRootViewController {
    self.messageListController = [[UAInboxMessageListController alloc] initWithNibName:@"UAInboxMessageListController" bundle:nil];
    self.messageListController.title = @"Inbox";
    self.messageListController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(inboxDone:)];

    self.rootViewController = [[UINavigationController alloc] initWithRootViewController:self.messageListController];
}

- (void)inboxDone:(id)sender {
    [self quitInbox:YES];
}

+ (void)displayInboxInViewController:(UIViewController *)parentViewController animated:(BOOL)animated {

    if ([parentViewController isKindOfClass:[UINavigationController class]]) {
        [(UINavigationController *)parentViewController popToRootViewControllerAnimated:NO];
    }

    [[self shared] createRootViewController];

    [self shared].isVisible = YES;
    
    UA_LDEBUG(@"Presenting Inbox Modal");
    UIViewController *inboxViewController = [self shared].rootViewController;

    // Optionally specify a custom modal transition
    inboxViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

    [parentViewController presentViewController:inboxViewController animated:animated completion:NULL];
}

+ (void)displayMessageWithID:(NSString *)messageID inViewController:(UIViewController *)parentViewController {
    if(![self shared].isVisible) {
        
        if ([self shared].useOverlay) {
            UAInboxMessage *message = [[UAInbox shared].messageList messageForID:messageID];
            if (message) {
                [UALandingPageOverlayController showMessage:message];
            } else {
                UA_LDEBUG(@"Unable to retrieve message body URL");
            }
            return;
        }
        
        else {
            UALOG(@"Inbox UI needs to be visible before displaying a message. Displaying now.");
            // We're not inside the modal/navigationcontroller setup so lets start with the parent
            [self displayInboxInViewController:[self shared].inboxParentController animated:NO]; // BUG?
        }
    }
        
    // For iPhone
    UINavigationController *navController = (UINavigationController *)[self shared].rootViewController;
    UAInboxMessageViewController *mvc;
    
    //if a message view is displaying, just load the new message
    if ([navController.topViewController class] == [UAInboxMessageViewController class]) {
        mvc = (UAInboxMessageViewController *) navController.topViewController;
        [mvc loadMessageForID:messageID];
    } 
    //otherwise, push over a new message view
    else {
        mvc = [[UAInboxMessageViewController alloc] initWithNibName:@"UAInboxMessageViewController" bundle:nil];
        mvc.closeBlock = ^(BOOL animated){
            [[self shared] quitInbox:animated];
        };
        [mvc loadMessageForID:messageID];
        [navController pushViewController:mvc animated:YES];
    }
}

- (void)richPushNotificationArrived:(NSDictionary *)message {
    //custom launch notification handling here
}

- (void)richPushMessageAvailable:(UAInboxMessage *)richPushMessage {
    NSString *alertText = richPushMessage.title;
    [self.alertHandler showNewMessageAlert:alertText withViewBlock:^{
        [self.class displayMessageWithID:richPushMessage.messageID inViewController:nil];
    }];
}

- (void)applicationLaunchedWithRichPushNotification:(NSDictionary *)notification {
    //custom launch notification handling here
}

- (void)launchRichPushMessageAvailable:(UAInboxMessage *)richPushMessage {
    [self.class displayMessageWithID:richPushMessage.messageID inViewController:nil];
}

- (void)quitInbox:(BOOL)animated {

    self.isVisible = NO;

    UIViewController *con = [self.rootViewController presentingViewController];
    [con dismissViewControllerAnimated:animated completion:NULL];

    // BUG: Workaround. ModalViewController does not handle resizing correctly if
    // dismissed in landscape when status bar is visible
    if (![UIApplication sharedApplication].statusBarHidden) {

        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        CGRect frame = con.view.frame;
        if (orientation == UIInterfaceOrientationLandscapeRight) {
            con.view.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
        } else if (orientation == UIInterfaceOrientationLandscapeLeft) {
            con.view.frame = CGRectMake(frame.origin.y, frame.origin.x, frame.size.width, frame.size.height);
        }
    }

    self.rootViewController = nil;
}

+ (void)quitInbox {
    [[self shared] quitInbox:YES];
}

+ (void)land {
    //do any necessary teardown here
}

@end
