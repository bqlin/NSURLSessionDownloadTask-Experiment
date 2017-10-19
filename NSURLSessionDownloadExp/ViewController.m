//
//  ViewController.m
//  NSURLSessionDownloadExp
//
//  Created by BqLin on 2017/10/19.
//  Copyright © 2017年 POLYV. All rights reserved.
//

#import "ViewController.h"
#import "DownloadManager.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIProgressView *downloadProgressView;

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	__weak typeof(self) weakSelf = self;
	DownloadManager *manager = [DownloadManager sharedManager];
	// https://raw.githubusercontent.com/bqlin/temp/master/MotionEffects.zip
	// https://ws25.videocc.net/f46ead66de/package_f46ead66deeb2ffc2c56aceb39005917_3.zip
	manager.downloadUrl = @"https://raw.githubusercontent.com/bqlin/temp/master/MotionEffects.zip";
	manager.progressHandler = ^(double progress) {
		dispatch_async(dispatch_get_main_queue(), ^{
			weakSelf.downloadProgressView.progress = progress;
		});
	};
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (IBAction)startDownload:(UIBarButtonItem *)sender {
	DownloadManager *manager = [DownloadManager sharedManager];
	[manager prepareWithCompletion:^{
		[manager startDownload];
	}];
}

- (IBAction)stopDownload:(UIBarButtonItem *)sender {
	DownloadManager *manager = [DownloadManager sharedManager];
	[manager stopDownload];
}

- (IBAction)clear:(UIBarButtonItem *)sender {
	DownloadManager *manager = [DownloadManager sharedManager];
	[manager removeDownloadedFile];
	self.downloadProgressView.progress = 0;
}

@end
