//
//  PeerFlipsideViewController.h
//  Peer
//
//  Copyright (c) 2014 Newton Japan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <CoreLocation/CoreLocation.h>

@class PeerFlipsideViewController;

@protocol PeerFlipsideViewControllerDelegate
- (void)flipsideViewControllerDidFinish:(PeerFlipsideViewController *)controller;
@end

@interface PeerFlipsideViewController : UIViewController <MCNearbyServiceBrowserDelegate, MCSessionDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) MCPeerID	*peerID;
@property (strong, nonatomic) MCSession	*session;

@end
