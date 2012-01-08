//
//  ZPItemObserver.h
//  ZotPad
//
//
//  Objects that implement this protocol can be observers that are 
//  Notified when new items become available
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroItem.h"
@protocol ZPItemObserver <NSObject>

@optional

// Tells an observer that detailed citation information is available
-(void) notifyItemAvailable:(ZPZoteroItem*) item;

// Tells an observer that information about attachments is available
-(void) notifyItemAttachmentsAvailable:(ZPZoteroItem*) item;



@end
