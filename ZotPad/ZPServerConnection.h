//
//  ZPServerConnection.h
//  ZotPad
//
//  Handles communication with Zotero server. Used as a singleton.
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OAuthConsumer.h"
#import "OAToken.h"
#import "ZPAuthenticationDialog.h"
#import "ZPServerResponseXMLParser.h"

@interface ZPServerConnection : NSObject{
    
    //The Oauht key to use
    NSString* _oauthkey;
    NSString* _username;
    NSString* _userID;
    
    OAToken* _requestToken;
    
    // A reference to source view controller so that we can display modal views for authentication
    UIViewController* _sourceViewController;
    
    // Dialog that will show the Zotero login
    // TODO: Should this be located in the AppDelegate instead? 
    ZPAuthenticationDialog* _authenticationDialog;
 
    BOOL _debugServerConnection;
}

// This class is used as a singleton
+ (ZPServerConnection*) instance;

// Check if the connection is already authenticated
- (BOOL) authenticated;

// Authenticates with OAuth
- (void) doAuthenticate:(UIViewController*) source;

// Methods used in the OAuth authentication
- (void) makeOAuthRequest: (OAToken *) token;
- (void)requestTokenTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data;

// Methods to get data from the server
-(NSArray*) retrieveLibrariesFromServer;
-(NSArray*) retrieveCollectionsForLibraryFromServer:(NSInteger)libraryID;
-(ZPServerResponseXMLParser*) retrieveItemsFromLibrary:(NSInteger)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString sortField:(NSString*)sortField sortDescending:(BOOL)sortIsDescending limit:(NSInteger)maxCount start:(NSInteger)offset;
@end
