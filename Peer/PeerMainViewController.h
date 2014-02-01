//
//  PeerMainViewController.h
//  Peer
//
//  Copyright (c) 2014 Newton Japan. All rights reserved.
//

#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "PeerFlipsideViewController.h"

@interface PeerMainViewController : UIViewController <PeerFlipsideViewControllerDelegate, MCNearbyServiceAdvertiserDelegate, UIImagePickerControllerDelegate, CBPeripheralManagerDelegate>

@end
