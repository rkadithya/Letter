//
//  PhotoViewerViewController.swift
//  Letter
//
//  Created by Adithya on 03/08/24.
//

import UIKit
class PhotoViewerViewController: UIViewController {
    
    private let url : URL
    
    private let imageView : UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        
        return imageView
    }()

    init(with url: URL){
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Photo"
        navigationItem.largeTitleDisplayMode = .never
        self.view.backgroundColor = .white
        view.addSubview(imageView)
        imageView.sd_setImage(with: self.url,completed: nil)
        
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        imageView.frame = view.bounds
    }
}
