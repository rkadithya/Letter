//
//  ProfileViewController.swift
//  Letter
//
//  Created by Adithya on 03/08/24.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import SDWebImage

enum ProfileViewModelType{
    case info, logout
    
}
struct ProfileViewModel{
    let viewModelType : ProfileViewModelType
    let title : String
    let handler: (() -> Void)?
}

class ProfileViewController: UIViewController {
    @IBOutlet var tableView:UITableView!
    var data = [ProfileViewModel]()
    override func viewDidLoad() {
        super.viewDidLoad()
        UserDefaults.standard.synchronize()
    }
    override func viewDidDisappear(_ animated: Bool) {
        data.removeAll()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        data.append(ProfileViewModel(viewModelType: .info, title: "\(UserDefaults.standard.value(forKey: "name") ?? "No name")", handler: nil))
        data.append(ProfileViewModel(viewModelType: .info, title: "\(UserDefaults.standard.value(forKey: "email") ?? "No email")", handler: nil))
        data.append(ProfileViewModel(viewModelType: .logout, title: "Log Out", handler: { [weak self] in
            guard let strongSelf = self else{
                return
                
            }
            let actionSheet = UIAlertController(title: "",
                                          message: "",
                                          preferredStyle: .actionSheet)
            
            actionSheet.addAction(UIAlertAction(title: "Log Out", style: .destructive, handler: { [weak self]_ in
                guard let strongSelf = self else{
                    return
                }
                DispatchQueue.main.async{
                    UserDefaults.standard.removeObject(forKey: "email")
                    UserDefaults.standard.removeObject(forKey: "name")
                    UserDefaults.standard.setValue(nil, forKey: "email")
                    UserDefaults.standard.setValue(nil, forKey: "name")
                    UserDefaults.standard.synchronize()

                }
                FBSDKLoginKit.LoginManager().logOut()
                GIDSignIn.sharedInstance()?.signOut()
                


                                
                do{
                    try  FirebaseAuth.Auth.auth().signOut()
                    let vc = LoginViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    strongSelf.present(nav, animated: true)

                }catch{
                    print("Failed to log out")
                }
            }))
            actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            strongSelf.present(actionSheet,animated: true)
        }))

        
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableHeader()
        tableView.reloadData()
    }
    func createTableHeader() -> UIView?{
        guard let email = UserDefaults.standard.value(forKey: "email")  as? String else{
            return nil
        }
        let safeMail = DatabaseManager.safeEmail(emailAddress: email)
        let fileName = safeMail + "_profile_picture.png"
        let path = "images/"+fileName
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.width, height: 300))
        let imageView = UIImageView(frame: CGRect(x:( headerView.width - 150)/2, y:75, width: 150, height: 150))
        headerView.backgroundColor = .none
        imageView.contentMode =  .scaleAspectFill
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.masksToBounds = true
        imageView.backgroundColor = .white
        imageView.layer.cornerRadius = imageView.width / 2
        
        headerView.addSubview(imageView)
        
        StorageManager.shared.downloadUrl(for: path, completion: { result  in
            switch result{
            case .success(let url):
                imageView.sd_setImage(with: url, completed: nil)
            case .failure(let error):
                print("Failed to get profile picture \(error)")
                
                
            }
        })
        
        return headerView
        
    }
    

}
extension ProfileViewController:UITableViewDelegate,UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell

        cell.setup(with: viewModel)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
       data[indexPath.row].handler?()
       
    }
    

    
}

class ProfileTableViewCell : UITableViewCell{
    static let identifier = "ProfileTableViewCell"
    
    public func setup(with viewModel:ProfileViewModel){
        self.textLabel?.text = viewModel.title
        switch viewModel.viewModelType {
        case .info:
            self.selectionStyle = .none
            self.textLabel?.textAlignment = .left
            self.textLabel?.textColor = .white
            self.textLabel?.font = .systemFont(ofSize: 20, weight: .semibold)

            
        case .logout:
            self.textLabel?.textColor = .red
            self.textLabel?.textAlignment = .center
            
            
        }
        
    }
}
