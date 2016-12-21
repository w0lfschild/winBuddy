//
//  winBuddy.m
//  winBuddy
//
//  Created by Wolfgang Baird on 11/27/16.
//  Copyright © 2016 Wolfgang Baird. All rights reserved.
//

@import AppKit;

#import "FConvenience.h"
#import <Carbon/Carbon.h>
#import <objc/runtime.h>

#define APP_BLACKLIST @[@"com.apple.loginwindow", @"com.apple.notificationcenterui"]
#define CLS_BLACKLIST @[@"TDesktopWindow", @"NSStatusBarWindow", @"NSCarbonMenuWindow", @"BookmarkBarFolderWindow", @"TShrinkToFitWindow", @"QLFullscreenWindow", @"QLPreviewPanel"]

#define PrefKey(key)  (@"winBuddy_" key)
#define ReadPref(key) [Defaults objectForKey:PrefKey(key)]
#define WritePref(key, value) [Defaults setObject:(value) forKey:PrefKey(key)]

static const char * const borderKey = "mf_border";

@interface winBuddy : NSObject
- (void)_updateMenubarState;
- (IBAction)_toggleMenubar:(id)sender;
- (IBAction)_toggleShadows:(id)sender;
- (IBAction)_toggleBorder:(id)sender;
@end

@interface NSWindow (wb_window)
- (void)mf_setupBorder;
- (void)mf_initBorder;
- (void)mf_updateBorder;
@end

winBuddy    *plugin;
NSMenu      *winBuddyMenu;
static void *isActive = &isActive;

@implementation winBuddy

+ (winBuddy*) sharedInstance
{
    static winBuddy* plugin = nil;
    
    if (plugin == nil)
        plugin = [[winBuddy alloc] init];
    
    return plugin;
}

+ (void)load
{
    plugin = [winBuddy sharedInstance];
    NSUInteger osx_ver = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
    
    if (osx_ver >= 9)
    {
        if (![APP_BLACKLIST containsObject:[[NSBundle mainBundle] bundleIdentifier]])
        {
            NSLog(@"Loading winBuddy...");
            
            [Defaults registerDefaults:@{ PrefKey(@"HideMenubar"): @NO }];
            [Defaults registerDefaults:@{ PrefKey(@"HideShadow"): @YES }];
            [Defaults registerDefaults:@{ PrefKey(@"ShowBorder"): @YES }];

            [plugin setMenu];
            [plugin _updateMenubarState];
            
            // Initialize any windows that might already exist
            for(NSWindow *window in [NSApp windows])
                [plugin winBuddy_initialize:window];
            
            [[NSNotificationCenter defaultCenter] addObserver:plugin
                                                     selector:@selector(winBuddy_WindowDidBecomeKey:)
                                                         name:NSWindowDidBecomeKeyNotification
                                                       object:nil];
            
            NSLog(@"%@ loaded into %@ on macOS 10.%ld", [self class], [[NSBundle mainBundle] bundleIdentifier], (long)osx_ver);
        }
        else
        {
            NSLog(@"winBuddy is blocked in this application because of issues");
        }
    }
    else
    {
        NSLog(@"winBuddy is blocked in this application because of your version of macOS is too old");
    }
}

- (void)winBuddy_WindowDidBecomeKey:(NSNotification *)notification {
    [plugin winBuddy_initialize:[notification object]];
}

- (void)winBuddy_initialize:(NSWindow*)theWindow {
//    NSLog(@"wb_ %@", [theWindow className]);
    if (![CLS_BLACKLIST containsObject:[theWindow className]])
    {
        if (![objc_getAssociatedObject(theWindow, isActive) boolValue])
        {
            if (ReadPref(@"HideShadow") != nil)
                theWindow.hasShadow = ![ReadPref(@"HideShadow") boolValue];
            [plugin _updateMenubarState];
            [theWindow mf_setupBorder];
            objc_setAssociatedObject(theWindow, isActive, [NSNumber numberWithBool:true], OBJC_ASSOCIATION_RETAIN);
        }
    }
}

- (void)_updateMenubarState {
    if([ReadPref(@"HideMenubar") boolValue])
        SetSystemUIMode(kUIModeAllSuppressed, kUIOptionAutoShowMenuBar);
    else
        SetSystemUIMode(kUIModeNormal, 0);
}

- (void)_updateShadowState {
    for(NSWindow *window in [NSApp windows])
        [window setHasShadow:![ReadPref(@"HideShadow") boolValue]];
}

- (void)_updateBorderState {
    for(NSWindow *window in [NSApp windows])
        [window mf_updateBorder];
}


- (IBAction)_toggleMenubar:(id)sender {
    WritePref(@"HideMenubar", @(![ReadPref(@"HideMenubar") boolValue]));
    [sender setState:[ReadPref(@"HideMenubar") boolValue]];
    [self _updateMenubarState];
}

- (IBAction)_toggleShadows:(id)sender {
    WritePref(@"HideShadow", @(![ReadPref(@"HideShadow") boolValue]));
    [sender setState:[ReadPref(@"HideShadow") boolValue]];
    [self _updateShadowState];
}

- (IBAction)_toggleBorder:(id)sender {
    WritePref(@"ShowBorder", @(![ReadPref(@"ShowBorder") boolValue]));
    [sender setState:[ReadPref(@"ShowBorder") boolValue]];
    [self _updateBorderState];
}

