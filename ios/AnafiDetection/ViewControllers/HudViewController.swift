//
//  HudViewController.swift
//  ParrotDemo
//
//  Created by ian timmis on 7/18/19.
//  Copyright © 2019 RIIS. All rights reserved.
//

import UIKit
import GroundSdk
import TensorFlowLite

class HudViewController: UIViewController {
    
    @IBOutlet weak var takeoffLandButton: UIButton!
    @IBOutlet weak var streamView: StreamView!
    @IBOutlet weak var overlayView: OverlayView!
    
    private let groundSdk = GroundSdk()
    private var droneUid: String?
    private var drone: Drone?
    private var streamServerRef: Ref<StreamServer>?
    private var liveStreamRef: Ref<CameraLive>?
    
    private var modelDataHandler: ModelDataHandler =
    ModelDataHandler(modelFileInfo: MobileNetSSD.modelInfo, labelsFileInfo: MobileNetSSD.labelsInfo)!
    
    private let displayFont = UIFont.systemFont(ofSize: 6.0, weight: .medium)
    private let edgeOffset: CGFloat = 2.0
    private let labelOffset: CGFloat = 10.0
    
    let takeOffButtonImage = UIImage(named: "ic_flight_takeoff_48pt")
    let landButtonImage = UIImage(named: "ic_flight_land_48pt")
    let handButtonImage = UIImage(named: "ic_flight_hand_48pt")
    
    private var pilotingItf: Ref<ManualCopterPilotingItf>?

    /**
     Responds to the view loading. We setup landscape orientation here.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        let value = UIInterfaceOrientation.landscapeRight.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    /**
     View will appear. We get the drone and setup the interfaces to it. If
     the drone disconnects, we push back to the home viewcontroller.
     */
    override func viewWillAppear(_ animated: Bool) {
        // get the drone
        if let droneUid = droneUid {
            drone = groundSdk.getDrone(uid: droneUid) { [unowned self] _ in
                self.dismiss(self)
            }
        }
        
        if let drone = drone {
            initDroneRefs(drone)
        } else {
            dismiss(self)
        }
    }
    
