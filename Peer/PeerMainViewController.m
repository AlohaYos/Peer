//
//  PeerMainViewController.m
//  Peer
//
//  Copyright (c) 2014 Newton Japan. All rights reserved.
//

#import "PeerMainViewController.h"

@interface PeerMainViewController ()
@property (weak, nonatomic) IBOutlet UITextField *peernameTextField;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@end

@implementation PeerMainViewController
{
	MCNearbyServiceAdvertiser	*_nearbyServiceAdvertiser;
	MCPeerID					*_peerID;
	MCSession					*_session;
	NSProgress					*_progress;

    CBPeripheralManager			*_peripheralManager;

	NSURL						*_photoURL;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	_photoURL = nil;
	
	[self getPeerID];
	_peerID = [[MCPeerID alloc] initWithDisplayName:self.peernameTextField.text];
	_session = [[MCSession alloc] initWithPeer:_peerID];
	_session.delegate = (id<MCSessionDelegate>)self;

	_peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
}

- (void)viewDidAppear:(BOOL)animated {
	[self startAdvertise];
	_session.delegate = (id<MCSessionDelegate>)self;
	
	[self beaconing:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
	[self stopAdvertise];

	[self beaconing:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Flipside View

- (void)flipsideViewControllerDidFinish:(PeerFlipsideViewController *)controller {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showAlternate"]) {
        [[segue destinationViewController] setDelegate:self];
		PeerFlipsideViewController *flipVC = [segue destinationViewController];
		flipVC.peerID = _peerID;
		flipVC.session = _session;
    }
}

#pragma mark - Photo pickup

- (IBAction)selectPhotoButtonPushed:(id)sender {
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.delegate = (id<UINavigationControllerDelegate, UIImagePickerControllerDelegate>)self;
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	[self presentViewController:picker animated:YES completion:nil];
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	self.imageView.image = (UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage];
	NSData *imageData = UIImageJPEGRepresentation(self.imageView.image, 1.0);
	NSString* copyPath=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/tempImage.jpg"];
	NSError *error;
	if([[NSFileManager defaultManager] fileExistsAtPath:copyPath] == YES) {
		[[NSFileManager defaultManager] removeItemAtPath:copyPath error:&error];
	}
	[imageData writeToFile:copyPath atomically:YES];
	
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Beacon job

-(void)beaconing:(BOOL)flag {
	NSUUID		*uuid = [[NSUUID alloc] initWithUUIDString:@"E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"];
	CLBeaconRegion *region = [[CLBeaconRegion alloc]
							  initWithProximityUUID:uuid
							  identifier:[uuid UUIDString]];
	
	NSDictionary *peripheralData = [region peripheralDataWithMeasuredPower:nil];
	
	switch (flag) {
		case YES:
			[_peripheralManager startAdvertising:peripheralData];
			break;
		case NO:
			[_peripheralManager stopAdvertising];
			break;
	}
	
}

#pragma mark - Advertiser job

- (void)startAdvertise {
	
	NSDictionary *discoveryInfo = [[NSDictionary alloc] initWithObjectsAndKeys:[[UIDevice currentDevice] name],@"device name", nil];
    _nearbyServiceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:_peerID discoveryInfo:discoveryInfo serviceType:@"connect-anyway"];
    _nearbyServiceAdvertiser.delegate = self;
    [_nearbyServiceAdvertiser startAdvertisingPeer];
}

- (void)stopAdvertise {
	[_nearbyServiceAdvertiser stopAdvertisingPeer];
}

#pragma mark - Advertiser delegate job

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error {
    if(error){
        NSLog(@"%@", [error localizedDescription]);
    }
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler {
	NSLog(@"didReceiveInvitationFromPeer");
	
	if([_session.connectedPeers count]==0) {
		NSLog(@"New connection peer[%@-->%@]", peerID.displayName, _peerID.displayName);
	}
	else {
		NSLog(@"Already connected");
	}
	
	invitationHandler(([_session.connectedPeers count]==0?YES:NO), _session);
}

#pragma mark - Session job

- (void)communicateToPeer {
	[self sendMessage:[NSString stringWithFormat:@"Hello from %@", _peerID.displayName]];
	
	NSString* copyPath=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/tempImage.jpg"];
	NSURL *imageUrl = [NSURL fileURLWithPath:copyPath];
	[self sendImage:imageUrl];
}

- (void)sendMessage:(NSString *)message {
    NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;

    [_session sendData:messageData toPeers:_session.connectedPeers withMode:MCSessionSendDataReliable error:&error];
    if (error) {
        NSLog(@"Error sending message to peers [%@]", error);
    }
}

- (void)sendImage:(NSURL *)imageUrl {
    for (MCPeerID *peerID in _session.connectedPeers) {
		if(imageUrl) {
			_progress = [_session sendResourceAtURL:imageUrl withName:[imageUrl lastPathComponent] toPeer:peerID withCompletionHandler:^(NSError *error) {
				if (error) {
					NSLog(@"Send resource to peer [%@] completed with Error [%@]", peerID.displayName, error);
				}
			}];
		}
    }
	
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkProgress) userInfo:nil repeats:NO];
}

#pragma mark - Session delegate job

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
	if(state == MCSessionStateConnected) {
		[self performSelectorOnMainThread:@selector(communicateToPeer) withObject:nil waitUntilDone:NO];
	}
}


- (void)checkProgress {
	if(_progress) {
		self.progressView.progress = _progress.fractionCompleted;
		if(_progress.completedUnitCount < _progress.totalUnitCount) {
			[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkProgress) userInfo:nil repeats:NO];
		}
	}
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    
}

#pragma mark - PeerID edit

- (IBAction)peerEditEnd:(id)sender {
	[self setPeerID];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    return [textField resignFirstResponder];
}

- (void)setPeerID {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.peernameTextField.text forKey:@"peerID"];
}

- (void)getPeerID {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *peerID = [defaults objectForKey:@"peerID"];
	if([peerID length]>0) {
		self.peernameTextField.text = peerID;
	}
}



@end
