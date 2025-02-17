//
//  OCNotifications.m
//  ownCloud iOS library
//
//  Created by Marino Faggiana on 23/01/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//


#import "OCNotifications.h"

@implementation OCNotifications

- (id)init {
    
    self = [super init];
    
    if (self) {
        
        self.idNotification = 0;
        self.application = @"";
        self.user = @"";
        self.date = [NSDate date];
        self.typeObject = @"";
        self.idObject = @"";
        self.subject = @"";
        self.subjectRich = @"";
        self.subjectRichParameters = [NSDictionary new];
        self.message = @"";
        self.messageRich = @"";
        self.messageRichParameters = [NSDictionary new];
        self.link = @"";
        self.icon = @"";
        self.actions = [NSArray new];
    }
    
    return self;
}

@end
