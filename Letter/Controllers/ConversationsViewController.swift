//
//  ViewController.swift
//  Letter
//
//  Created by Adithya on 03/08/24.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

struct Conversation{
    let id : String
    let otherUserEmail : String
    let name : String
    let latestMessage : latestMessage
}

struct latestMessage{
    let date : String
    let text : String
    let isRead : Bool
}

class ConversationsViewController: UIViewController {
    
    
    private var conversations = [Conversation]()

    private var tableView:UITableView = {
        let table = UITableView()
        table.register(ConversationTableViewCell.self, forCellReuseIdentifier:ConversationTableViewCell.identifier)
        return table
    }()
    
    
    private var noConversationLabel:UILabel = {
        let label = UILabel()
        label.text = "There is no conversations available!"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.isHidden = true
        return label
        
    }()
    
    private let spinner:JGProgressHUD = {
        let spinner = JGProgressHUD()
        spinner.style = .dark
        return spinner
    }()
    private var loginObserver : NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        UserDefaults.standard.synchronize()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(didTapOnCompose))
        view.addSubview(tableView)
        view.addSubview(noConversationLabel)
        setupTableView()
        loginObserver =  NotificationCenter.default.addObserver(forName: .didLogInNotification,
                                               object: nil, queue: .main, using: ({[weak self] _ in
            guard let StrongSelf = self else{
                return
            }
            StrongSelf.startListeningToConversations()
        }))
    }
    private func startListeningToConversations(){
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        if let observer = loginObserver{
            NotificationCenter.default.removeObserver(observer)
            print("Started Fetcing Conversation .....")
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        DatabaseManager.shared.getAllConversations(for: safeEmail, completion: { [weak self] result in
            switch result{
            case .success(let conversations):
                print("fetching all the  conversation available")
                guard !conversations.isEmpty else{               
                    self?.tableView.isHidden = true
                    self?.noConversationLabel.isHidden = false

                    return
                }
                self?.tableView.isHidden = false
                self?.noConversationLabel.isHidden = true

                self?.conversations = conversations
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
       
            case.failure(let error):
                print("Failed to fetch convo \(error)")
                self?.tableView.isHidden = true
                self?.noConversationLabel.isHidden = false
            }
            
        })
    }
    
    @objc func didTapOnCompose(){
        let vc = NewConversationViewController()
        vc.completion = {[weak self] result in
            guard let strongSelf = self else {
                return
            }
            print("\(result)")
            let currentConversations = strongSelf.conversations
            if let targetConversations = currentConversations.first(where:{
                $0.otherUserEmail == DatabaseManager.safeEmail(emailAddress: result.email)
            }){
                let vc = ChatViewController(with: targetConversations.otherUserEmail, id: targetConversations.id)
                vc.isNewConversation = false
                vc.title = targetConversations.name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }else{
                strongSelf.createNewConversation(result: result)

            }
        }
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
    
    private func createNewConversation(result:SearchResults){
         let name = result.name
        let email = DatabaseManager.safeEmail(emailAddress: result.email)
        
        //if conversation already exists use the existing sender id otherwise use the same code
        DatabaseManager.shared.conversationExists(with: email, completion: {[weak self] result in
            guard let strongSelf = self else{
                return
            }
            switch result {
            case .success(let conversationId):
                let vc = ChatViewController(with: email, id:conversationId)
                vc.isNewConversation = false
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            case.failure(_):
                let vc = ChatViewController(with: email, id:nil)
                vc.isNewConversation = true
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)

            }
        })
       
        
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noConversationLabel.frame = CGRect(x: 10,
                                          y: (view.height - 100)/2,
                                           width: view.width - 20, height: 100)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if FirebaseAuth.Auth.auth().currentUser == nil{
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false)
        }
        startListeningToConversations()

    }
    func setupTableView(){
        self.tableView.dataSource = self
        self.tableView.delegate = self
    }
    func fetchConversation(){
        
    }
}

extension ConversationsViewController:UITableViewDelegate,UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier, for: indexPath) as! ConversationTableViewCell
        let model = conversations[indexPath.row]
        cell.configure(with: model)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = conversations[indexPath.row]
        openConversations(model)
       
    }
    
    func openConversations(_ model:Conversation){
        let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
       return  120
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete{
            let conversationID = conversations[indexPath.row].id
            tableView.beginUpdates()

            DatabaseManager.shared.deleteConversation(conversationId: conversationID, completion: { [weak self] success in
                if success{
                    self?.conversations.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .left)
                }
            })
          
            tableView.endUpdates()
        }
    }
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
}

