//
//  LoginViewController.swift
//  Letter
//
//  Created by Adithya on 03/08/24.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import JGProgressHUD
class LoginViewController: UIViewController {
    
    private let scrollView:UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let imageView:UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "Logo")
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 30
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private let emailTextField:UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email Address..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
    }()
    
    
    private let passWordField:UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password"
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        field.isSecureTextEntry = true
        return field
    }()
    
    private let loginButton : UIButton = {
        let button = UIButton()
        button.setTitle("Login", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.secondarySystemBackground, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20,weight: .bold)
        return button
    }()
    
    private let fbLoginButton : FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["email", "public_profile"]
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 16,weight: .bold)
        return button
    }()
    
    private let spinner:JGProgressHUD = {
        let spinner = JGProgressHUD()
        spinner.style = .dark
        return spinner
    }()
    private let googleLoginButton =  GIDSignInButton()
     
    private var loginObserver : NSObjectProtocol?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        UserDefaults.standard.synchronize()
        view.backgroundColor = .systemBackground
        title = "Login"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Register",
            style: .done,
            target: self,
            action: #selector(didRightButtonTapped))
        
        loginButton
            .addTarget(
                self,
                action: #selector(loginButtonTapped),
                for: .touchUpInside)
        
        emailTextField.delegate = self
        passWordField.delegate = self
        fbLoginButton.delegate = self
     
        
        
        loginObserver =  NotificationCenter.default.addObserver(forName: .didLogInNotification,
                                               object: nil, queue: .main, using: ({[weak self] _ in
            guard let StrongSelf = self else{
                return
            }
            StrongSelf.navigationController?.dismiss(animated: true)
        }))
        
        
        GIDSignIn.sharedInstance()?.presentingViewController =  self
        //Subview
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailTextField)
        scrollView.addSubview(passWordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(fbLoginButton)
        scrollView.addSubview(googleLoginButton)
        
    }
    
    deinit{
        if let observer = loginObserver{
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        scrollView.frame = view.bounds
        let size = scrollView.width / 3
        
        //imageView
        imageView.frame = CGRect(
            x: (scrollView.width-size)/2,
            y: 20,
            width: size,
            height: size)
        
        //Email text field
        emailTextField.frame = CGRect(x: 30, y: imageView.bottom + 30, width: scrollView.width - 60, height: 52)
        passWordField.frame = CGRect(x: 30, y: emailTextField.bottom + 10, width: scrollView.width - 60, height: 52)
        loginButton.frame = CGRect(x: 30, y: passWordField.bottom + 15, width: scrollView.width - 60, height: 52)
        fbLoginButton.frame = CGRect(x: 30, y: loginButton.bottom + 15, width: scrollView.width - 60, height: 52)
        googleLoginButton.frame = CGRect(x: 30, y: fbLoginButton.bottom + 15, width: scrollView.width - 60, height: 52)
        
    }
    @objc private func didRightButtonTapped(){
        let vc = RegisterViewController()
        vc.title = "Create an account"
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func loginButtonTapped(){
        
        emailTextField.resignFirstResponder()
        passWordField.resignFirstResponder()
        
        guard let email = emailTextField.text, let password = passWordField.text,
              !email.isEmpty, !password.isEmpty,password.count >= 6 else{
            alertUserLoginError()
            return
        }
        
        spinner.show(in: view)
        //Firebase Login
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion: {[weak self] authResult, error in
            guard let StrongSelf = self else{
                return
            }
            DispatchQueue.main.async {
                StrongSelf.spinner.dismiss()
                
            }
            guard let result = authResult, error == nil else{
                print("Error occured")
                return
            }
            let user = result.user
            UserDefaults.standard.set(email, forKey: "email")
            let safeMail = DatabaseManager.safeEmail(emailAddress: email)
            //            UserDefaults.standard.set(email, forKey: "name")
            DatabaseManager.shared.getAllData(path: safeMail, completion: { result in
                switch result{
                case .success(let data):
                    guard let userData = data as? [String : Any],
                          let firstName = userData["first_name"],
                          let lastName = userData["last_name"] else{
                        return
                    }
                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                case .failure(let error):
                    print("Error fetching name \(error)")
                }
            })
            
            print("\(String(describing: user)) have logged in successfully")
            
            StrongSelf.navigationController?.dismiss(animated: true)
            
        })
    }
    
    func alertUserLoginError(){
        let alert = UIAlertController(title: "Woops!", message: "Please enter all the information", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }
}

extension LoginViewController:UITextFieldDelegate{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if(textField == emailTextField){
            passWordField.becomeFirstResponder()
        }else if( textField ==  passWordField){
            loginButtonTapped()
        }
        return true
    }
}

extension LoginViewController:LoginButtonDelegate{
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginKit.FBLoginButton) {
        //Do nothing
    }
    
    func loginButton(_ loginButton: FBSDKLoginKit.FBLoginButton, didCompleteWith result: FBSDKLoginKit.LoginManagerLoginResult?, error: (Error)?) {
        
        guard let token = result?.token?.tokenString else{
            print("User failed to login")
            return
        }
        let facebookRequest = FBSDKLoginKit.GraphRequest(
            graphPath: "me",
            parameters: ["fields":"email, first_name,last_name,picture.type(large)"],
            tokenString: token,
            version: nil,
            httpMethod: .get
        )
        
        facebookRequest.start(completionHandler: { _,result,error in
            guard let result = result as? [String:Any], error == nil else{
                print("Failed to make graph request")
                return
            }
            print(result)
            
            guard let firstName = result["first_name"] as? String,
                  let lastName = result["last_name"] as? String,
                  let email = result["email"] as? String,
                  let picture = result["picture"] as? [String:Any],
                  let data = picture["data"] as? [String:Any],
                  let pictureUrl = data["url"] as?  String else{
                print("Failed to get email and username from facebook")
                return
            }
            
            
            UserDefaults.standard.set(email, forKey: "email")
            UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")

            DatabaseManager.shared.userExists(with: email, completion: { exists in
                 if !exists{
                     let chatUser = ChatAppUser(firstName: firstName, lastName: lastName, emailAddress: email)
                     DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
                         //Upload image
                         if (success){
                             guard let url = URL(string: pictureUrl) else{
                                 return
                             }
                             print("Downloading  data from facebook")

                             URLSession.shared.dataTask(with: url, completionHandler: { data, _, _ in
                                 guard let data = data else{
                                     print("failed to get data from facebook")

                                     return
                                 }
                                 
                                 print("Got data from facebook")
                                 let fileName = chatUser.profilePictureFileName
                                 StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName, completion: { result in
                                     switch result {
                                     case .success(let downloadUrl):
                                         UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                         print(downloadUrl)
                                     case .failure(let error):
                                         print(error)
                                         
                                     }
                                 })
                             }).resume()
                         }
                     })
                }
            })
            let credential = FacebookAuthProvider.credential(withAccessToken: token)

            FirebaseAuth.Auth.auth().signIn(with: credential, completion: {[weak self] authResult,error  in
                guard let StrongSelf = self else{
                    return
                    
                }
                guard let result = authResult, error == nil else{
                    if let error = error{
                        print("Facebook credential login failed!!! \n step verification may be needed \(error)")
                    }
                    return
                }
                
                print("Successfully logged in")
                StrongSelf.navigationController?.dismiss(animated: true)
                
            })
        })
    }
}