    /**
     Sets the deviceUid to the current connected drones identifier.
     
     - Parameter uid:   The uid of the drone
     */
    func setDeviceUid(_ uid: String) {
        droneUid = uid
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscapeRight
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    /**
     Sends us back to the home viewcontroller.
     
     - Parameter sender: the caller fo this function.
     */
    @IBAction func dismiss(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    /**
     Initializes the interfaces to our drone. In this case, we only setup the manual
     piloting interface, but in the future we could add additional interfaces here.
     (Such as follow me, automated flight, etc.)
     
     - Parameter drone: The drone we are connected to
     */
    private func initDroneRefs(_ drone: Drone) {
        pilotingItf = drone.getPilotingItf(PilotingItfs.manualCopter) { [unowned self] pilotingItf in
            self.updateTakeoffLandButton(pilotingItf)
        }
        
        // Monitor the stream server.
        streamServerRef = drone.getPeripheral(Peripherals.streamServer) { [weak self] streamServer in
            // Called when the stream server is available and when it changes.

            if let self = self, let streamServer = streamServer {
                // Enable Streaming
                streamServer.enabled = true
                self.liveStreamRef = streamServer.live { liveStream in
                    // Called when the live stream is available and when it changes.

                    if let liveStream = liveStream {
                        // Set the live stream as the stream to be render by the stream view.
                        self.streamView.setStream(stream: liveStream)
                        // Play the live stream.
                        _ = liveStream.play()
                        self.captureImage()
                    }
                }
            }
        }
        
        
    }
    
    /**
     Responds to the takeoffLand button click action. The drone will automatically takeoff
     if grounded or land if in flight.
     
     - Parameter sender: The takeoffLand button on the Hud viewcontroller.
     */
    @IBAction func takeOffLand(_ sender: Any) {
        if let pilotingItf = pilotingItf?.value {
            pilotingItf.smartTakeOffLand()
        }
    }
    
    /**
     This function is called by the piloting interface on the event of a new
     smartTakeOffLand action being performed on the drone. This updates the image
     of the takeoffLand button dynamically to represent the action being performed.
     
     - Parameter pilotingItf: The piloting interface used for manual flight.
     */
    private func updateTakeoffLandButton(_ pilotingItf: ManualCopterPilotingItf?) {
        if let pilotingItf = pilotingItf, pilotingItf.state == .active {
            takeoffLandButton.isHidden = false
            let smartAction = pilotingItf.smartTakeOffLandAction
            switch smartAction {
            case .land:
                takeoffLandButton.setImage(landButtonImage, for: .normal)
            case .takeOff:
                takeoffLandButton.setImage(takeOffButtonImage, for: .normal)
            case .thrownTakeOff:
                takeoffLandButton.setImage(handButtonImage, for: .normal)
            case .none:
                ()
            }
            takeoffLandButton.isEnabled = smartAction != .none
        } else {
            takeoffLandButton.isEnabled = false
            takeoffLandButton.isHidden = true
        }
    }
    
    /**
     Responds to the Left Joystick. Updates the pitch and roll of the drone in real time.
     
     - Parameter sender: The left joystick on the Hud viewcontroller.
     */
    @IBAction func leftJoystickUpdate(_ sender: JoystickView) {
        if let pilotingItf = pilotingItf?.value, pilotingItf.state == .active {
            pilotingItf.set(pitch: -sender.value.y)
            pilotingItf.set(roll: sender.value.x)
        }
    }
    
    /**
     Responds to the Right Joystick. Updates the vertical speed and yaw rotation in real time.
     
     - Parameter sender: The right joystick on the Hud viewcontroller.
     */
    @IBAction func rightJoystickUpdate(_ sender: JoystickView) {
        if let pilotingItf = pilotingItf?.value, pilotingItf.state == .active {
            pilotingItf.set(verticalSpeed: sender.value.y)
            pilotingItf.set(yawRotationSpeed: sender.value.x)
        } 
    }
}

//extension HudViewController: YuvSinkListener {
//
//    func frameReady(sink: StreamSink, frame: SdkCoreFrame) {
//        captureImage()
//    }
//
//    func didStart(sink: StreamSink) {
//
//    }
//
//    func didStop(sink: StreamSink) {
//
//    }
//}

// Handle Image processing and the overlay
extension HudViewController {

    func captureImage() {
        // captures the current frame of the video feed as an image
        let fps = 1.0
        let seconds = 1.0 / fps
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            self.runInference(self.streamView.snapshot)
            self.captureImage()
        }
    }
    
    func runInference(_ image:UIImage) {
        let pixelBuffer:CVPixelBuffer = image.pixelBuffer()!
        guard let inferences = self.modelDataHandler.runModel(onFrame: pixelBuffer) else {
            return
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        DispatchQueue.main.async {
            // Draws the bounding boxes and displays class names and confidence scores.
            self.drawDetections(onInferences: inferences, withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)))
        }
    }
    
    func drawDetections(onInferences inferences: [Inference], withImageSize imageSize:CGSize) {
       self.overlayView.objectOverlays = []
       self.overlayView.setNeedsDisplay()

       guard !inferences.isEmpty else {
         return
       }

       var objectOverlays: [ObjectOverlay] = []

       for inference in inferences {

         // Translates bounding box rect to current view.
         var convertedRect = inference.rect.applying(CGAffineTransform(scaleX: self.overlayView.bounds.size.width / imageSize.width, y: self.overlayView.bounds.size.height / imageSize.height))

         if convertedRect.origin.x < 0 {
           convertedRect.origin.x = self.edgeOffset
         }

         if convertedRect.origin.y < 0 {
           convertedRect.origin.y = self.edgeOffset
         }

         if convertedRect.maxY > self.overlayView.bounds.maxY {
           convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
         }

         if convertedRect.maxX > self.overlayView.bounds.maxX {
           convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
         }

         let confidenceValue = Int(inference.confidence * 100.0)
         let string = "\(inference.className)  (\(confidenceValue)%)"

         let size = string.size(usingFont: self.displayFont)

         let objectOverlay = ObjectOverlay(name: string, borderRect: convertedRect, nameStringSize: size, color: inference.displayColor, font: self.displayFont)

         objectOverlays.append(objectOverlay)
       }

       // Hands off drawing to the OverlayView
       self.draw(objectOverlays: objectOverlays)

     }

     /** Calls methods to update overlay view with detected bounding boxes and class names.
      */
     func draw(objectOverlays: [ObjectOverlay]) {
       self.overlayView.objectOverlays = objectOverlays
       self.overlayView.setNeedsDisplay()
     }
}
