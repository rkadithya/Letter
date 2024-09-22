//
//  StorageManager.swift
//  Letter
//
//  Created by apple on 19/08/24.
//

import Foundation
import FirebaseStorage

final class StorageManager{
    static let shared = StorageManager()
    let storage = Storage.storage().reference()
    
    public typealias uploadProfilePicture = (Result<String, Error>) -> Void
    
    ///Uploads picture to firebase and returns string to download on completion
    public func uploadProfilePicture(with data:Data, fileName : String, completion:@escaping uploadProfilePicture){
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: { metaData, error in
            guard error == nil else{
                print("Failed to upload data to firebase ")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
      self.storage.child("images/\(fileName)").downloadURL(completion: {url,error in
                
                guard let url = url, error == nil else{
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
          let urlString = url.absoluteString
          print("Download URL - \(urlString)")
          completion(.success(urlString))
            })
        })
    }
    
    public enum StorageErrors : Error{
        case failedToUpload
        case failedToGetDownloadURL
    }
    
    public func downloadUrl(for path: String, completion: @escaping(Result<URL, Error>) -> Void){
        let reference = storage.child(path)
        reference.downloadURL(completion: { url, error in
            guard let url = url, error == nil else{
                completion(.failure(StorageErrors.failedToGetDownloadURL))
                return
            }
            completion(.success(url))
        } )
    }
    
    ///Uploads picture to firebase for chat / send photo
    public func uploadMessagePhoto(with data:Data, fileName : String, completion:@escaping uploadProfilePicture){
        storage.child("message_images/\(fileName)").putData(data, metadata: nil, completion: {[weak self] metaData, error in
            guard error == nil else{
                print("Failed to upload data to firebase ")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
      self?.storage.child("message_images/\(fileName)").downloadURL(completion: {url,error in
                
                guard let url = url, error == nil else{
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
          let urlString = url.absoluteString
          print("Download URL - \(urlString)")
          completion(.success(urlString))
            })
        })
    }
    
    ///Uploads Video to firebase for chat / send Video
    public func uploadMessageVideo(with fileUrl:URL, fileName : String, completion:@escaping uploadProfilePicture){
        storage.child("message_videos/\(fileName)").putFile(from: fileUrl, metadata: nil, completion:  {[weak self] metaData, error in
            guard error == nil else{
                print("Failed to upload data to firebase ")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
      self?.storage.child("message_videos/\(fileName)").downloadURL(completion: {url,error in
                
                guard let url = url, error == nil else{
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
          let urlString = url.absoluteString
          print("Download URL - \(urlString)")
          completion(.success(urlString))
            })
        })
    }
}
