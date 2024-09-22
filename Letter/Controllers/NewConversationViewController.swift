//
//  NewConversationViewController.swift
//  Letter
//
//  Created by Adithya on 03/08/24.
//
import UIKit
import JGProgressHUD

class NewConversationViewController: UIViewController {

    private  let spinner = JGProgressHUD(style: .dark)
    public var completion : ((SearchResults) -> (Void))?
    private var users = [[String:String]]()
    private var results = [SearchResults]()

    
    private var hasFetched = false
    private let searchBar:UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search here"
        return searchBar
    }()
    
    
    
    private let tableView:UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(NewConversationCell.self, forCellReuseIdentifier: NewConversationCell.identifier)
        return table
    }()
    
    private let  noResultsLabel : UILabel = {
        let label  = UILabel()
        label.isHidden = true
        label.text = "No Users Found"
        label.font = .systemFont(ofSize: 21,weight: .medium)
        label.textAlignment = .center
        label.textColor = .orange
        return label
        
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.becomeFirstResponder()
        view.backgroundColor = .systemBackground
        searchBar.delegate = self
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done
                                                            , target: self, action: #selector(dismissSelf))
        
        view.addSubview(tableView)
        view.addSubview(noResultsLabel)
        
        tableView.delegate = self
        tableView.dataSource  = self
        
    
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noResultsLabel.frame = CGRect(x: view.width/4, y: (view.height - 200)/2, width: view.width/2, height: 200 )
    }
    
    
    @objc private func dismissSelf(){
        dismiss(animated: true, completion: nil)
    }
    
    
}

extension NewConversationViewController:UISearchBarDelegate{
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text,  !text.replacingOccurrences(of: " ", with: "").isEmpty else{
            return
        }
        
        searchBar.resignFirstResponder()
        results.removeAll()
        spinner.show(in: view)
        self.searchUsers(query: text)
    }
    
    func searchUsers(query:String){
        if hasFetched{
            filterUsers(with: query)
        }else{
            DatabaseManager.shared.getAllUsers(completion: { [weak self] Result in
                switch Result{
                case .success(let userCollection):
                    self?.hasFetched = true
                    self?.users = userCollection
                    self?.filterUsers(with: query)
                case .failure(let error):
                    print("Failed to get user")
                }
    
            })
        }
    }
    
    func filterUsers(with term:String){
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else{return}
        
       let safeEmail =  DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        guard hasFetched else{
            return
        }
        
        self.spinner.dismiss()
        let results : [SearchResults] = self.users.filter({
            guard  let email = $0["email"],
                    email != safeEmail else{
                return false
            }
            guard let name = $0["name"]?.lowercased() as? String else{
                return false
            }
            return name.hasPrefix(term.lowercased())
            
        }).compactMap({
            guard let email = $0["email"],
                  let name = $0["name"] else{
                return nil
            }
            return SearchResults(name: name, email: email)
        })
        self.results = results
        updateUI()
    }
    func updateUI(){
        
        if results.isEmpty{
            self.tableView.isHidden = true
            self.noResultsLabel.isHidden = false
        }else{
            self.tableView.isHidden = false
            self.noResultsLabel.isHidden = true
            self.tableView.reloadData()
        }
        
    }
    
    
}

extension NewConversationViewController:UITableViewDelegate, UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: NewConversationCell.identifier, for: indexPath)as! NewConversationCell
        cell.configure(with: model)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        //Start conversation
        
        let targetUser = results[indexPath.row]
        dismiss(animated: true, completion: { [weak self] in
            self?.completion?(targetUser)
        })
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}
struct SearchResults{
var name : String
var  email: String
}

