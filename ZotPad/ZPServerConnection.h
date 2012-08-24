//
//  ZPServerConnection.h
//  ZotPad
//
//  Handles communication with Zotero server. Used as a singleton.
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPAuthenticationDialog.h"
#import "ZPServerResponseXMLParser.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroLibrary.h"
#import "ZPZoteroAttachment.h"
#import "ZPFileChannel.h"


@interface ZPServerConnection : NSObject <UIAlertViewDelegate>{
}

// Check if the connection is already authenticated
+(BOOL) authenticated;
+(BOOL) hasInternetConnection;

// Methods to get data from the server
+(NSArray*) retrieveLibrariesFromServer;
+(NSArray*) retrieveCollectionsForLibraryFromServer:(NSInteger)libraryID;

+(NSArray*) retrieveItemsFromLibrary:(NSInteger)libraryID itemKeys:(NSArray*)keys;

+(NSArray*) retrieveKeysInContainer:(NSInteger)libraryID collectionKey:(NSString*)key;
+(NSArray*) retrieveKeysInContainer:(NSInteger)libraryID collectionKey:(NSString*)collectionKey searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending;
    
+(NSString*) retrieveTimestampForContainer:(NSInteger)libraryID collectionKey:(NSString*)key;
+(NSArray*) retrieveAllItemKeysFromLibrary:(NSInteger)libraryID;

//This retrieves single item details and notes and attachments associated with that item
+(ZPZoteroItem*) retrieveSingleItemDetailsFromServer:(ZPZoteroItem*)item;

// Asynchronous downloading of files
+(NSInteger) numberOfFilesDownloading;
+(BOOL) checkIfCanBeDownloadedAndStartDownloadingAttachment:(ZPZoteroAttachment*)attachment;
+(void) finishedDownloadingAttachment:(ZPZoteroAttachment*)attachment toFileAtPath:(NSString*) tempFile withVersionIdentifier:(NSString*) identifier usingFileChannel:(ZPFileChannel*)fileChannel;
+(void) failedDownloadingAttachment:(ZPZoteroAttachment*)attachment withError:(NSError*) error usingFileChannel:(ZPFileChannel*)fileChannel fromURL:(NSString*)url;
+(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment;
+(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment;
+(BOOL) isAttachmentDownloading:(ZPZoteroAttachment*)attachment;

//Asynchronous uploading of files
+(NSInteger) numberOfFilesUploading;
+(void) uploadVersionOfAttachment:(ZPZoteroAttachment*)attachment;
+(void) finishedUploadingAttachment:(ZPZoteroAttachment*)attachment withVersionIdentifier:(NSString*)identifier;
+(void) failedUploadingAttachment:(ZPZoteroAttachment*)attachment withError:(NSError*) error usingFileChannel:(ZPFileChannel*)fileChannel toURL:(NSString*)url;
+(void) canceledUploadingAttachment:(ZPZoteroAttachment*)attachment usingFileChannel:(ZPFileChannel*)fileChannel;
+(void) useProgressView:(UIProgressView*) progressView forUploadingAttachment:(ZPZoteroAttachment*)attachment;
+(BOOL) isAttachmentUploading:(ZPZoteroAttachment*)attachment;

+(void) removeProgressView:(UIProgressView*) progressView;


@end
