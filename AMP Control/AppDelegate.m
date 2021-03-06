//
//  AppDelegate.m
//  AMP Control
//
//  Created by Lars Häuser on 26.03.14.
//  Copyright (c) 2014 Lars Häuser. All rights reserved.
//

#import "AppDelegate.h"



@implementation AppDelegate

@synthesize apacheButton, apacheIndi,
            mysqlButton, mysqlIndi,
            recheck,
            mysqlIndiCell, apacheIndiCell,
            apacheLabel, mysqlLabel, apacheCircIndi, mysqlCircIndi,
            tile;

NSString *const APACHESTART = @"Apache start";
NSString *const APACHESTOP = @"Apache stop";
NSString *const MYSQLSTART = @"MySQL start";
NSString *const MYSQLSTOP = @"MySQL stop";

- (id)init
{
    self = [super init];
    if (self)
    {
        tile = [[NSApplication sharedApplication] dockTile];
    }
    return self;
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [apacheCircIndi setDisplayedWhenStopped:NO];
    [mysqlCircIndi setDisplayedWhenStopped:NO];
    [apacheIndiCell setDoubleValue:1];
    [mysqlIndiCell setDoubleValue:1];
    
    [self checkBoth];
}

- (void) startApache {
    [apacheCircIndi startAnimation:self];
    NSString *command;
    if (apacheButton.title == APACHESTOP) {
        command = @"stop";
    } else if (apacheButton.title == APACHESTART) {
        command = @"start";
    }
    
    NSString * output = nil;
    NSString * processErrorDescription = nil;
    [self runProcessAsAdministrator:@"apachectl"
                      withArguments:[NSArray arrayWithObjects:command, nil]
                             output:&output
                   errorDescription:&processErrorDescription];
    
    [self checkBoth];
    
}

- (void) startMySql {
    
    [mysqlCircIndi startAnimation:self];
    NSString *command;
    
    if ([mysqlButton.title isEqualToString: MYSQLSTOP]) {
        command = @"stop";
    } else if ([mysqlButton.title isEqualToString: MYSQLSTART]) {
        command = @"start";
    }
    runCommand([NSString stringWithFormat:@"/usr/local/opt/mysql/bin/mysql.server %@", command]);
    
    [self checkBoth];
    
}

-(void) checkBoth
{
    BOOL mr = [self checkIfMysqlIsRunning];
    BOOL ar = [self checkIfApacheIsRunning];
    
    if(mr && ar)
    {
        [tile setBadgeLabel:@"both"];
    }
    else if (ar)
    {
        [tile setBadgeLabel:@"Apache"];
    }
    else if (mr)
    {
        [tile setBadgeLabel:@"MySQL"];
    }
}

- (BOOL) checkIfApacheIsRunning {
    // wait a seconf to look for pid
    [NSThread sleepForTimeInterval:1.0f];
    //grep http
    NSString *output = runCommand(@"ps ax | grep httpd | grep -v grep");
    BOOL running = true;
    if([output length] > 0)
    {
        // get pid number
        [apacheLabel setStringValue: runCommand(@"tail /private/var/run/httpd.pid")];
        [apacheButton setTitle: APACHESTOP];
        [apacheIndiCell setDoubleValue:3];
        running = true;
    }
    else
    {
        [apacheLabel setStringValue: @""];
        [apacheButton setTitle: APACHESTART];
        [apacheIndiCell setDoubleValue:1];
        running = false;
    }
    [apacheCircIndi stopAnimation:self];
    return running;
}

- (BOOL) checkIfMysqlIsRunning {
    // wait a seconf to look for pid
    [NSThread sleepForTimeInterval:1.0f];
    //grep http
    NSString *output = runCommand(@"ps ax | grep mysql | grep -v grep");
    BOOL running = true;
    if([output length] > 0)
    {
        // get name of host to find correct pid file
        NSString *hn = runCommand(@"HOSTNAME");
        
        NSString *complete = [NSString stringWithFormat:@"tail /usr/local/var/mysql/%@.pid", [hn stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        // get pid number
        [mysqlLabel setStringValue: runCommand(complete)];
        //NSLog(pidfilepath);
        
        [mysqlButton setTitle: MYSQLSTOP];
        [mysqlIndiCell setDoubleValue:3];
        running = true;
    }
    else
    {
        [mysqlLabel setStringValue: @""];
        [mysqlButton setTitle: MYSQLSTART];
        [mysqlIndiCell setDoubleValue:1];
        running = false;
    }
    [mysqlCircIndi stopAnimation:self];
    return running;
}

- (IBAction)apacheStartButton:(id)sender {
    [self startApache];
}

- (IBAction)mysqlStartButton:(id)sender {
    [self startMySql];
}

- (IBAction)recheck:(id)sender {
    [apacheCircIndi startAnimation:self];
    [mysqlCircIndi startAnimation:self];
    [self checkBoth];
}

- (BOOL) runProcessAsAdministrator:(NSString*)scriptPath
                     withArguments:(NSArray *)arguments
                            output:(NSString **)output
                  errorDescription:(NSString **)errorDescription {
    
    NSString * allArgs = [arguments componentsJoinedByString:@" "];
    NSString * fullScript = [NSString stringWithFormat:@"'%@' %@", scriptPath, allArgs];
    
    NSDictionary *errorInfo = [NSDictionary new];
    NSString *script =  [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", fullScript];
    
    NSAppleScript *appleScript = [[NSAppleScript new] initWithSource:script];
    NSAppleEventDescriptor * eventResult = [appleScript executeAndReturnError:&errorInfo];
    
    // Check errorInfo
    if (! eventResult)
    {
        // Describe common errors
        *errorDescription = nil;
        if ([errorInfo valueForKey:NSAppleScriptErrorNumber])
        {
            NSNumber * errorNumber = (NSNumber *)[errorInfo valueForKey:NSAppleScriptErrorNumber];
            if ([errorNumber intValue] == -128)
                *errorDescription = @"The administrator password is required to do this.";
        }
        
        // Set error message from provided message
        if (*errorDescription == nil)
        {
            if ([errorInfo valueForKey:NSAppleScriptErrorMessage])
                *errorDescription =  (NSString *)[errorInfo valueForKey:NSAppleScriptErrorMessage];
        }
        
        return NO;
    }
    else
    {
        // Set output to the AppleScript's output
        *output = [eventResult stringValue];
        
        return YES;
    }
}

NSString *removeNewLine(NSString *string)
{
    NSArray* newLineChars = [NSArray arrayWithObjects:@"\\u000A", @"\\u000B",@"\\u000C",@"\\u000D",@"\\u0085",nil];
    
    for( NSString* nl in newLineChars )
        string = [string stringByReplacingOccurrencesOfString: nl withString:@""];
    
    return string;
}

NSString *runCommand(NSString *commandToRun)
{
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: @"/bin/bash"];
    
    NSArray *arguments = [NSArray arrayWithObjects:
                          @"-c" ,
                          [NSString stringWithFormat:@"%@", commandToRun],
                          nil];
    NSLog(@"run command: %@",commandToRun);
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *output;
    output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
    return output;
}

@end
