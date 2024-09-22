//
//  DatabaseManager.swift
//  Letter
//
//  Created by Adithya on 15/08/24.
//

import Foundation
import FirebaseDatabase
import MessageKit
import CoreLocation
final class DatabaseManager{
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    static func safeEmail(emailAddress : String) -> String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}
extension DatabaseManager{
    func getAllData(path : String, completion: @escaping (Result<Any,Error>) -> Void){
        self.database.child(path).observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
}
//MARK: - Account management section
extension DatabaseManager{
    
    public func userExists(with email:String, completion: @escaping((Bool) -> (Void)) ){
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            
            guard snapshot.value as? [String : Any] != nil else{
                completion(false)
                return
            }
            completion(true)
        })
    }

    ///Inserts new user into database
    public func insertUser(with User : ChatAppUser, completion:@escaping  (Bool) -> Void){
        database.child(User.safeEmail).setValue([
            "first_name" : User.firstName,
            "last_name" : User.lastName
        ],withCompletionBlock: { [weak self] error, _ in
            guard let strongSelf = self else{
                return
            }
            guard error == nil else{
                print("Failed to write to database")
                completion(false)
                return
            }
            strongSelf.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
     
                if var usersCollection = snapshot.value as? [[String:String]] {
                    let newElement = [
                            "name":User.firstName + " " + User.lastName,
                            "email":User.safeEmail
                        ]
                    usersCollection.append(newElement)
                    strongSelf.database.child("users").setValue(usersCollection,withCompletionBlock: { error, _ in
                        guard  error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)

                    })
                    
                }else{
                    let newCollection : [[String : String]] = [
                        
                        [
                            "name":User.firstName + " " + User.lastName,
                            "email":User.safeEmail
                        ]
                    ]
                    strongSelf.database.child("users").setValue(newCollection,withCompletionBlock: { error, _ in
                        guard  error == nil else{
                            completion(false)

                            return
                        }
                        completion(true)

                    })
                }
                
            })
        }
        )
        
    }
    
    
    public  func getAllUsers(completion: @escaping (Result<[[String:String]],Error>) -> Void){
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String:String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public enum DatabaseError:Error{
        case failedToFetch
    }
}

//MARK: - Sending  messages or conversations
extension DatabaseManager{
    
    //Creates a new message with target user email and first message
    public func createNewConversations(with otherUserEmail: String, name:String, firstMessage:Message, completion:@escaping(Bool) -> Void){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email")  as? String,
                    let currentName = UserDefaults.standard.value(forKey: "name") as? String
        else{
            return
        }
        let safemail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let reference = database.child("\(safemail)")
        reference.observeSingleEvent(of: .value, with: {[weak self]  snapshot in
            guard var userNode = snapshot.value as? [String:Any] else{
                completion(false)
                print("user not found!")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dataFormatter.string(from: messageDate)
            var message = ""
            switch firstMessage.kind{
                
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            let conversationID =  "conversation_\(firstMessage.messageId)"
            
            let newConversationData:[String:Any] = [
                "id" :conversationID,
                "other_user_email" : otherUserEmail,
                "name":name,
                "latest_message" : [
                "date" : dateString,
                "message" : message,
                "is_read" : false
                ]
            ]
            let recipient_newConversationData:[String:Any] = [
                "id" :conversationID,
                "other_user_email" : safemail,
                "name":currentName,
                "latest_message" : [
                "date" : dateString,
                "message" : message,
                "is_read" : false
                ]
            ]
            
            
            //Update receipient conversation entry
            
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String:Any]] {
                    //Append
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                    
                }
                    else{
                        self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })
            
            
            //Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String:Any]] {
                //Converation array exists for the current user
                //Append the chat
                conversations.append(newConversationData)
                reference.setValue(userNode, withCompletionBlock: {[weak self] error, _ in
                    guard error == nil else{
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name, conversationID: conversationID,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                    
                })
                
            }else
            {
                userNode["conversations"] = [
                    newConversationData
                ]
                reference.setValue(userNode, withCompletionBlock: { [weak self]error, _ in
                    guard error == nil else{
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name, conversationID: conversationID,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                    
                })
            }
        })
    }
    
