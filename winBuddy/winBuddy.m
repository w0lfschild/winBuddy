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

#define APP_BLACKLIST @[@"com.apple.loginwindow", @"com.apple.notificationcenterui", @"com.apple.OSDUIHelper", @"com.apple.controlstrip"]
#define CLS_BLACKLIST @[@"TDesktopWindow", @"NSStatusBarWindow", @"NSCarbonMenuWindow", @"BookmarkBarFolderWindow", @"TShrinkToFitWindow", @"QLFullscreenWindow", @"QLPreviewPanel", @"NCRemoteViewServiceWindow"]

#define PrefKey(key)  (@"winBuddy_" key)
#define ReadPref(key) [Defaults objectForKey:PrefKey(key)]
#define WritePref(key, value) [Defaults setObject:(value) forKey:PrefKey(key)]

static const char * const borderKey = "wwb_border";
static const char * const stylesKey = "wwb_styles";


@interface winBuddy : NSObject
- (void)_updateMenubarState;
- (IBAction)_toggleMenubar:(id)sender;
- (IBAction)_toggleShadows:(id)sender;
- (IBAction)_toggleBorder:(id)sender;
@end

@interface NSWindow (wb_window)
- (void)wwb_setupBorder;
- (void)wwb_initBorder;
- (void)wwb_updateBorder;
- (void)wwb_updateTitleBar;
@end

winBuddy    *plugin;
NSMenu      *winBuddyMenu;
static void *isActive = &isActive;

@implementation winBuddy

+ (winBuddy*) sharedInstance {
    static winBuddy* plugin = nil;
    
    if (plugin == nil)
        plugin = [[winBuddy alloc] init];
    
    return plugin;
}

+ (void)load {
    plugin = [winBuddy sharedInstance];
    NSUInteger osx_ver = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
    
//    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
//    NSString *processName = [processInfo processName];
//    int processID = [processInfo processIdentifier];
//    NSLog(@"wb_ Process Name: '%@' Process ID:'%d'", processName, processID);
    
    if (osx_ver >= 9) {
        if (![APP_BLACKLIST containsObject:[[NSBundle mainBundle] bundleIdentifier]]) {
            NSLog(@"Loading winBuddy...");
            
            [Defaults registerDefaults:@{ PrefKey(@"HideMenubar"): @NO }];
            [Defaults registerDefaults:@{ PrefKey(@"HideShadow"): @YES }];
            [Defaults registerDefaults:@{ PrefKey(@"HideTitleBar"): @NO }];
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
        } else {
            NSLog(@"winBuddy is blocked in this application because of issues");
        }
    } else {
        NSLog(@"winBuddy is blocked in this application because of your version of macOS is too old");
    }
}

- (void)winBuddy_WindowDidBecomeKey:(NSNotification *)notification {
    [plugin winBuddy_initialize:[notification object]];
}

