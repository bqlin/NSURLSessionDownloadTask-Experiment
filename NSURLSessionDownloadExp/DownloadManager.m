//
//  DownloadManager.m
//  NSURLSessionDownloadExp
//
//  Created by BqLin on 2017/10/19.
//  Copyright © 2017年 POLYV. All rights reserved.
//

#import "DownloadManager.h"

const NSInteger PLVBackgroundSessionMaxConnection = 1;
const NSTimeInterval PLVBackgroundSessionResourceTimeout = 1200;
const NSTimeInterval PLVBackgroundSessionRequestTimeout = 30;

const NSInteger PLVForegroundSessionMaxConnection = 1;
const NSTimeInterval PLVForegroundSessionResourceTimeout = 1200;
const NSTimeInterval PLVForegroundSessionRequestTimeout = 120;

@interface DownloadManager ()<NSURLSessionDownloadDelegate>

/// 下载会话
@property (nonatomic, strong) NSURLSession *session;

/// 下载任务
@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;

@property (nonatomic, strong) NSData *resumeData;

/// 回调队列
@property (nonatomic, strong) NSOperationQueue *sessionCallbackQueue;

@property (nonatomic, assign) BOOL prepared;

@end

@implementation DownloadManager

#pragma mark - singleton init

static id _sharedManager = nil;

+ (instancetype)sharedManager {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_sharedManager = [[self alloc] init];
		[_sharedManager commonInit];
	});
	return _sharedManager;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if (!_sharedManager) {
			_sharedManager = [super allocWithZone:zone];
		}
	});
	return _sharedManager;
}

- (id)copyWithZone:(NSZone *)zone {
	return _sharedManager;
}

- (void)commonInit {
}

#pragma mark - download

- (void)prepareWithCompletion:(void (^)())completion {
	if (self.prepared) {
		completion();
		return;
	}
	if (!self.session) {
		self.session = [self createSession];
	}
	if (!self.downloadTask) {
		if (self.resumeData) {
			self.downloadTask = [self.session downloadTaskWithResumeData:self.resumeData];
		} else {
			self.downloadTask = [self.session downloadTaskWithURL:[NSURL URLWithString:self.downloadUrl]];
		}
	}
	self.prepared = YES;
	completion();
}

- (void)startDownload {
	[self.downloadTask resume];
}

- (void)stopDownload {
	__weak typeof(self) weakSelf = self;
	[self.downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
		if (!resumeData) return;
		// 移除 NSURLSessionResumeByteRange
		NSMutableDictionary *resumeDic = [self dictionaryWithData:resumeData].mutableCopy;
		[resumeDic removeObjectForKey:@"NSURLSessionResumeByteRange"];
		weakSelf.resumeData = [self dataWithDictionary:resumeDic];
		
		[weakSelf reset];
	}];
}

- (void)reset {
	self.downloadTask = nil;
	self.prepared = NO;
}

- (BOOL)removeDownloadedFile {
	NSString *fileName = self.downloadUrl.lastPathComponent;
	NSString *destinationPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:fileName];
	NSError *error = nil;
	BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:&error];
	if (error) {
		NSLog(@"remove error: %@", error);
	}
	return removed;
}

#pragma mark create session
/// 创建会话
- (NSURLSession *)createSession {
	NSURLSession *session = nil;
	session = [self backgroundSession];
	return session;
}
/// 前台会话
- (NSURLSession *)foregroundSession {
	NSURLSessionConfiguration *foregroundSessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
	foregroundSessionConfig.HTTPMaximumConnectionsPerHost = PLVForegroundSessionMaxConnection;
	foregroundSessionConfig.timeoutIntervalForResource = PLVForegroundSessionResourceTimeout;
	foregroundSessionConfig.timeoutIntervalForRequest = PLVForegroundSessionRequestTimeout;
	NSOperationQueue *sessionQueue = [[NSOperationQueue alloc] init];
	sessionQueue.maxConcurrentOperationCount = 1;
	self.sessionCallbackQueue = sessionQueue;
	return [NSURLSession sessionWithConfiguration:foregroundSessionConfig delegate:self delegateQueue:sessionQueue];
}
/// 后台会话
- (NSURLSession *)backgroundSession {
	NSString *bgsessionID = [NSString stringWithFormat:@"net.polyv.sdk.download.bgsession"];
	NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:bgsessionID];
	config.HTTPMaximumConnectionsPerHost = PLVBackgroundSessionMaxConnection;	//一个host最大并发连接数
	config.timeoutIntervalForResource = PLVBackgroundSessionResourceTimeout;	//限制整个资源的请求时长
	config.timeoutIntervalForRequest = PLVBackgroundSessionRequestTimeout;		//每次有新的data请求到会被重置
	config.discretionary = NO;
	config.sessionSendsLaunchEvents = YES;
	NSOperationQueue *sessionQueue = [[NSOperationQueue alloc] init];
	sessionQueue.maxConcurrentOperationCount = 1;
	self.sessionCallbackQueue = sessionQueue;
	return [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:sessionQueue];
}

#pragma mark NSURLSessionDownloadDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
	double progress = 1.0 * totalBytesWritten / totalBytesExpectedToWrite;
	if (self.progressHandler) {
		self.progressHandler(progress);
	}
	NSString *progressDescription = [NSNumberFormatter localizedStringFromNumber:@(progress) numberStyle:NSNumberFormatterPercentStyle];
	NSLog(@"progress: %@\t\t%lld/%lld", progressDescription, totalBytesWritten, totalBytesExpectedToWrite);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes {
	NSLog(@"%@ - %lld - %lld", downloadTask, fileOffset, expectedTotalBytes);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
	NSString *fileName = downloadTask.response.suggestedFilename;
	NSString *destinationPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:fileName];
	NSLog(@"%@", destinationPath);
	NSError *error = nil;
	[[NSFileManager defaultManager] moveItemAtPath:location.path toPath:destinationPath error:nil];
	if (error) {
		NSLog(@"move error: %@", error);
	}
	[self reset];
}

#pragma mark NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
	
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
	
}

#pragma mark NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
	
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
	if (self.backgroundCompletionHandler) {
		void (^completionHandler)(void) = self.backgroundCompletionHandler;
		self.backgroundCompletionHandler = nil;
		completionHandler();
	}
	
	NSLog(@"All tasks are finished");
}

#pragma mark - tool

- (NSDictionary *)dictionaryWithData:(NSData *)data {
	CFPropertyListFormat plistFormat = kCFPropertyListXMLFormat_v1_0;
	CFPropertyListRef plist = CFPropertyListCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)data, kCFPropertyListImmutable, &plistFormat, NULL);
	if ([(__bridge id)plist isKindOfClass:[NSDictionary class]]) {
		return (__bridge NSDictionary *)plist;
	} else {
		CFRelease(plist);
		return nil;
	}
}

- (NSData *)dataWithDictionary:(NSDictionary *)dic {
	CFDataRef data = CFPropertyListCreateData(kCFAllocatorDefault, (__bridge CFPropertyListRef)dic, kCFPropertyListXMLFormat_v1_0, kCFPropertyListImmutable, NULL);
	if ([(__bridge id)data isKindOfClass:[NSData class]]) {
		return (__bridge NSData *)data;
	} else {
		CFRelease(data);
		return nil;
	}
}

@end