    private func finishCreatingConversation(name:String, conversationID:String, firstMessage:Message, completion: @escaping (Bool) -> Void){
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dataFormatter.string(from: messageDate)
        var message = ""
        switch firstMessage.kind{
            
        case .text(let messageText):
            message = messageText
            
        case .attributedText(_):
            break
        case .photo(_):
            break
            
        case .video(_):
            break
            
        case .location(_):
            break
            
        case .emoji(_):
            break
            
        case .audio(_):
            break
            
        case .contact(_):
            break
            
        case .linkPreview(_):
            break
            
        case .custom(_):
            break
            
        }
        
        guard let email = UserDefaults.standard.value(forKey: "email") else{
            completion(false)
            return
        }
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: email as! String)
        let collectionMessage : [String : Any] = [
            
            "id" : firstMessage.messageId,
            "type" : firstMessage.kind.messageKindString,
            "content" : message,
            "date" : dateString,
            "sender_email" : currentUserEmail,
            "is_read" : false,
            "name" : name

        ]
        let value : [String : Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, _  in
            guard error == nil else{
                completion(false)
                return
                
            }
            completion(true)
        })
    }
    //Fetches all conversations for user passed in email
        public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
            database.child("\(email)/conversations").observe(.value, with: { snapshot in
                guard let value = snapshot.value as? [[String: Any]] else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                let conversations: [Conversation] = value.compactMap ({ dictionary in
                    guard let conversationId = dictionary["id"] as? String,
                          let name = dictionary["name"] as? String,
                          let otherUserMail = dictionary["other_user_email"] as? String,
                          let latestMessageDict = dictionary["latest_message"] as? [String: Any],
                          let date = latestMessageDict["date"] as? String,
                          let message = latestMessageDict["message"] as? String,
                          let isRead = latestMessageDict["is_read"] as? Bool else {
                        
                        print("No conversation available")
                        return nil // If any of these are nil, return nil so the compactMap will skip this entry
                    }
                let latestMessageObject = latestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: conversationId, otherUserEmail: otherUserMail, name: name, latestMessage: latestMessageObject)
            })
                print("success fetching all the  conversation available")

                completion(.success(conversations))
        })
        
    }

    //Get all the messages for the given conversatons
    public func getAllMessagesForConversations(for id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }

            let messages: [Message] = value.compactMap { dictionary in
                guard let id = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let name = dictionary["name"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let datestring = dictionary["date"] as? String,
                      let date = ChatViewController.dataFormatter.date(from: datestring) else {
                    // Skip this dictionary entry if any of the required fields are missing or invalid
                    return nil
                }

                var kind: MessageKind?

                switch type {
                case "photo":
                    if let imageUrl = URL(string: content),
                       let placeholder = UIImage(systemName: "plus") {
                        let media = Media(url: imageUrl, image: nil, placeholderImage: placeholder, size: CGSize(width: 300, height: 300))
                        kind = .photo(media)
                    }

                case "video":
                    if let videoUrl = URL(string: content),
                       let placeholder = UIImage(named: "nopreview") {
                        let media = Media(url: videoUrl, image: nil, placeholderImage: placeholder, size: CGSize(width: 300, height: 300))
                        kind = .video(media)
                    }

                case "location":
                    let locationComponent = content.components(separatedBy: ",")
                    if let longitude = Double(locationComponent.first ?? ""),
                       let latitude = Double(locationComponent.last ?? "") {
                        let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: CGSize(width: 300, height: 300))
                        kind = .location(location)
                    }

                default:
                    kind = .text(content)
                }

                guard let finalKind = kind else {
                    // Skip this message if the kind is invalid
                    return nil
                }

                let sender = Sender(senderId: senderEmail, displayName: name, photoUrl: "")
                return Message(sender: sender, messageId: id, sentDate: date, kind: finalKind)
            }

            print("success fetching all the conversation available")
            completion(.success(messages))
        })
    }

    //Send an message to target conversation
    public func sendMessageToConversation(to conversationID: String, name : String, otheUserEmail: String, newMessage:Message, completion:@escaping(Bool) -> Void){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            completion(false)
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        
        database.child("\(conversationID)/messages").observeSingleEvent(of: .value, with: {[weak self] snapshot in
            guard let strongSelf = self else{
                return
                
            }
            guard var currentMessages =  snapshot.value as? [[String:Any]] else{
                completion(false)
                return
                
            }
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dataFormatter.string(from: messageDate)
            var message = ""
            switch newMessage.kind{
                
            case .text(let messageText):
                message = messageText
                
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetURl = mediaItem.url?.absoluteString{
                    message = targetURl
                }
                break
                
            case .video(let mediaItem):
                if let targetURl = mediaItem.url?.absoluteString{
                    message = targetURl
                }
                break
                
            case .location(let locationData):
                let location = locationData.location
                message = ("\(location.coordinate.longitude),\(location.coordinate.latitude)")
                break
                
            case .emoji(_):
                break
                
            case .audio(_):
                break
                
            case .contact(_):
                break
                
            case .linkPreview(_):
                break
                
            case .custom(_):
                break
                
            }
            
            guard let email = UserDefaults.standard.value(forKey: "email") else{
                completion(false)
                return
            }
            
            let currentUserEmail = DatabaseManager.safeEmail(emailAddress: email as! String)
            let newMessageEntry : [String : Any] = [
                "id" : newMessage.messageId,
                "type" : newMessage.kind.messageKindString,
                "content" : message,
                "date" : dateString,
                "sender_email" : currentUserEmail,
                "is_read" : false,
                "name" : name
            ]
            
            currentMessages.append(newMessageEntry)
            strongSelf.database.child("\(conversationID)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else{
                    completion(false)
                    return
                }
                strongSelf.database.child("\(safeEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    var databaseEntryConversations = [[String:Any]]()
                    
                    let updatedValue : [String : Any] = [
                        "date" : dateString,
                        "is_read" : false,
                        "message" : message
                    ]
                    
                    if var currentUserConversations = snapshot.value as? [[String:Any]] {
                        //We need to create conversation
                        var position = 0
                        var targetConversation : [String:Any]?

                        for conversationDictionary in currentUserConversations{
                            if let currentId = conversationDictionary["id"] as? String, currentId == conversationID{
                                targetConversation = conversationDictionary
                                break
                            }
                            position += 1
                        }
                        if var targetConversation = targetConversation{
                            targetConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targetConversation
                            databaseEntryConversations = currentUserConversations
                        }else{
                            let newConversationData:[String:Any] = [
                                "id" :conversationID,
                                "other_user_email" : DatabaseManager.safeEmail(emailAddress: otheUserEmail),
                                "name":name,
                                "latest_message" :  updatedValue
                                
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                    }else{
                        
                        let newConversationData:[String:Any] = [
                            "id" :conversationID,
                            "other_user_email" : DatabaseManager.safeEmail(emailAddress: otheUserEmail),
                            "name":name,
                            "latest_message" :  updatedValue
                            
                        ]
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }
                    strongSelf.database.child("\(safeEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        //Update latest message for recipient
                        strongSelf.database.child("\(otheUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            let updatedValue : [String : Any] = [
                                "date" : dateString,
                                "is_read" : false,
                                "message" : message
                            ]
                            guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else{
                                return
                                
                            }
                            var databaseEntryConversations = [[String:Any]]()

                            if var otherUserConversations = snapshot.value as? [[String:Any]] {
                                var targetConversation : [String:Any]?
                                var position = 0
                                for conversationDictionary in otherUserConversations{
                                    if let currentId = conversationDictionary["id"] as? String, currentId == conversationID{
                                        targetConversation = conversationDictionary
                                        break
                                    }
                                    position += 1
                                    
                                }
                                if var targetConversation = targetConversation{
                                    targetConversation["latest_message"] = updatedValue
                                    otherUserConversations[position] = targetConversation
                                    databaseEntryConversations = otherUserConversations
                                }else{
                                    //Failed to find in current collection
                                    let newConversationData:[String:Any] = [
                                        "id" :conversationID,
                                        "other_user_email" : DatabaseManager.safeEmail(emailAddress: currentEmail),
                                        "name":currentName,
                                        "latest_message" :  updatedValue
                                        
                                    ]
                                    otherUserConversations.append(newConversationData)
                                    databaseEntryConversations = otherUserConversations
                                }

                            }else{
                                //Current collection does not exists
                                let newConversationData:[String:Any] = [
                                    "id" :conversationID,
                                    "other_user_email" : DatabaseManager.safeEmail(emailAddress: currentEmail),
                                    "name":currentName,
                                    "latest_message" :  updatedValue
                                    
                                ]
                                databaseEntryConversations = [
                                    newConversationData
                                ]

                            }
             
                           

                            strongSelf.database.child("\(otheUserEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                                
                                guard error == nil else{
                                    completion(false)
                                    return
                                }
                                completion(true)
                            })
                        })
                    })
                })
            }
        })
    }
    
    public func deleteConversation(conversationId:String, completion: @escaping (Bool) -> Void){
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return
            
        }
        print("Deleting conversation id : \(conversationId)")
        let safemail = DatabaseManager.safeEmail(emailAddress: email)
        let ref = database.child("\(safemail)/conversations")
            ref.observeSingleEvent(of: .value, with: { snapshot in
            if var conversations = snapshot.value as? [[String:Any]]{
                var positionToRemove = 0
                for conversation in conversations{
                    if let id = conversation["id"] as? String,
                        id == conversationId{
                        print("found the conversation to  be deleted!")

                        break
                        
                    }
                    positionToRemove += 1
                    
                }
                conversations.remove(at: positionToRemove)
                ref.setValue(conversations, withCompletionBlock: { error, _ in
                    guard error == nil else{
                        print("Unable to delete conversation")

                        completion(false)
                        return
                    }
                    print("Conversation has been deleted")
                    completion(true)
                })
            }
        })
        
    }
    
