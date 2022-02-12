//
//  MainViewController.swift
//  CoreML Demo
//
//  Created by Leo Ho on 2022/1/26.
//

import UIKit
import CoreML
import Vision
import Photos
import PhotosUI
import ImageIO

// MARK: - Data Flow
/*
 1.Click Camera Button or Photo Button
 2.Get Photo
 3.UIImagePickerViewControllerDelegate or PHPickerViewControllerDelegate to show Image
 4.Call Function updateClassifications
 5.Create and Init VNCoreMLRequest
 6.Call Function processClassifications
 7.Show Classifications Results with Alert
 */

class MainViewController: UIViewController {

    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var photoButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    
    var classificationAns: String = "" // 用來儲存分類結果
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 如果相機不能用，就將相機按鈕隱藏
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraButton.isHidden = true
            return
        }
        
        cameraButton.setTitle(NSLocalizedString("Camera", comment: ""), for: .normal)
        photoButton.setTitle(NSLocalizedString("Photo", comment: ""), for: .normal)
    }
    
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: PeopleImageClassifier().model) // PeopleImageClassifier 是 mlmodel 的檔名
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                self?.processClassifications(request: request, error: error)
            }
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()

    func processClassifications(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                self.classificationAns = String.localizedStringWithFormat(NSLocalizedString("Unable Classify Image!\nError:", comment: ""), error?.localizedDescription as! CVarArg)
                self.presentAlert(message: self.classificationAns)
                return
            }
            let classifications = results as! [VNClassificationObservation]
            if (classifications.isEmpty) {
                self.classificationAns = NSLocalizedString("Nothing Recognized!", comment: "")
            } else {
                let topClassifications = classifications.prefix(2)
                let descriptions = topClassifications.map { classification in
                    return String(format: "(%.2f) %@", classification.confidence, classification.identifier)
                }
                self.classificationAns = descriptions.joined(separator: "\n")
            }
            self.presentAlert(message: self.classificationAns)
        }
    }
    
    func updateClassifications(image: UIImage) {
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        guard let ciImage = CIImage(image: image) else {
            fatalError("Unable to create \(CIImage.self) from \(image).")
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                print("Failed to perform classification.\n\(error.localizedDescription)")
                self.presentAlert(message: String.localizedStringWithFormat(NSLocalizedString("Failed to perform classification.", comment: ""), error.localizedDescription))
            }
        }
    }
    
    @IBAction func cameraBtn(_ sender: UIButton) {
        presentCamera(imageType: .camera)
    }
    
    @IBAction func choosePhotoBtn(_ sender: UIButton) {
        presentPhotoPicker()
    }
    
    func presentCamera(imageType: UIImagePickerController.SourceType) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = imageType
        present(imagePicker, animated: true)
    }
    
    func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1 // 設定可以選取的數量，0 = 無限制
        config.filter = .images // 設定顯示的類型
        let photoPicker = PHPickerViewController(configuration: config)
        photoPicker.delegate = self
        present(photoPicker, animated: true)
    }
    
    func presentAlert(message: String?) {
        let alertController = UIAlertController(title: NSLocalizedString("Classifications Results", comment: ""), message: message, preferredStyle: .alert)
        let closeAction = UIAlertAction(title: NSLocalizedString("Close", comment: ""), style: .default) { action in
            //
        }
        alertController.addAction(closeAction)
        present(alertController, animated: true)
    }
}

extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        let image = info[.originalImage] as! UIImage
        imageView.image = image
        updateClassifications(image: image)
    }
}

extension MainViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        for result in results {
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { data, error in
                    if let image = data as? UIImage {
                        DispatchQueue.main.async {
                            self.imageView.image = image
                            self.updateClassifications(image: image)
                        }
                    }
                }
            }
        }
    }
}