- (void)setMenu {
    NSMenu* windowMenu = [NSApp windowsMenu];
    winBuddyMenu = [plugin winBuddyMenuCreate];
    NSUInteger zoomIdx = [windowMenu indexOfItemWithTitle:@"Zoom"];
    [windowMenu insertItem:[NSMenuItem separatorItem] atIndex:zoomIdx+1];
    NSMenuItem* newItem = [[NSMenuItem alloc] initWithTitle:@"winBuddy" action:nil keyEquivalent:@""];
    [newItem setSubmenu:winBuddyMenu];
    [windowMenu insertItem:newItem atIndex:zoomIdx+2];
}

- (NSMenu*)winBuddyMenuCreate {
    NSMenu *submenuRoot = [[NSMenu alloc] init];
    [submenuRoot setTitle:@""];
    [[submenuRoot addItemWithTitle:@"Hide menubar and dock" action:@selector(_toggleMenubar:) keyEquivalent:@""] setTarget:plugin];
    [[submenuRoot addItemWithTitle:@"Hide window shadows" action:@selector(_toggleShadows:) keyEquivalent:@""] setTarget:plugin];
    [[submenuRoot addItemWithTitle:@"Show window borders" action:@selector(_toggleBorder:) keyEquivalent:@""] setTarget:plugin];
    [[submenuRoot itemAtIndex:0] setState:[ReadPref(@"HideMenubar") boolValue]];
    [[submenuRoot itemAtIndex:1] setState:[ReadPref(@"HideShadow") boolValue]];
    [[submenuRoot itemAtIndex:2] setState:[ReadPref(@"ShowBorder") boolValue]];
    return submenuRoot;
}

@end

@implementation NSWindow (wb_window)

- (void)mf_setupBorder {
    [NotificationCenter addObserver:self selector:@selector(mf_updateBorder)
                               name:NSWindowDidResizeNotification
                             object:self];
    [NotificationCenter addObserver:self selector:@selector(mf_updateBorder)
                               name:NSWindowDidEndSheetNotification
                             object:self];
    
    // Wait till we're onscreen to add borders
    [NotificationCenter addObserver:self selector:@selector(mf_initBorder)
                               name:NSWindowDidUpdateNotification
                             object:self];
}

- (void)mf_initBorder {
    [NotificationCenter removeObserver:self
                                  name:NSWindowDidUpdateNotification
                                object:self];
        
    // Create a child window to keep the border
    NSWindow *child = [[NSWindow alloc] initWithContentRect:self.frame
                                                  styleMask:NSBorderlessWindowMask
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    
    NSRect bounds  = { NSZeroPoint, self.frame.size };
    NSBox *border  = [[NSBox alloc] initWithFrame:bounds];
    border.boxType = NSBoxCustom;
    border.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    border.borderType = NSLineBorder;
    border.borderColor = [NSColor blackColor];
    border.borderWidth = 1;
    child.contentView = border;
    child.ignoresMouseEvents = YES;
    child.movableByWindowBackground = NO;
    child.opaque = NO;
    child.backgroundColor = [NSColor clearColor];
    [child setHidesOnDeactivate:NO];
    [child useOptimizedDrawing:YES];
    [child setReleasedWhenClosed:false];
    [self addChildWindow:child ordered:NSWindowAbove];
    
    objc_setAssociatedObject(self, borderKey, child, OBJC_ASSOCIATION_RETAIN);
    
    [NotificationCenter addObserver:self selector:@selector(mf_releaseChild)
                               name:NSWindowWillCloseNotification
                             object:self];
    
    [NotificationCenter addObserver:self selector:@selector(mf_updateBorder)
                               name:NSWindowDidBecomeKeyNotification
                             object:self];
    [NotificationCenter addObserver:self selector:@selector(mf_updateBorder)
                               name:NSWindowDidResignKeyNotification
                             object:self];
    
    [self mf_updateBorder];
}

- (void)mf_releaseChild {
    [NotificationCenter removeObserver:self
                                  name:NSWindowWillCloseNotification
                                object:self];
    [NotificationCenter removeObserver:self
                                  name:NSWindowDidResizeNotification
                                object:self];
    [NotificationCenter removeObserver:self
                                  name:NSWindowDidEndSheetNotification
                                object:self];
    [NotificationCenter removeObserver:self
                                  name:NSWindowDidBecomeKeyNotification
                                object:self];
    [NotificationCenter removeObserver:self
                                  name:NSWindowDidResignKeyNotification
                                object:self];

    [NotificationCenter addObserver:self selector:@selector(mf_setupBorder)
                               name:NSWindowDidBecomeKeyNotification
                             object:self];
    
    NSWindow *borderWin = objc_getAssociatedObject(self, borderKey);
    [borderWin close];
}

- (void)mf_updateBorder {
    NSWindow *borderWin = objc_getAssociatedObject(self, borderKey);
    [borderWin.contentView setBorderColor:self.isKeyWindow ? [NSColor redColor] : [NSColor blackColor]];
    [borderWin setFrame:self.frame display:YES];
    if (![ReadPref(@"ShowBorder") boolValue])
            [borderWin.contentView setBorderColor:[NSColor clearColor]];
}

@end
