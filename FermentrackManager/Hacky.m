//
//  Hacky.c
//  FermentrackManager
//
//  Created by Corbin Dunn on 11/1/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

#import "Hacky.h"

#import <ServiceManagement/ServiceManagement.h>
#import <Security/Authorization.h>

extern NSError *InstallHelperWithString(NSString *label) {
    AuthorizationItem authItem        = { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
    AuthorizationRights authRights    = { 1, &authItem };
    AuthorizationFlags flags        =    kAuthorizationFlagDefaults                |
                                        kAuthorizationFlagInteractionAllowed    |
                                        kAuthorizationFlagPreAuthorize            |
                                        kAuthorizationFlagExtendRights;

    /* Obtain the right to install our privileged helper tool (kSMRightBlessPrivilegedHelper). */
    AuthorizationRef authRef;
    OSStatus status = AuthorizationCreate(&authRights, kAuthorizationEmptyEnvironment, flags, &authRef);

    if (status != errAuthorizationSuccess) {
        return [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    } else {
        CFErrorRef  cfError;
        
        /* This does all the work of verifying the helper tool against the application
         * and vice-versa. Once verification has passed, the embedded launchd.plist
         * is extracted and placed in /Library/LaunchDaemons and then loaded. The
         * executable is placed in /Library/PrivilegedHelperTools.
         */
        BOOL result = (BOOL) SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)label, authRef, &cfError);
        if (!result) {
            return CFBridgingRelease(cfError);
        }
        return nil;
    }
}
