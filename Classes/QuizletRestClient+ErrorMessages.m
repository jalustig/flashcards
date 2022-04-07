//
//  QuizletRestClient+ErrorMessages.m
//  FlashCards
//
//  Created by Jason Lustig on 4/14/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "QuizletRestClient+ErrorMessages.h"

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "FCCardSet.h"
#import "FCCollection.h"

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#import "QuizletLoginController.h"
#endif

@implementation QuizletRestClient (ErrorMessages)

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
- (void)genericCardSetAccessFailedWithError:(NSError*)error withDelegateView:(UIViewController<QuizletLoginControllerDelegate>*)delegateView withCardSet:(ImportSet*)cardSet 
#else
- (void)genericCardSetAccessFailedWithError:(NSError*)error withDelegateView:(id)delegateView withCardSet:(ImportSet*)cardSet 
#endif
{
    
    if (error.code == kFCErrorObjectDoesNotExist) {
        FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"This set does not exist.", @"Import", @"message"));
    } else if (error.code == kFCErrorObjectDeleted) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"This set was either deleted by its owner or because it had inappropriate content.", @"Import", @"message"));
    } else if (error.code == kFCErrorPrivateSetWithPassword || error.code == kFCErrorPrivateSetPasswordNotValid) {
        NSString *message;
        if (error.code == kFCErrorPrivateSetWithPassword) {
            message = NSLocalizedStringFromTable(@"This is a \"private\" card set and is password-protected. Please enter the set's password (case-sensitive) to access:", @"Import", @"message");
        } else {
            message = NSLocalizedStringFromTable(@"The password you entered is not valid. Please enter the set's password (case-sensitive) to access:", @"Import", @"message");
        }
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@""
                                                            message:message
                                                           delegate:delegateView
                                                  cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"")
                                                  otherButtonTitles:NSLocalizedStringFromTable(@"Download Set", @"Import", @""), nil];
        alertView.alertViewStyle = UIAlertViewStyleSecureTextInput;
        [alertView show];
#endif
    } else if (error.code == kFCErrorUserNotLoggedIn) {
        // the user must log in to access this set:
        FCDisplayBasicErrorMessage(@"",
                                   @"You must log in to enter a password for a set.");
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
        QuizletLoginController *loginController = [QuizletLoginController new];
        loginController.delegate = delegateView;
        [loginController presentFromController:delegateView];
#endif
    } else if (error.code == kFCErrorLoginNotValid) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"There has been an error with your Quizlet authentication; please re-authenticate with Quizlet.", @"Import", @""));
        [FlashCardsCore resetAllRestoreProcessSettings];
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
        QuizletLoginController *loginController = [QuizletLoginController new];
        loginController.delegate = delegateView;
        [loginController presentFromController:delegateView];
#endif        

    } else {
        
        // inform the user
        NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%d)", @"Error", @"message"),
                             [[error userInfo] objectForKey:@"errorMessage"],
                             [error code]];
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   message);
    }

}
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
- (void)genericGroupAccessFailedWithError:(NSError *)error withDelegateView:(UIViewController<QuizletLoginControllerDelegate>*)delegateView withGroup:(ImportGroup*)group
#else
- (void)genericGroupAccessFailedWithError:(NSError *)error withDelegateView:(id)delegateView withGroup:(ImportGroup*)group
#endif
{
    if (error.code == kFCErrorGroupAccessPending) {
        FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"The administrator of this group has been notified of your application.", @"Import", @"message"));
    } else if (error.code == kFCErrorLoginNotValid) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"There has been an error with your Quizlet authentication; please re-authenticate with Quizlet.", @"Import", @""));
        [FlashCardsCore resetAllRestoreProcessSettings];
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
        QuizletLoginController *loginController = [QuizletLoginController new];
        loginController.delegate = delegateView;
        [loginController presentFromController:delegateView];
#endif        
    } else if (error.code == kFCErrorGroupAccessRemoved) {
        FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"An administrator of this group has removed you.", @"Import", @"message"));
    } else if (error.code == kFCErrorGroupAccessInvited) {
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                         message:NSLocalizedStringFromTable(@"You have been invited to join this group. Would you like to join?", @"Import", @"message")
                                                        delegate:delegateView
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"")
                                               otherButtonTitles:NSLocalizedStringFromTable(@"Join Group", @"Import", @""), nil];
        [alert show];
