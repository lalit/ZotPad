
//
//  ZPFileChannel_WebDAV.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPCore.h"

#import "ZPFileChannel_WebDAV.h"
#import "ZPPreferences.h"
#import "ZPServerConnection.h"
#import "ASIHTTPRequest.h"
#import "ZPLogger.h"
#import "ZPDatabase.h"

#import "SBJson.h"


//Unzipping and base64 decoding
#import "ZipArchive.h"
#import "QSStrings.h"


NSInteger const ZPFILECHANNEL_WEBDAV_DOWNLOAD = 1;
NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_FILE = 3;
NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_REGISTER = 4;

// This is needed bacause WebDAV requests contain actually two request. The first request will just request the size of the file.

@interface ZPFileChannel_WebDAV_ProgressDelegate : NSObject <ASIHTTPRequestDelegate>{
    long long length;
    long long received;
}
-(id) initWithUIProgressView:(UIProgressView*)view;

@property (retain) UIProgressView* progressView;

@end

@implementation ZPFileChannel_WebDAV_ProgressDelegate

@synthesize progressView;

-(id) initWithUIProgressView:(UIProgressView*)view{
    self = [super init];
    progressView = view;
    length = 0;
    received = 0;
    return self;
}

-(int) fileChannelType{
    return VERSION_SOURCE_WEBDAV;
}

- (void)request:(ASIHTTPRequest *)request didReceiveBytes:(long long)bytes{
    received += bytes;

    //Only update the progress view when the file has started downloading.
    
    if([request responseStatusCode] == 200){
        float progress = (float)received/length;
        [self.progressView setProgress:progress];
    }
}
- (void)request:(ASIHTTPRequest *)request incrementDownloadSizeBy:(long long)newLength{
    length += newLength;
}

@end

@implementation ZPFileChannel_WebDAV


- (id) init{
    self= [super init];
    downloadProgressDelegates = [[NSMutableDictionary alloc] init];
    return self;
}

#pragma mark - Downloading

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    //Setup the request 
    NSString* WebDAVRoot = [[ZPPreferences instance] webDAVURL];
    NSString* key =  attachment.key;
    NSString* urlString = [WebDAVRoot stringByAppendingFormat:@"/%@.zip",key];
    NSURL *url = [NSURL URLWithString:urlString]; 
    
    NSLog(@"Downloading from WebDAV %@",urlString);
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url]; 
    
    [self linkAttachment:attachment withRequest:request];
        
    NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
    [request setDownloadDestinationPath:tempFile];
    
    //For some reason authentication using digest fails if persistent connections are in use
    [request setShouldAttemptPersistentConnection:NO];
    [request setShouldPresentAuthenticationDialog:YES];
    [request setUseKeychainPersistence:YES];
    [request setRequestMethod:@"GET"];
    [request setDelegate:self];
    [request setShowAccurateProgress:TRUE];

    request.userInfo = [NSDictionary dictionaryWithObject:attachment forKey:@"attachment"];
    request.tag = ZPFILECHANNEL_WEBDAV_DOWNLOAD;
    
    [request startAsynchronous];

}
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    
    if(request != NULL){
        [request cancel];
        [self cleanupAfterFinishingAttachment:attachment];
    }
}
-(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    
    if(request != NULL){
        ZPFileChannel_WebDAV_ProgressDelegate* progressDelegate;
        @synchronized(downloadProgressDelegates){
            progressDelegate = [downloadProgressDelegates objectForKey:[NSNumber numberWithInt: attachment]];
            
            if(progressDelegate == NULL){
                progressDelegate  = [[ZPFileChannel_WebDAV_ProgressDelegate alloc] initWithUIProgressView:progressView];
                [downloadProgressDelegates setObject:progressDelegate forKey:[NSNumber numberWithInt: attachment]];
            }
            else{
                progressDelegate.progressView = progressView;
            }
        }
        [request setDownloadProgressDelegate:progressDelegate];
    }
}

#pragma mark - Uploading


