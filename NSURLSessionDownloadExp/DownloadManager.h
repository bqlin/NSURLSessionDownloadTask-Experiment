//
//  DownloadManager.h
//  NSURLSessionDownloadExp
//
//  Created by BqLin on 2017/10/19.
//  Copyright © 2017年 POLYV. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DownloadManager : NSObject

@property (nonatomic, copy) NSString *downloadUrl;

@property (nonatomic, copy) void (^backgroundCompletionHandler)(void);

@property (nonatomic, copy) void (^progressHandler)(double progress);

+ (instancetype)sharedManager;

- (void)prepareWithCompletion:(void (^)())completion;

- (void)startDownload;
- (void)stopDownload;

/// 移除已下载的文件
- (BOOL)removeDownloadedFile;

@end
