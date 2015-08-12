#import "ErrorClient.h"
#import <UIKit/UIKit.h>

#import "Tools.h"
#import "RavenClient.h"

#import "MessageEntity.h"
#import "CodeCoordinate.h"

#import <execinfo.h>

NSString* const kErrorServerURLStringUserDefaultsKey = @"kErrorServerURLStringUserDefaultsKey";
NSString* const kCustomTagsKey = @"Custom tags";

static NSString* const kCustomUserIdUserDefaultsKey = @"kCustomUserIdUserDefaultsKey";

@interface SignalException : NSException

+ (SignalException*)exceptionWithSignal:(int)signal callStackReturnAddresses:(NSArray*)addresses callStackSymbols:(NSArray*)symbols;

@end

@interface SignalException ()

@property (copy) NSArray* callStackReturnAddresses_;
@property (copy) NSArray* callStackSymbols_;


@end

@implementation SignalException

+ (SignalException*)exceptionWithSignal:(int)signal callStackReturnAddresses:(NSArray*)addresses callStackSymbols:(NSArray*)symbols {
    SignalException* exception = [[SignalException alloc] initWithName:[NSString stringWithFormat:@"Signal Exception %d", signal] reason:@"Terminated due to uncaught exception" userInfo:nil];
    exception.callStackReturnAddresses_ = addresses;
    exception.callStackSymbols_ = symbols;
    return exception;
}

- (NSArray*)callStackReturnAddresses {
    return self.callStackReturnAddresses_;
}

- (NSArray*)callStackSymbols {
    return self.callStackSymbols_;
}

@end

@implementation ErrorClient

+ (void)initialize {
    if (self == [ErrorClient self]) {
        RavenClient* sharedClient = [RavenClient clientWithDSN:[[NSUserDefaults standardUserDefaults] stringForKey:kErrorServerURLStringUserDefaultsKey]];
        NSString* identifierForVendor = [UIDevice currentDevice].identifierForVendor.UUIDString;
        if (identifierForVendor.length > 0) {
            sharedClient.user = @{@"vendor_id": identifierForVendor};
        }
        else {
            NSString* customUserId = [[NSUserDefaults standardUserDefaults] stringForKey:kCustomUserIdUserDefaultsKey];
            if (customUserId.length == 0) {
                customUserId = [Tools randomStringWithLength:16];
                [[NSUserDefaults standardUserDefaults] setObject:customUserId forKey:kCustomUserIdUserDefaultsKey];
            }
            sharedClient.user = @{@"custom_id": customUserId};
        }
        [RavenClient setSharedClient:sharedClient];
    }
}

+ (void)setupExceptionHandler {
    RavenClient* ravenClient = [RavenClient sharedClient];
    if (ravenClient != nil) {
        [ravenClient setupExceptionHandler];
        struct sigaction mySigAction;
        mySigAction.sa_sigaction = signalHandler;
        mySigAction.sa_flags = SA_SIGINFO;
        sigemptyset(&mySigAction.sa_mask);
        sigaction(SIGQUIT, &mySigAction, NULL);
        sigaction(SIGILL, &mySigAction, NULL);
        sigaction(SIGTRAP, &mySigAction, NULL);
        sigaction(SIGABRT, &mySigAction, NULL);
        sigaction(SIGEMT, &mySigAction, NULL);
        sigaction(SIGFPE, &mySigAction, NULL);
        sigaction(SIGBUS, &mySigAction, NULL);
        sigaction(SIGSEGV, &mySigAction, NULL);
        sigaction(SIGSYS, &mySigAction, NULL);
        sigaction(SIGPIPE, &mySigAction, NULL);
        sigaction(SIGALRM, &mySigAction, NULL);
        sigaction(SIGXCPU, &mySigAction, NULL);
        sigaction(SIGXFSZ, &mySigAction, NULL);
    }
}

+ (void)sendInfo:(MessageEntity *)info {
    [self inCoordinate:nil sendInfo:info];
}