-(void) startUploadingAttachment:(ZPZoteroAttachment*)attachment{
    
    //Download new attachment metadata
    
    //TODO: Refactor this to call ZPCacheController instead so that the response from the server is stored in the DB. 

    attachment = [[[ZPServerConnection instance] retrieveItemsFromLibrary:attachment.libraryID itemKeys:[NSArray arrayWithObject:attachment.key]] objectAtIndex:0];
    NSLog(@"Reveived MD5 from server %@",attachment.md5);
    
    if(! [attachment.md5 isEqualToString:attachment.versionIdentifier_local]){
        //Conflict
        NSLog(@"Local MD5 %@ conflicts with server MD5 %@",attachment.versionIdentifier_local,attachment.md5);
        NSLog(@"Original file MD5: %@",[attachment md5ForFileAtPath:attachment.fileSystemPath_original]);
        NSLog(@"Modified file MD5: %@",[attachment md5ForFileAtPath:attachment.fileSystemPath_modified]);
        
        //If the version that we have downloaded from the server is different than what exists on the server now, delete the local copy
        if(! [attachment.md5 isEqualToString:attachment.versionIdentifier_server]){
            NSLog(@"Download MD5 %@ conflicts with server MD5 %@",attachment.versionIdentifier_server,attachment.md5);

            [[NSFileManager defaultManager] removeItemAtPath:attachment.fileSystemPath_original error:NULL];
            attachment.versionIdentifier_server = attachment.md5;
            [[ZPDatabase instance] writeVersionInfoForAttachment:attachment];
        }
        [self presentConflictViewForAttachment:attachment];

    }
    else{
        
        //Start uploading item metadata
        
        NSString* path = attachment.fileSystemPath_modified;
        NSDictionary* documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES];
        NSTimeInterval timeModified = [[documentFileAttributes fileModificationDate] timeIntervalSince1970];
        timeModified = timeModified * 1000.0f;
        NSInteger intTime = (int) timeModified;
        NSString* md5 = [attachment md5ForFileAtPath:path];    
        
        if(md5==NULL){
            [NSException raise:@"MD5 cannot be null" format:@""];
        }
        NSString* oauthkey =  [[ZPPreferences instance] OAuthKey];
        NSString* urlString = [NSString stringWithFormat:@"https://api.zotero.org/users/%@/items/%@?key=%@",[[ZPPreferences instance] userID],attachment.key, oauthkey];
        
        ASIHTTPRequest* request = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:urlString]];

        request.userInfo = [NSDictionary dictionaryWithObject:attachment forKey:@"attachment"];
        request.tag = ZPFILECHANNEL_WEBDAV_UPLOAD_REGISTER;
        request.delegate = self;
        
        [request addRequestHeader:@"Content-Type" value:@"application/json"];
        [request addRequestHeader:@"If-Match" value:attachment.etag];
        
        //Update the JSON
        NSDictionary* oldJsonContent = (NSDictionary*) [attachment.jsonFromServer JSONValue];
        NSMutableDictionary* jsonContent = [NSMutableDictionary dictionaryWithDictionary:oldJsonContent];

        [jsonContent setObject:md5 forKey:@"md5"];
        [jsonContent setObject:[NSNumber numberWithInt:timeModified] forKey:@"mtime"];
        
        NSString* jsonString = [jsonContent JSONRepresentation];
        [request appendPostData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
        request.requestMethod = @"PUT";
        
        //this can be removed
        request.timeOutSeconds=10;

        NSLog(@"Sent MD5 to server %@",md5);

        [request startAsynchronous];
    }
}

-(void) useProgressView:(UIProgressView*) progressView forUploadingAttachment:(ZPZoteroAttachment*)attachment{
    
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    
    if(request != NULL){
        if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_FILE){
            [request setUploadProgressDelegate:progressView];
        }
        else{
            NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:request.userInfo];
            [dict setObject:progressView forKey:@"progressView"];
            request.userInfo = dict;
        }
    }
}


#pragma mark - Callbacks

