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
#import "ZPAuthenticationDialog.h"
#import "ZPServerResponseXMLParser.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroLibrary.h"
#import "ZPZoteroAttachment.h"


@interface ZPServerConnection : NSObject{
        
    NSInteger _activeRequestCount;
    
    NSMutableDictionary* _attachmentFileDataObjectsByConnection;
    NSMutableDictionary* _attachmentObjectsByConnection;
}

// This class is used as a singleton
+ (ZPServerConnection*) instance;

// Check if the connection is already authenticated
- (BOOL) authenticated;

// Methods to get data from the server
-(NSArray*) retrieveLibrariesFromServer;
-(NSArray*) retrieveCollectionsForLibraryFromServer:(NSNumber*)libraryID;

-(NSArray*) retrieveItemsFromLibrary:(NSNumber*)libraryID itemKeys:(NSArray*)keys;

-(NSArray*) retrieveItemsFromLibrary:(NSNumber*)libraryID limit:(NSInteger)limit offset:(NSInteger)offest;
-(NSArray*) retrieveKeysInContainer:(NSNumber*)libraryID collectionKey:(NSString*)key;
-(NSString*) retrieveTimestampForContainer:(NSNumber*)libraryID collectionKey:(NSString*)key;
-(NSArray*) retrieveNoteAndAttachmentKeysFromLibrary:(NSNumber*)libraryID;

//This retrieves single item details and notes and attachments associated with that item
-(ZPZoteroItem*) retrieveSingleItemDetailsFromServer:(ZPZoteroItem*)item;

-(void) downloadAttachment:(ZPZoteroAttachment*)attachment;


@end
