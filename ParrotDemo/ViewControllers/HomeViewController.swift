//
//  ViewController.swift
//  ParrotDemo
//
//  Created by ian timmis on 7/16/19.
//  Copyright © 2019 RIIS. All rights reserved.
//

import UIKit
import GroundSdk

class HomeViewController: UITableViewController {
    
    private let groundSdk = GroundSdk()
    private var droneListRef: Ref<[DroneListEntry]>!
    private var droneList: [DroneListEntry]?
    
    private var drone: Drone? = nil
    private var stateRef: Ref<DeviceState>?
    
    private var selectedUid: String?
    private var droneState: Int?

    /**
     Responds to the view loading. Gets the list of drones and saves a reference to them.
     This sets up the closure allowing the table to update in real time to updates in
     the set of observable drones.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.rowHeight = 80
        
        // This keeps our drone lists up to date in real time
        droneListRef = groundSdk.getDroneList(
            observer: { [unowned self] entryList in
                self.droneList = entryList
                self.tableView.reloadData()
        })
    }

    /**
     Loads the rows of our tableview. Sets up a cell for each drone in our list. The text
     in each cell is set up to update in real time to updates of our drones.
     (such as connection state, etc.)
     
     - Parameter tableView: Reference to the tableView
     - Parameter indexPath: The index to current cell being populated
     
     - Returns: The new table cell we have created
     */
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // This function loads the table cells
        let cell = tableView.dequeueReusableCell(withIdentifier: "DroneCell", for: indexPath)
        if let cell = cell as? DeviceCell {
            if let droneEntry =  self.droneList?[indexPath.row] {
                cell.name.text = droneEntry.name
                cell.uid.text = droneEntry.uid
                cell.model.text = droneEntry.model.description
                let state = droneEntry.state
                cell.connectionState.text =
                "\(state.connectionState.description)-\(state.connectionStateCause.description)"
            }
        }
        
        return cell
    }
    
    /**
     Responds to table cells being clicked. If the drone we have selected is not connected
     to our phone, connect to it. If the drone is connected, then disconnect. If we attempt
     to connect and cannot, we display a message to the user that they need to be connected to
     the drone's WiFi before connecting to the drone.
     
     Upon successful connection, we navigate automatically to the Hud viewcontroller.
     
     - Parameter tableView: Reference to the tableView
     - Parameter indexPath: The index to selected cell
     */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if let droneEntry = self.droneList?[indexPath.row] {
            drone = groundSdk.getDrone(uid: droneEntry.uid)
            self.selectedUid = droneEntry.uid
            if let drone = drone {
                self.stateRef = drone.getState { [weak self] state in
                    (self?.tableView.cellForRow(at: indexPath) as! DeviceCell).connectionState.text = state!.description
                    
                    // When disconnecting the drone, this code will get called twice, first saying "connected" second saying "disconnected".
                    // We keep track of previous drone state to ensure disconnection does not push to Hud screen
                    if (state?.connectionState.rawValue)! == 2 && self?.droneState != 2{
                            self?.navigateToHud()
                    }
                    self?.droneState = state?.connectionState.rawValue
                }
            }

            if let connectionState = stateRef?.value?.connectionState {
                if connectionState == DeviceState.ConnectionState.disconnected {
                    if let drone = drone {
                        if drone.state.connectors.count > 0 {
                            connect(drone: drone, connector: drone.state.connectors[0])
                        } else {
                            // No way of connecting to drone
                            let alert = UIAlertController(title: "No means of connection", message: "To connect to your drone, remember to connect to the Anafi WiFi signal first.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
                            self.present(alert, animated: true)
                        }
                    }
                } else {
                    _ = drone?.disconnect()
                }
            }
        }
    }
    
    /**
     Performs the process of connecting to the drone via the specified device connector.
     In this app, we only connect to the drone using nothing but our cell phone. Other
     connectors could allow phone plugged into the drone controller etc. If the drone
     requires a password, we ask for it. Otherwise, simply connect.
     
     - Parameter drone: The drone we want to connect to
     - Parameter connector: The way we would like to connect to drone.
     */
    private func connect(drone: Drone, connector: DeviceConnector) {
        if drone.state.connectionStateCause == .badPassword {
            // ask for password
            let alert = UIAlertController(title: "Password", message: "", preferredStyle: .alert)
            alert.addTextField(configurationHandler: nil)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                if let password = alert.textFields?[0].text {
                    _ = drone.connect(connector: connector, password: password)
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            _ = drone.connect(connector: connector)
        }
    }
    
    /**
     Segues to the Hud viewController. This is conditioned on the drone
     being connected.
     */
    private func navigateToHud() {
        if let drone = drone {
            if drone.getPilotingItf(PilotingItfs.manualCopter) != nil {
                performSegue(withIdentifier: "gotoHud", sender: self)
            }
        }
    }
    
    /**
     Returns the number of rows in the tableview, the count is equal to the amount of
     drones we have in our list.
     
     - Parameter tableView: The table in our viewcontroller
     - Parameter section: the section we are populating (in our case, we only have one)
     
     - Returns: Num of rows in tableview
     */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return droneList?.count ?? 0
    }
    
    /**
     Responds to the segue to another ViewController. We pass the drone
     Uid to the Hud here.
     
     - Parameter segue: The segue in progress.
     - Parameter sender: The caller of this function.
     */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? HudViewController,
            let selectedUid = selectedUid {
            viewController.setDeviceUid(selectedUid)
        }
    }
}

/**
 This is the class representing the table cells in our drone list
 */
@objc(DeviceCell)
private class DeviceCell: UITableViewCell {
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var model: UILabel!
    @IBOutlet weak var uid: UILabel!
    @IBOutlet weak var connectionState: UILabel!
    @IBOutlet weak var connectors: UILabel!
}