- (void)requestFinished:(ASIHTTPRequest *)request{
    
    ZPZoteroAttachment* attachment = [request.userInfo objectForKey:@"attachment"];
    
    if(request.tag == ZPFILECHANNEL_WEBDAV_DOWNLOAD){
        NSString* tempFile; 
        
        if([attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL && [attachment.contentType isEqualToString:@"text/html"]){
            tempFile = [request downloadDestinationPath];
        }
        
        else {
            //Unzip the attachment
            ZipArchive* zipArchive = [[ZipArchive alloc] init];
            [zipArchive UnzipOpenFile:[request downloadDestinationPath]];
            
            tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
            
            [zipArchive UnzipFileTo:tempFile overWrite:YES];
            [zipArchive UnzipCloseFile];
            
            //Use the first unzipped file
            NSArray* unzippedFiles = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:tempFile error:NULL];
            if([unzippedFiles count]!=1){
                TFLog([NSString stringWithFormat:@"Normal attachment files downloaded from WebDAV should have one file inside a zip. Attachment with key %@ downloaded from URL %@ had %i files in the zip",attachment.key,request.url,[unzippedFiles count]]);
                tempFile = NULL;
            }
            else{
                tempFile = [tempFile stringByAppendingPathComponent:[unzippedFiles objectAtIndex:0]];
            }
        }
        
        NSString* md5 = [attachment md5ForFileAtPath:tempFile];
        
        NSLog(@"Received file MD5 from server %@", md5);
                                               
        [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:tempFile withVersionIdentifier:md5 usingFileChannel:self];
        
        [self cleanupAfterFinishingAttachment:attachment];
    }
    else if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_REGISTER){
        if(request.responseStatusCode == 200){

            //OK. Start uploading the actual file
            
            //Setup the request 
            NSString* WebDAVRoot = [[ZPPreferences instance] webDAVURL];
            NSString* key =  attachment.key;
            NSString* urlString = [WebDAVRoot stringByAppendingFormat:@"/%@.zip",key];
            NSURL *url = [NSURL URLWithString:urlString]; 
            
            NSLog(@"Uploading to WebDAV %@",urlString);
            
            ASIHTTPRequest *uploadRequest = [ASIHTTPRequest requestWithURL:url]; 
            
            [self linkAttachment:attachment withRequest:request];

            //For some reason authentication using digest fails if persistent connections are in use
            [uploadRequest setShouldAttemptPersistentConnection:NO];
            [uploadRequest setShouldPresentAuthenticationDialog:YES];
            [uploadRequest setUseKeychainPersistence:YES];
            
            //Zip the file before uploading
            
            ZipArchive* zipArchive = [[ZipArchive alloc] init];

            NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];

            NSString* encodedName = [[QSStrings encodeBase64WithString:attachment.filename] stringByAppendingString:@"%ZB64"];

            [zipArchive CreateZipFile2:tempFile];
            [zipArchive addFileToZip:attachment.fileSystemPath_modified newname:encodedName];
            [zipArchive CloseZipFile2];
            
            [uploadRequest appendPostDataFromFile:tempFile];
            
            [[NSFileManager defaultManager] removeItemAtPath:tempFile error:NULL];
            [uploadRequest setRequestMethod:@"PUT"];
            [uploadRequest setDelegate:self];
            
            uploadRequest.userInfo = [NSDictionary dictionaryWithObject:attachment forKey:@"attachment"];
            uploadRequest.tag = ZPFILECHANNEL_WEBDAV_UPLOAD_FILE;
            
            NSObject* progressDelegate = [request.userInfo objectForKey:@"progressView"];
            if(progressDelegate != NULL){
                uploadRequest.uploadProgressDelegate = progressDelegate;
            }

            [uploadRequest startAsynchronous];
        }
        else if(request.responseStatusCode == 412){
            //Conflict. 
            
            //Download new attachment metadata
            
            //TODO: Refactor this to call ZPCacheController instead so that the response from the server is stored in the DB. 
            
            attachment = [[[ZPServerConnection instance] retrieveItemsFromLibrary:attachment.libraryID itemKeys:[NSArray arrayWithObject:attachment.key]] objectAtIndex:0];
            
            //If the version that we have downloaded from the server is different than what exists on the server now, delete the local copy
            if(! [attachment.md5 isEqualToString:attachment.versionIdentifier_server]){
                [[NSFileManager defaultManager] removeItemAtPath:attachment.fileSystemPath_original error:NULL];
                attachment.versionIdentifier_server = attachment.md5;
                [[ZPDatabase instance] writeVersionInfoForAttachment:attachment];
            }
            [self presentConflictViewForAttachment:attachment];
        }
        else{
            NSError* error =[NSError errorWithDomain:@"zotero.org" code:request.responseStatusCode userInfo:[NSDictionary dictionaryWithObject:@"" forKey:NSLocalizedDescriptionKey]];
            [self cleanupAfterFinishingAttachment:attachment];
            [[ZPServerConnection instance] failedUploadingAttachment:attachment withError:error usingFileChannel:self];
        }
    }
    else if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_FILE){
        //All done
        [[ZPServerConnection instance] finishedUploadingAttachment:attachment];
        [self cleanupAfterFinishingAttachment:attachment];
    }

}

- (void)requestFailed:(ASIHTTPRequest *)request{
    NSError *error = [request error];
    TFLog(@"File download from Zotero server failed: %@",[error description]);

    ZPZoteroAttachment* attachment = [request.userInfo objectForKey:@"attachment"];
    
    //If there was an authentication issue, reauthenticate
    if(error.code == 3){
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Authentication failed"
                                                          message:@"Authenticating with WebDAV server failed."
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:@"Disable WebDAV",nil];
        
        [message show];
    }
    if(error.code == 5){
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Configuration error"
                                                          message:@"WebDAV addresss is not configured properly. Please check ZotPad settings."
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:@"Disable WebDAV",nil];
        
        [message show];
    }
    
    if(request.tag == ZPFILECHANNEL_WEBDAV_DOWNLOAD){
        [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self];
    }
    else{
        [[ZPServerConnection instance] failedUploadingAttachment:attachment withError:error usingFileChannel:self];
    }
    
    [self cleanupAfterFinishingAttachment:attachment];
}

-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment *)attachment{
    @synchronized(downloadProgressDelegates){
        [downloadProgressDelegates removeObjectForKey:[NSNumber numberWithInt: attachment]];
    }

}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    //Disable webdav
    if(buttonIndex == 1){
        [[ZPPreferences instance] setUseWebDAV:FALSE];
    }
}


@end
