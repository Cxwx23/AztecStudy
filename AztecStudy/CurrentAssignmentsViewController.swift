//
//  CurrentAssignmentsViewController.swift
//  AztecStudy
//
//  Created by Christopher Simonson on 12/16/18.
//  Copyright © 2018 SimonsonProductions. All rights reserved.
//

import UIKit
import Firebase

/* Current Assignments View Controller
 *
 * Displays the users current assignments.  User can also click the checkbox next to the assignment to mark as complete.
 * Checked assignment will than transition to completed assignments tab.
 */
class CurrentAssignmentsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    //MARK: Outlets
    
    @IBOutlet weak var tableView: UITableView!
    
    //MARK: Properties
    
    var assignments = [Assignment]()
    let userID = Auth.auth().currentUser?.uid
    
    //MARK: Table Methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assignments.count 
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CheckBoxCell", for: indexPath) as? AssignmentTableViewCell else {
            fatalError("The dequed cell is not an instance of ScheduleTableViewCell")
        }
        let btnCheck = cell.contentView.viewWithTag(1) as? UIButton
        btnCheck?.tag = indexPath.row
        btnCheck?.addTarget(self, action: #selector(checkboxClicked(_ :)), for: .touchUpInside)
        
        let assignmentInfo = assignments[indexPath.row]
        cell.classLabel.text = assignmentInfo.course
        cell.detailsLabel.text = assignmentInfo.details
        
        let dueDate = assignmentInfo.dueDate
        let dueDateArr = dueDate.components(separatedBy: "-")
        let month = getMonth(date: dueDateArr[1])
        let dueDateStr = "Due: \(month) \(dueDateArr[0]), \(dueDateArr[2])"
        cell.dueDateLabel.text = dueDateStr
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
 
    /* Slide to delete assignment */
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let assignmentInfo = assignments[indexPath.row]
            let assignmentID = assignmentInfo.assignmentID
            Database.database().reference().child("users").child(userID!).child("assignments").child("current").child(assignmentID).removeValue()
            self.assignments.remove(at: indexPath.row)
            self.tableView.reloadData()
        }
    }
 

    //MARK: Initial Load

    override func viewDidLoad() {
        super.viewDidLoad()
        //Set delegates
        self.tableView.delegate = self
        self.tableView.dataSource = self
        //Load assignemnts
        loadAssignments()
    }
    
    //MARK: Action
    
    /* Unwind the segue */
    @IBAction func unwindToCurrentViewController(segue: UIStoryboardSegue) {
        loadAssignments()
    }
    
    /* Helper method to handle when the check box for the assignment is clicked */
    @objc func checkboxClicked(_ sender: UIButton) {
        if (!sender.isSelected) {
            let alertController = UIAlertController(title: "Mark Assignment Complete", message: "Are You Sure?", preferredStyle: UIAlertController.Style.alert)
            alertController.addAction(UIAlertAction(title: "Yes", style: UIAlertAction.Style.default, handler: {(action: UIAlertAction!) in
                self.assignmentCompleted(sender: sender.tag)
            }))
            alertController.addAction(UIAlertAction(title: "No", style: UIAlertAction.Style.cancel, handler: {(action: UIAlertAction!) in
                print("CANCEL ACTION")
                
            }))
            DispatchQueue.main.async {
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    //MARK: Private Methods
    
    private func getMonth(date: String) -> String {
        var month = ""
        switch date {
        case "01":
            month = "Jan"
        case "02":
            month = "Feb"
        case "03":
            month = "Mar"
        case "04":
            month = "Apr"
        case "05":
            month = "May"
        case "06":
            month = "Jun"
        case "07":
            month = "Jul"
        case "08":
            month = "Aug"
        case "09":
            month = "Sep"
        case "10":
            month = "Oct"
        case "11":
            month = "Nov"
        case "12":
            month = "Dec"
        default:
            month = ""
        }
        return month
    }
    
    /* Assignment marked as complete so assignment is moved to completed assignments in the Firebase database*/
    private func assignmentCompleted(sender: Int) {
        let assignment = self.assignments[sender]
        assignment.completed = true
        let ref = Database.database().reference()
        ref.child("users").child(userID!).child("assignments").child("completed").child(assignment.assignmentID).setValue(["course": assignment.course, "details": assignment.details , "dueDate": assignment.dueDate,"completed": assignment.completed, "ID": assignment.assignmentID])
        ref.child("users").child(userID!).child("assignments").child("current").child(assignment.assignmentID).removeValue()
        self.assignments.remove(at: sender)
        self.tableView.reloadData()
    }
    
    /* Loads the assignments */
    private func loadAssignments() {
        assignments = []
        let data = Database.database().reference().child("users").child(userID!).child("assignments").child("current")
        data.observeSingleEvent(of: .value) { snapshot in
            for assignment in snapshot.children {
                //Loop through assignments for the user
                let snap = assignment as! DataSnapshot
                let assignmentID = snap.key
                let assignmentChildren = data.child(assignmentID)
                assignmentChildren.observeSingleEvent(of: .value) { childSnap in
                    //Local variables to hold assignment details
                    var course = ""
                    var details = ""
                    var dueDate = ""
                    var completed = false
                    var id = ""
                    //Loop through assignment details
                    for assignmentData in childSnap.children {
                        let csnap = assignmentData as! DataSnapshot
                        let category = csnap.key
                        let catInfo = csnap.value
                        if(category == "course") {
                            course = catInfo as! String
                        }
                        else if (category == "completed") {
                            completed = catInfo as! Bool
                        }
                        else if (category == "details") {
                            details = catInfo as! String
                        }
                        else if (category == "ID") {
                            id = catInfo as! String
                        }
                        else {
                            dueDate = catInfo as! String
                        }
                    }
                    //Create an assignment entry
                    let assignmentEntry = Assignment(course: course, dueDate: dueDate, details: details, completed: completed, assignmentID: id)
                    self.assignments.append(assignmentEntry)
                    //Sort by due date
                    self.assignments = self.assignments.sorted(by: {$0.dueDate < $1.dueDate})
                    //Reload the data
                    self.tableView.reloadData()
                }
            }
        }
    }
}