- (void)winBuddy_initialize:(NSWindow*)theWindow {
//    NSLog(@"wb_ %@", [theWindow className]);
    if (![CLS_BLACKLIST containsObject:[theWindow className]]) {
        if (![objc_getAssociatedObject(theWindow, isActive) boolValue]) {
            // Don't load in preference panes
            if ([[[NSProcessInfo processInfo] processName] rangeOfString:@"com.apple.preference"].location == NSNotFound) {
                if (ReadPref(@"HideShadow") != nil)
                    theWindow.hasShadow = ![ReadPref(@"HideShadow") boolValue];
                [plugin _updateMenubarState];
                [theWindow wwb_setupBorder];
                [theWindow wwb_updateTitleBar];
                objc_setAssociatedObject(theWindow, isActive, [NSNumber numberWithBool:true], OBJC_ASSOCIATION_RETAIN);
            }
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
        [window wwb_updateBorder];
}

- (void)_updateTitleBarState {
    for(NSWindow *window in [NSApp windows])
        [window wwb_updateTitleBar];
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

- (IBAction)_toggleTitleBar:(id)sender {
    WritePref(@"HideTitleBar", @(![ReadPref(@"HideTitleBar") boolValue]));
    [sender setState:[ReadPref(@"HideTitleBar") boolValue]];
    [self _updateTitleBarState];
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
    [[submenuRoot addItemWithTitle:@"Hide window title bar" action:@selector(_toggleTitleBar:) keyEquivalent:@""] setTarget:plugin];
    [[submenuRoot addItemWithTitle:@"Show window borders" action:@selector(_toggleBorder:) keyEquivalent:@""] setTarget:plugin];
    [[submenuRoot itemAtIndex:0] setState:[ReadPref(@"HideMenubar") boolValue]];
    [[submenuRoot itemAtIndex:1] setState:[ReadPref(@"HideShadow") boolValue]];
    [[submenuRoot itemAtIndex:2] setState:[ReadPref(@"HideTitleBar") boolValue]];
    [[submenuRoot itemAtIndex:3] setState:[ReadPref(@"ShowBorder") boolValue]];
    return submenuRoot;
}

@end

@implementation NSWindow (wb_window)

- (void)wwb_setupBorder {
    [NotificationCenter addObserver:self selector:@selector(wwb_updateBorder)
                               name:NSWindowDidResizeNotification
                             object:self];
    [NotificationCenter addObserver:self selector:@selector(wwb_updateBorder)
                               name:NSWindowDidEndSheetNotification
                             object:self];
    
    // Wait till we're onscreen to add borders
    [NotificationCenter addObserver:self selector:@selector(wwb_initBorder)
                               name:NSWindowDidUpdateNotification
                             object:self];
    
    [NotificationCenter addObserver:self selector:@selector(wwb_fscreen:) name:NSWindowDidEnterFullScreenNotification object:nil];
}

- (void)wwb_initBorder {
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
    
    [NotificationCenter addObserver:self selector:@selector(wwb_releaseChild)
                               name:NSWindowWillCloseNotification
                             object:self];
    
    [NotificationCenter addObserver:self selector:@selector(wwb_updateBorder)
                               name:NSWindowDidBecomeKeyNotification
                             object:self];
    [NotificationCenter addObserver:self selector:@selector(wwb_updateBorder)
                               name:NSWindowDidResignKeyNotification
                             object:self];
    
    [self wwb_updateBorder];
}

- (void)wwb_releaseChild {
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

    [NotificationCenter addObserver:self selector:@selector(wwb_setupBorder)
                               name:NSWindowDidBecomeKeyNotification
                             object:self];
    
    NSWindow *borderWin = objc_getAssociatedObject(self, borderKey);
    [borderWin close];
}

- (void)wwb_fscreen:(NSNotification *)note {
    NSWindow *borderWin = objc_getAssociatedObject(self, borderKey);
    [borderWin.contentView setBorderColor:[NSColor clearColor]];
}

- (void)wwb_updateTitleBar {
    NSWindow *savedStyle = objc_getAssociatedObject(self, stylesKey);
    if (savedStyle == nil) {
        savedStyle = [[NSWindow alloc] init];
        savedStyle.styleMask = self.styleMask;
        objc_setAssociatedObject(self, stylesKey, savedStyle, OBJC_ASSOCIATION_RETAIN);
    }
    if ([ReadPref(@"HideTitleBar") boolValue]) {
        if (self.toolbar != nil) {
            self.titleVisibility = true;
        } else {
            NSWindow *styles = [[NSWindow alloc] init];
            styles.styleMask = self.styleMask;
            objc_setAssociatedObject(self, stylesKey, styles, OBJC_ASSOCIATION_RETAIN);
            self.styleMask = NSBorderlessWindowMask;
        }
    } else {
        if (self.toolbar != nil) {
            self.titleVisibility = false;
        } else {
            NSWindow *styles = objc_getAssociatedObject(self, stylesKey);
            self.styleMask = styles.styleMask;
        }
    }
}

- (void)wwb_updateBorder {
//    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
//    NSString *processName = [processInfo processName];
//    int processID = [processInfo processIdentifier];
//    NSLog(@"wb_ %@", self.className);
//    NSLog(@"wb_ Process Name: '%@' Process ID:'%d'", processName, processID);

    NSWindow *borderWin = objc_getAssociatedObject(self, borderKey);
    [borderWin.contentView setBorderColor:self.isKeyWindow ? [NSColor redColor] : [NSColor blackColor]];
    [borderWin setFrame:self.frame display:YES];
    if (![ReadPref(@"ShowBorder") boolValue])
        [borderWin.contentView setBorderColor:[NSColor clearColor]];
}

@end
