//
//  ChatViewController.swift
//  Letter
//
//  Created by apple on 18/08/24.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation

struct Message:MessageType{
    public var sender: MessageKit.SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKit.MessageKind
    
}
extension MessageKind{
    var messageKindString : String{
        switch self{
            
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributedText"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "linkPreview"
        case .custom(_):
            return "custom"
        }
    }
    
}
struct Sender:SenderType{
    public var senderId: String
    public var displayName: String
    public var  photoUrl:String
}

struct Media : MediaItem{
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
}

struct Location:LocationItem{
    var location: CLLocation
    
    var size: CGSize
    
    
}
class ChatViewController: MessagesViewController {
    
    private var senderPhotoUrl : URL?
    private var otherUserPhotoUrl : URL?

    
    public static let dataFormatter:DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle =  .long
        dateFormatter.locale = .current
        return dateFormatter
    }()
    
    public var isNewConversation = false
    public var  otheruserEmail : String
    private var  conversationId : String?

    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        return Sender(senderId: safeEmail, displayName: "Me", photoUrl: "")
    }
    init(with email:String, id:String?) {
        self.conversationId = id
        self.otheruserEmail = email
        super.init(nibName: nil, bundle: nil)
   
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        UserDefaults.standard.synchronize()
        if let conversationId = conversationId{
            listenForMessages(id: conversationId, shouldScrollToBottom : true)
        }
    }
    
    private func setupInputButton(){
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        
        button.onTouchUpInside({[weak self] _ in
            self?.presentInputActionSheet()
            
        })
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
        
        

    }
    private func presentInputActionSheet(){
        
        let actionSheet = UIAlertController(title: "Attach", message: "What would you like to attach?", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: { [weak self] _ in
            self?.presentPhotoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: {  _ in
        }))
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self] _ in
            self?.presentVideoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: { [weak self] _ in
            self?.presentLocationPicker()
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true)
    }
    
    private func presentLocationPicker(){
        let vc = LocationPickerViewController(coordinates: nil)
        vc.isPickable = true
        vc.title = "Pick Location"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = {[weak self] selectedCoordinates in
            guard let strongSelf = self else{ return }
            guard
                let messageID = strongSelf.createMessageId(),
                let conversationId = strongSelf.conversationId,
                  let name = strongSelf.title,
                    let selfSender = strongSelf.selfSender
            else{
                return
            }
            let longitude :  Double = selectedCoordinates.longitude
            let latitude : Double = selectedCoordinates.latitude
            print("Long : \(longitude)  Lat : \(latitude)")
           
            
            let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: .zero)
            
            let message = Message(sender: selfSender, messageId: messageID, sentDate: Date(), kind: .location(location))
            DatabaseManager.shared.sendMessageToConversation(to: conversationId, name: name, otheUserEmail: strongSelf.otheruserEmail, newMessage: message, completion: { success in
                
                if success{
                    print("Send a Location message")
                }else{
                    print("failed to send  a Location message")
                    
                }})
            
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    private func presentPhotoInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Photo", message: "What would you like to attach photo from??", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Photo library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: {[weak self]   _ in
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .camera
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true)
    }
    
    private func presentVideoInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Photo", message: "What would you like to attach a video from??", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            picker.allowsEditing = true
            picker.videoQuality = .typeMedium
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: {[weak self]   _ in
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .camera
            picker.allowsEditing = true
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true)
    }
    
    private func listenForMessages(id : String, shouldScrollToBottom : Bool){
        DatabaseManager.shared.getAllMessagesForConversations(for: id, completion: {[weak self] result in
            switch result{
            case .success(let messages):
                guard !messages.isEmpty else{
                    return
                }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()

                    if shouldScrollToBottom{
                        self?.messagesCollectionView.scrollToLastItem()

                    }
                }
            case .failure(let error):
                print("Failed to fetch messages \(error)")
            }
        })
    }
}

extension ChatViewController:UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard
              let messageID = createMessageId(),
              let conversationId = conversationId,
              let name = self.title,
                let selfSender = self.selfSender
        else{
            return
        }
       if let  image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage,
          let imageData = image.pngData(){
           let fileName = "photo_message_"+messageID.replacingOccurrences(of: " ", with: "-") + ".png"
           //Upload image
           StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: { [weak self] result in
               guard let strongSelf = self else{
                   return
               }
               switch result{
               case .success(let urlString):
                   print("Uploading photo : \(urlString)")
                   guard let url = URL(string: urlString),
                         let placeholder = UIImage(systemName: "plus")
                   else{
                       return
                       
                   }
                   
                   let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                   
                   let message = Message(sender: selfSender,
                                         messageId:messageID,
                                         sentDate: Date(),
                                         kind: .photo(media))
                   
                   DatabaseManager.shared.sendMessageToConversation(to: conversationId, name: name, otheUserEmail: strongSelf.otheruserEmail, newMessage: message, completion: { success in
                       
                       if success{
                           print("Send a photo message")
                       }else{
                           print("failed to send  a photo message")
                           
                       }})
                   
               case .failure(let error):
                   print("Failed to upload message photo \(error)")
               }})
       }else if let videoUrl = info[.mediaURL] as? URL  {
           let fileName = "photo_message_"+messageID.replacingOccurrences(of: " ", with: "-") + ".png"
           //Upload image
           StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName,  completion: { [weak self] result in
               guard let strongSelf = self else{
                   return
               }
               switch result{
               case .success(let urlString):
                   print("Uploaded video : \(urlString)")
                   guard let url = URL(string: urlString),
                         let placeholder = UIImage(systemName: "plus")
                   else{
                       return
                       
                   }
                   
                   let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                   
                   let message = Message(sender: selfSender,
                                         messageId:messageID,
                                         sentDate: Date(),
                                         kind: .video(media))
                   
                   DatabaseManager.shared.sendMessageToConversation(to: conversationId, name: name, otheUserEmail: strongSelf.otheruserEmail, newMessage: message, completion: { success in
                       
                       if success{
                           print("Send a photo message")
                       }else{
                           print("failed to send  a photo message")
                           
                       }})
                   
               case .failure(let error):
                   print("Failed to upload message photo \(error)")
               }})       }
    }
}