#endif
    } else if (error.code == kFCErrorObjectDoesNotExist) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"This group does not exist.", @"Import", @"message"));
    } else if (error.code == kFCErrorObjectDeleted) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"This group was either deleted by its owner or because it had inappropriate content.", @"Import", @"message"));
    } else if (error.code == kFCErrorGroupLimitExceeded) {
        FCDisplayBasicErrorMessage(@"", 
                                   NSLocalizedStringFromTable(@"You may only join a maximum of 8 Quizlet groups (you have 8). Please remove some before adding new ones, or subscribe to the Quizlet PLUS service to have unlimited groups. (This is a limitation of Quizlet, not FlashCards++, please consult the FAQ on www.Quizlet.com.)", @"Import", @"message"));
    } else if (error.code == kFCErrorPrivateSet || error.code == kFCErrorPrivateSetWithPassword || error.code == kFCErrorPrivateSetPasswordNotValid) {
        NSString *message;
        if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) { 
            bool hasGroupScope = [(NSNumber*)[FlashCardsCore getSetting:@"quizletWriteGroupScope"] boolValue];
            if (!hasGroupScope) {
                
                // the user is not logged in - we must ask the user to log in before joining a group.
                NSString *message = NSLocalizedStringFromTable(@"Please log in to Quizlet to access or join this group.", @"Import", @"message");
                FCDisplayBasicErrorMessage(@"", message);
                
                [FlashCardsCore resetAllRestoreProcessSettings];
                [FlashCardsCore setSetting:@"importProcessRestore" value:@YES];
                if ([delegateView collection] != nil) {
                    [FlashCardsCore setSetting:@"importProcessRestoreCollectionId" value:[[[[delegateView collection] objectID] URIRepresentation] absoluteString]];
                }
                if ([delegateView cardSet] != nil) {
                    [FlashCardsCore setSetting:@"importProcessRestoreCardsetId" value:[[[[delegateView cardSet] objectID] URIRepresentation] absoluteString]];
                }
                QuizletLoginController *loginController = [QuizletLoginController new];
                loginController.delegate = delegateView;
                [loginController presentFromController:delegateView];
                return;
            }

            bool isSecure;
            NSString *message;
            NSString *placeholder;
            if (error.code == kFCErrorPrivateSetWithPassword || error.code == kFCErrorPrivateSetPasswordNotValid) {
                group.requiresPassword = YES;
                // if it requires a password, ask for the password:
                isSecure = YES;
                if (error.code == kFCErrorPrivateSetWithPassword) {
                    // it is the first time, so ask for the password:
                    message = NSLocalizedStringFromTable(@"This is a \"private\" group and is password-protected. Please enter the group's password (case-sensitive) to join:", @"Import", @"message");
                } else {
                    // it is the wrong password:
                    message = NSLocalizedStringFromTable(@"The password you entered is not valid. Please enter the group's password (case-sensitive) to join:", @"Import", @"message");
                }
                placeholder = NSLocalizedStringFromTable(@"Group Password", @"Import", @"");
            } else {
                group.requiresPassword = NO;
                // if it is just asking for permission to join, ask the user to join:
                isSecure = NO;
                message = NSLocalizedStringFromTable(@"The is a \"private\" group. Please enter a quick message to the group to ask to join:", @"Import", @"message");
                placeholder = NSLocalizedStringFromTable(@"Your Message", @"Import", @"");
            }
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@""
                                                                message:message
                                                               delegate:delegateView
                                                      cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"")
                                                      otherButtonTitles:NSLocalizedStringFromTable(@"Join Group", @"Import", @""), nil];
            alertView.alertViewStyle = UIAlertViewStyleSecureTextInput;
            [alertView show];
#endif
        } else {
            // if the user is not yet logged in, ask the user to log in:
            message = NSLocalizedStringFromTable(@"This is a \"private\" group. Please log in to Quizlet to access or join this group.", @"Import", @"message");
            FCDisplayBasicErrorMessage(@"", message);
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED

            [FlashCardsCore resetAllRestoreProcessSettings];
            if ([delegateView respondsToSelector:@selector(cardSet)]) {
                [FlashCardsCore setSetting:@"importProcessRestore" value:[NSNumber numberWithBool:YES]];
                if ([delegateView collection] != nil) {
                    [FlashCardsCore setSetting:@"importProcessRestoreCollectionId" value:[[[[delegateView collection] objectID] URIRepresentation] absoluteString]];
                }
                if ([delegateView cardSet] != nil) {
                    [FlashCardsCore setSetting:@"importProcessRestoreCardsetId" value:[[[[delegateView cardSet] objectID] URIRepresentation] absoluteString]];
                    [FlashCardsCore setSetting:@"importProcessRestoreCollectionId" value:[[[[[delegateView cardSet] collection] objectID] URIRepresentation] absoluteString]];
                }
            }
            [FlashCardsCore setSetting:@"importProcessRestoreChoiceViewController" value:NSStringFromClass([delegateView class])];

            QuizletLoginController *loginController = [QuizletLoginController new];
            loginController.delegate = delegateView;
            [loginController presentFromController:delegateView];
#endif
        }    
    } else {
        
        // inform the user
        NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%d)", @"Error", @"message"),
                             [[error userInfo] objectForKey:@"errorMessage"],
                             [error code]];
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   message);
    }
}

@end
