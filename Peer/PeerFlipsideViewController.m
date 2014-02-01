//
//  PeerFlipsideViewController.m
//  Peer
//
//  Copyright (c) 2014 Newton Japan. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import "PeerFlipsideViewController.h"

@interface PeerFlipsideViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) id <PeerFlipsideViewControllerDelegate> delegate;
@property (strong, nonatomic) NSString	*peernameText;
@end

@implementation PeerFlipsideViewController
{
	MCNearbyServiceBrowser	*_nearbyServiceBrowser;
	NSProgress				*_progress;

	CLLocationManager		*_locationManager;
	NSUUID					*_uuid;
	CLBeaconRegion			*_region;
    NSMutableArray			*_beacons;
}

- (void)viewDidLoad {
    [super viewDidLoad];

	_uuid = [[NSUUID alloc] initWithUUIDString:@"E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"];
	_region = [[CLBeaconRegion alloc] initWithProximityUUID:_uuid identifier:[_uuid UUIDString]];
	_locationManager = [[CLLocationManager alloc] init];
	_locationManager.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated {
	_session.delegate = self;
	[_locationManager startRangingBeaconsInRegion:_region];
}

- (void)viewDidDisappear:(BOOL)animated {
	[_locationManager stopRangingBeaconsInRegion:_region];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Actions

- (IBAction)done:(id)sender {
	[_locationManager stopRangingBeaconsInRegion:_region];
	[self stopBrowsing];
    [self.delegate flipsideViewControllerDidFinish:self];
}

#pragma mark - Beacon job

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
	for(CLBeacon *beacon in beacons) {
		if((beacon.proximity == CLProximityNear)||(beacon.proximity == CLProximityImmediate)) {
			if(_nearbyServiceBrowser==nil) {
				AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
				[self startBrowsing];
			}
		}
	}
}

#pragma mark - Browser job

- (void)startBrowsing {
	_nearbyServiceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:_peerID serviceType:@"connect-anyway"];
	_nearbyServiceBrowser.delegate = self;
	[_nearbyServiceBrowser startBrowsingForPeers];
}

- (void)stopBrowsing {
	[_nearbyServiceBrowser stopBrowsingForPeers];
}

#pragma mark - Browser delegate job

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error {
    if(error){
        NSLog(@"[error localizedDescription] %@", [error localizedDescription]);
    }
}

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info {
	if([_session.connectedPeers count] == 0) {
		if(![peerID.displayName isEqualToString:self.peernameText]) {
			NSLog(@"Send invitation peer[%@-->%@]", _peerID.displayName, peerID.displayName);
			[_nearbyServiceBrowser invitePeer:peerID toSession:_session withContext:[@"Welcome" dataUsingEncoding:NSUTF8StringEncoding] timeout:10];
		}
	}
	else {
		NSLog(@"Already connected to other peer");
	}
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
	NSLog(@"lost peer : %@", peerID.displayName);
}

#pragma mark - Session delegate job

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    NSString *receivedMessage = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];
    NSLog(@"Peer [%@] receive data (%@)", peerID.displayName, receivedMessage);
	self.messageLabel.text = receivedMessage;
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    NSLog(@"Received data over stream with name %@ from peer %@", streamName, peerID.displayName);
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    NSLog(@"Start receiving resource [%@] from peer %@ with progress [%@]", resourceName, peerID.displayName, progress);
	_progress = progress;
	[self performSelectorOnMainThread:@selector(checkProgress) withObject:nil waitUntilDone:NO];
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
	NSLog(@"session:didFinishReceivingResourceWithName");
    if (!error)     {
		NSString* copyPath=[NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@", resourceName]];
		NSError *error;
		if([[NSFileManager defaultManager] fileExistsAtPath:copyPath] == YES) {
			[[NSFileManager defaultManager] removeItemAtPath:copyPath error:&error];
		}
		
        if (![[NSFileManager defaultManager] copyItemAtPath:[localURL path] toPath:copyPath error:nil]) {
            NSLog(@"Error copying resource to documents directory");
        }
        else {
			self.imageView.image = [UIImage imageWithContentsOfFile:copyPath];
        }
    }
}

- (void)checkProgress {
	self.progressView.progress = _progress.fractionCompleted;
	if(_progress.completedUnitCount < _progress.totalUnitCount) {
		[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(checkProgress) userInfo:nil repeats:NO];
	}
}



@end