//    func conversationExists(with targetRecipientEmail:String, completion: @escaping(Result<String, Error>) -> Void){
//        let safeReciepientMail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
//        guard let senderMail = UserDefaults.standard.value(forKey: "email") as? String else{
//            return
//        }
//        let safeSenderMail = DatabaseManager.safeEmail(emailAddress: senderMail)
//        database.child("\(safeReciepientMail)/conversations").observe(.value, with: { snapshot in
//            guard let collection = snapshot.value as? [[String:Any]] else{
//                completion(.failure(DatabaseError.failedToFetch))
//                return
//            }
//            
//            ///Iterate and find conversations with target sender
//            if let conversation = collection.first(where: {
//                
//                guard let targetSenderMail = $0["other_user_mail"] as? String else{
//                    return false
//                }
//                return safeSenderMail == targetSenderMail
//            } ){
//                //get id
//                guard let id = conversation["id"] as? String else{
//                    completion(.failure(DatabaseError.failedToFetch))
//
//                    return
//                }
//                completion(.success(id))
//                return
//            }
//            completion(.failure(DatabaseError.failedToFetch))
//            return
//        })
//    }
//}
    public func conversationExists(with targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
        let safeRecipientEmail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)

        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
            guard let collection = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }

            // iterate and find conversation with target sender
            if let conversation = collection.first(where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else {
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }) {
                // get id
                guard let id = conversation["id"] as? String else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(id))
                return
            }

            completion(.failure(DatabaseError.failedToFetch))
            return
        })
    }

}
struct ChatAppUser{
    let firstName:String
    let lastName:String
    let emailAddress:String
    var safeEmail:String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profilePictureFileName:String{
        return "\(safeEmail)_profile_picture.png"
    }

}