+ (void)inCoordinate:(CodeCoordinate*)coordinate sendInfo:(MessageEntity*)info {
    RavenClient* ravenClient = [RavenClient sharedClient];
    if (ravenClient != nil) {
        [ravenClient captureMessage:info.text
                              level:kRavenLogLevelDebugInfo
                    additionalExtra:info.info
                     additionalTags:[@{}
                                     key:kCustomTagsKey optional:info.standardTagsString]
                             method:coordinate ? coordinate.method : NULL
                               file:coordinate ? coordinate.file : NULL
                               line:coordinate ? coordinate.line : 0];
    }
}

+ (void)sendWarning:(MessageEntity *)warning {
    [self inCoordinate:nil sendWarning:warning];
}

+ (void)inCoordinate:(CodeCoordinate*)coordinate sendWarning:(MessageEntity*)warning {
    RavenClient* ravenClient = [RavenClient sharedClient];
    if (ravenClient != nil) {
        [ravenClient captureMessage:warning.text
                              level:kRavenLogLevelDebugWarning
                    additionalExtra:warning.info
                     additionalTags:[@{}
                                     key:kCustomTagsKey optional:warning.standardTagsString]
                             method:coordinate ? coordinate.method : NULL
                               file:coordinate ? coordinate.file : NULL
                               line:coordinate ? coordinate.line : 0];
    }
}

+ (void)sendError:(MessageEntity *)error {
    [self inCoordinate:nil sendError:error];
}

+ (void)inCoordinate:(CodeCoordinate*)coordinate sendError:(MessageEntity *)error {
    RavenClient* ravenClient = [RavenClient sharedClient];
    if (ravenClient != nil) {
        [ravenClient captureMessage:error.text
                              level:kRavenLogLevelDebugError
                    additionalExtra:error.info
                     additionalTags:[@{}
                                     key:kCustomTagsKey optional:error.standardTagsString]
                             method:coordinate ? coordinate.method : NULL
                               file:coordinate ? coordinate.file : NULL
                               line:coordinate ? coordinate.line : 0];
    }
}

+ (void)backtraceAddresses:(NSArray*__autoreleasing*)addresses symbols:(NSArray*__autoreleasing*)symbols {
    void *backtraceFrames[128];
    int frameCount = backtrace(backtraceFrames, 128);
    char **frameStrings = backtrace_symbols(&backtraceFrames[0], frameCount);
    
    NSMutableArray* m_frameReturnAddresses = [NSMutableArray array];
    NSMutableArray* m_frameSymbols = [NSMutableArray array];
    if (frameStrings != NULL) {
        int x = 0;
        for (x = 0; x < frameCount; x++) {
            if(frameStrings[x] == NULL) {
                break;
            }
            int* backtraceFramePointer = backtraceFrames[x];
            int backtraceFrame = *backtraceFramePointer;
            NSNumber* frameReturnAddress = [NSNumber numberWithInt:backtraceFrame];
            [m_frameReturnAddresses addObject:frameReturnAddress];
            NSString* frameNSString = [[NSString alloc] initWithUTF8String:frameStrings[x]];
            [m_frameSymbols addObject:frameNSString];
        }
        free(frameStrings);
    }
    
    if (addresses) {
        *addresses = [NSArray arrayWithArray:m_frameReturnAddresses];
    }
    if (symbols) {
        *symbols = [NSArray arrayWithArray:m_frameSymbols];
    }
}

void signalHandler(int signal, siginfo_t *info, void *context) {
    NSArray* addresses = nil;
    NSArray* symbols = nil;
    [ErrorClient backtraceAddresses:&addresses symbols:&symbols];
    [[RavenClient sharedClient] captureException:[SignalException exceptionWithSignal:signal
                                                             callStackReturnAddresses:addresses
                                                                     callStackSymbols:symbols]
                                         sendNow:NO];
}

@end
