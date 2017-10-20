# NSURLSessionDownloadTask-Experiment
使用 NSURLSessionDownloadTask 做断点下载，在 iOS 11 上出现下载文件不完整问题。

## 问题复现

- 在 iOS 11 下，使用 NSURLSessionDownloadTask 创建下载任务，开始；
- 调用 `-cancelByProducingResumeData:`，停止并存储 resumeData；
- 调用`-downloadTaskWithResumeData:`，传入存储的 resumeData，创建任务，`-resume`开始下载；
- 重复②③三次，问题就会重现。

## 问题表现

在下载任务回调`-URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:`，第三次下载时 `totalBytesExpectedToWrite` 值就会变为 `总大小 - 已下载大小`。

## 问题修复

去除 resumeData 中去除`NSURLSessionResumeByteRange`字段。

```objective-c
- (void)stopDownload {
	__weak typeof(self) weakSelf = self;
	[self.downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
		// 移除 NSURLSessionResumeByteRange
		NSMutableDictionary *resumeDic = [self dictionaryWithData:resumeData].mutableCopy;
		[resumeDic removeObjectForKey:@"NSURLSessionResumeByteRange"];
		weakSelf.resumeData = [self dataWithDictionary:resumeDic];
		
		[weakSelf reset];
	}];
}
```