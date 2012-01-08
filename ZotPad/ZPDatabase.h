//
//  ZPDatabase.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroItem.h"
#import "ZPZoteroNote.h"
#import "ZPZoteroAttachment.h"

#import "../FMDB/src/FMDatabase.h"
#import "../FMDB/src/FMResultSet.h"

@interface ZPDatabase : NSObject{
     
    FMDatabase* _database;
}

// This class is used as a singleton
+ (ZPDatabase*) instance;


-(void) addOrUpdateLibraries:(NSArray*)libraries;
-(void) addOrUpdateCollections:(NSArray*)collections forLibrary:(NSNumber*)libraryID;


// Methods for retrieving data from the data layer
- (NSArray*) libraries;
- (NSArray*) collectionsForLibrary : (NSNumber*)currentLibraryID withParentCollection:(NSString*)currentCollectionKey;
- (NSArray*) allCollectionsForLibrary: (NSNumber*)libraryID;
- (ZPZoteroItem*) getItemByKey: (NSString*) key;
- (NSArray*) getItemKeysForLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey
                      searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending;


- (void) addCreatorsToItem: (ZPZoteroItem*) item;
- (void) addFieldsToItem: (ZPZoteroItem*) item;
- (void) addNotesToItem: (ZPZoteroItem*) item;
- (void) addAttachmentsToItem: (ZPZoteroItem*) item;

//Return a list of all attachment paths ordered by priority for removel
- (NSArray*) getCachedAttachmentPaths;


- (void) updateViewedTimestamp:(ZPZoteroAttachment*)attachment;

- (NSString*) getLocalizationStringWithKey:(NSString*) key type:(NSString*) type locale:(NSString*) locale;



// Methods for writing data to database
-(void) addItemToDatabase:(ZPZoteroItem*)item;
-(void) addNoteToDatabase:(ZPZoteroNote*)note;
-(void) addAttachmentToDatabase:(ZPZoteroAttachment*)attachment;

// Records a new collection membership
-(void) addItem:(ZPZoteroItem*)item toCollection:(NSString*)collectionKey;

//Extract data from item and write to database

-(void) writeItemCreatorsToDatabase:(ZPZoteroItem*)item;
-(void) writeItemFieldsToDatabase:(ZPZoteroItem*)item;

// These remove items from the cache
- (void) removeItemsNotInArray:(NSArray*)itemKeys fromCollection:(NSString*)collectionKey inLibrary:(NSNumber*)libraryID;
- (void) deleteItemsNotInArray:(NSArray*)itemKeys fromLibrary:(NSNumber*)libraryID;

- (void) setUpdatedTimestampForCollection:(NSString*)collectionKey toValue:(NSString*)updatedTimestamp;
- (void) setUpdatedTimestampForLibrary:(NSNumber*)libraryID toValue:(NSString*)updatedTimestamp;

@end