extension   ChatViewController:InputBarAccessoryViewDelegate{
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        
        
        guard !text.replacingOccurrences(of: " ", with: "") .isEmpty,
        let selfSender = self.selfSender,
        let messageID = createMessageId()
        else{
            return
        }
        print(text)
        
        let message = Message(sender: selfSender,
                              messageId:messageID,
                              sentDate: Date(),
                              kind: .text(text))
            //Send message
        if isNewConversation{
            //Start a new conversation
         
            DatabaseManager.shared.createNewConversations(with: otheruserEmail, name: self.title ?? "Letter user",  firstMessage: message, completion: { [weak self] success in
                if success{
                    print("Message sent")
                    self?.isNewConversation = false
                    let newConversationID =  "conversation_\(message.messageId)"
                    self?.conversationId = newConversationID
                    self?.listenForMessages(id: newConversationID, shouldScrollToBottom: true)
                    self?.messageInputBar.inputTextView.text = nil
                }else{
                    print("message failed to send")
                }
            })
        }else{
            //Append to existing conversation - chat
            guard let conversationId = conversationId, let name = self.title else{
                            return
            }
            DatabaseManager.shared.sendMessageToConversation(to: conversationId, name: name, otheUserEmail: otheruserEmail, newMessage: message, completion: {[weak self] success in
                if success {
                    print("Success")
                    self?.messageInputBar.inputTextView.text = nil

                }else{
                    print("Failed to send")
                }
            })
        }
    }
    
    private func createMessageId() -> String?{
        guard let currentUserEmail  = UserDefaults.standard.string(forKey: "email")
        else {
            return nil
        }
        let safeMail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        let date = Self.dataFormatter.string(from: Date())
        let newIdentifier = "\(otheruserEmail)_\(safeMail)_\(date)"
        print("Created message id \(newIdentifier)")
        return newIdentifier
    }
}

extension ChatViewController:MessagesDataSource,MessagesLayoutDelegate,MessagesDisplayDelegate{
    func currentSender() -> MessageKit.SenderType {

        if let sender = selfSender{
            return sender
        }
//        return Sender(senderId: "", displayName: "", photoUrl:"")
        fatalError("Self sender is nil")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageKit.MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else{ 
            return
        }
        
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else { return }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            break
        }
        
    }
    
    
}
extension ChatViewController:MessageCellDelegate{
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else{
            return
        }
        let message = messages[indexPath.section]
        switch message.kind {
        case .location(let locationData):
            let coordinates = locationData.location.coordinate 
            let vc = LocationPickerViewController(coordinates: coordinates)
            vc.title = "Location"
            self.navigationController?.pushViewController(vc, animated: true)
            
    
        default:
            break
        }
        
    }
    func didTapImage(in cell: MessageCollectionViewCell)
    {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else{
            return
        }
        let message = messages[indexPath.section]
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else { return }
            let vc = PhotoViewerViewController(with: imageUrl)
            self.navigationController?.pushViewController(vc, animated: true)
            
        case .video(let media):
            guard let videoUrl = media.url else { return }
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            present(vc, animated: true)
    
        default:
            break
        }
        
    }
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId{
            return .link
        }
        return .secondarySystemBackground
    }
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId{
            //Show our image
            if let currentImageUrl = senderPhotoUrl{
                avatarView.sd_setImage(with: currentImageUrl,completed: nil)
            }else{
                //Fetch our image
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else{   return     }
                 let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                StorageManager.shared.downloadUrl(for: path, completion: {[weak self] result in
                    switch result {
                    case .success(let url):
                        self?.senderPhotoUrl = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)

                        }
                    case .failure(let error):
                        print("\(error)")
                    }
                })
            }
        }else{
            //Show other user image
            if let otherUserPhotoUrl = otherUserPhotoUrl{
                avatarView.sd_setImage(with: otherUserPhotoUrl, completed: nil)
            }else{
                //Fetch our image
                 let email = otheruserEmail
                 let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                StorageManager.shared.downloadUrl(for: path, completion: {[weak self] result in
                    switch result {
                    case .success(let url):
                        self?.otherUserPhotoUrl = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)

                        }
                    case .failure(let error):
                        print("\(error)")
                    }
                })
            }
            
        }
    }
}
