#import "ErrorClient.h"
#import "CodeCoordinate.h"
#import "ErrorEntity.h"

#import "Optional.h"
#import "Tools.h"
#import "RavenClient.h"

#import <execinfo.h>

NSString* const k_errorServerURLStringUserDefaultsKey = @"k_errorServerURLStringUserDefaultsKey";

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
        [RavenClient setSharedClient:[RavenClient clientWithDSN:[[NSUserDefaults standardUserDefaults] stringForKey:k_errorServerURLStringUserDefaultsKey]]];
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

+ (void)sendInfo:(NSString *)info {
    [self sendInfo:info coordinate:nil];
}

+ (void)sendInfo:(NSString*)info coordinate:(CodeCoordinate*)coordinate {
    RavenClient* ravenClient = [RavenClient sharedClient];
    if (ravenClient != nil) {
        [ravenClient captureMessage:info
                              level:kRavenLogLevelDebugInfo
                    additionalExtra:nil
                     additionalTags:nil
                             method:coordinate ? coordinate.method : NULL
                               file:coordinate ? coordinate.file : NULL
                               line:coordinate ? coordinate.line : 0];
    }
}

+ (void)sendWarning:(NSString *)warning {
    [self sendWarning:warning coordinate:nil];
}

+ (void)sendWarning:(NSString*)warning coordinate:(CodeCoordinate*)coordinate {
    RavenClient* ravenClient = [RavenClient sharedClient];
    if (ravenClient != nil) {
        [ravenClient captureMessage:warning
                              level:kRavenLogLevelDebugWarning
                    additionalExtra:nil
                     additionalTags:nil
                             method:coordinate ? coordinate.method : NULL
                               file:coordinate ? coordinate.file : NULL
                               line:coordinate ? coordinate.line : 0];
    }
}

+ (void)sendError:(ErrorEntity *)error {
    [self sendError:error coordinate:nil];
}

+ (void)sendError:(ErrorEntity *)error coordinate:(CodeCoordinate*)coordinate {
    RavenClient* ravenClient = [RavenClient sharedClient];
    if (ravenClient != nil) {
        [ravenClient captureMessage:error.text
                              level:kRavenLogLevelDebugError
                    additionalExtra:nil
                     additionalTags:@{ @"custom_tags": error.standardTagsString }
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
