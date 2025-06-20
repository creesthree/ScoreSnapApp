//
//  PhotoService.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import UIKit
import PhotosUI
import AVFoundation
import ImageIO
import CoreLocation

@MainActor
class PhotoService: NSObject, ObservableObject {
    @Published var isCameraAvailable = false
    @Published var isPhotoLibraryAvailable = false
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryPermissionStatus: PHAuthorizationStatus = .notDetermined
    
    private let imagePicker = UIImagePickerController()
    private var completionHandler: ((Result<UIImage, PhotoError>) -> Void)?
    
    override init() {
        super.init()
        checkPermissions()
        setupImagePicker()
    }
    
    // MARK: - Permission Management
    
    func checkPermissions() {
        checkCameraPermission()
        checkPhotoLibraryPermission()
    }
    
    private func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    private func checkPhotoLibraryPermission() {
        photoLibraryPermissionStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        isPhotoLibraryAvailable = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
    }
    
    func requestCameraPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            cameraPermissionStatus = granted ? .authorized : .denied
        }
        return granted
    }
    
    func requestPhotoLibraryPermission() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            photoLibraryPermissionStatus = status
        }
        return status == .authorized || status == .limited
    }
    
    // MARK: - Camera Capture
    
    func capturePhoto(from viewController: UIViewController) async throws -> UIImage {
        guard isCameraAvailable else {
            throw PhotoError.cameraNotAvailable
        }
        
        if cameraPermissionStatus != .authorized {
            let granted = await requestCameraPermission()
            guard granted else {
                throw PhotoError.cameraPermissionDenied
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.completionHandler = { result in
                    continuation.resume(with: result)
                }
                
                self.imagePicker.sourceType = .camera
                self.imagePicker.delegate = self
                viewController.present(self.imagePicker, animated: true)
            }
        }
    }
    
    // MARK: - Photo Library Selection
    
    func selectPhoto(from viewController: UIViewController) async throws -> UIImage {
        guard isPhotoLibraryAvailable else {
            throw PhotoError.photoLibraryNotAvailable
        }
        
        if photoLibraryPermissionStatus != .authorized && photoLibraryPermissionStatus != .limited {
            let granted = await requestPhotoLibraryPermission()
            guard granted else {
                throw PhotoError.photoLibraryPermissionDenied
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.completionHandler = { result in
                    continuation.resume(with: result)
                }
                
                self.imagePicker.sourceType = .photoLibrary
                self.imagePicker.delegate = self
                viewController.present(self.imagePicker, animated: true)
            }
        }
    }
    
    // MARK: - PHPickerViewController (Modern Photo Selection)
    
    func selectPhotoWithPHPicker(from viewController: UIViewController) async throws -> UIImage {
        guard isPhotoLibraryAvailable else {
            throw PhotoError.photoLibraryNotAvailable
        }
        
        if photoLibraryPermissionStatus != .authorized && photoLibraryPermissionStatus != .limited {
            let granted = await requestPhotoLibraryPermission()
            guard granted else {
                throw PhotoError.photoLibraryPermissionDenied
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                var configuration = PHPickerConfiguration(photoLibrary: .shared())
                configuration.filter = .images
                configuration.selectionLimit = 1
                
                let picker = PHPickerViewController(configuration: configuration)
                picker.delegate = self
                
                self.completionHandler = { result in
                    continuation.resume(with: result)
                }
                
                viewController.present(picker, animated: true)
            }
        }
    }
    
    // MARK: - Photo Validation
    
    func validatePhoto(_ image: UIImage) -> PhotoValidationResult {
        // Check if image is not nil
        guard image.cgImage != nil else {
            return .failure(.invalidImageFormat)
        }
        
        // Check minimum size (at least 100x100 pixels)
        let minSize: CGFloat = 100
        if image.size.width < minSize || image.size.height < minSize {
            return .failure(.imageTooSmall)
        }
        
        // Check maximum size (prevent memory issues)
        let maxSize: CGFloat = 4000
        if image.size.width > maxSize || image.size.height > maxSize {
            return .failure(.imageTooLarge)
        }
        
        // Check aspect ratio (reasonable for scoreboard photos)
        let aspectRatio = image.size.width / image.size.height
        if aspectRatio < 0.5 || aspectRatio > 3.0 {
            return .failure(.invalidAspectRatio)
        }
        
        return .success(image)
    }
    
    // MARK: - EXIF Metadata Extraction
    
    func extractEXIFMetadata(from image: UIImage) -> EXIFMetadata? {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            return nil
        }
        
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        
        let exif = properties["{Exif}"] as? [String: Any]
        let gps = properties["{GPS}"] as? [String: Any]
        let tiff = properties["{TIFF}"] as? [String: Any]
        
        return EXIFMetadata(
            dateTime: exif?["DateTimeOriginal"] as? String,
            dateTimeDigitized: exif?["DateTimeDigitized"] as? String,
            dateTimeSubsec: exif?["SubsecTimeOriginal"] as? String,
            exposureTime: exif?["ExposureTime"] as? Double,
            fNumber: exif?["FNumber"] as? Double,
            iso: exif?["ISOSpeedRatings"] as? Int,
            focalLength: exif?["FocalLength"] as? Double,
            flash: exif?["Flash"] as? Int,
            meteringMode: exif?["MeteringMode"] as? Int,
            whiteBalance: exif?["WhiteBalance"] as? Int,
            gpsLatitude: gps?["Latitude"] as? Double,
            gpsLongitude: gps?["Longitude"] as? Double,
            gpsAltitude: gps?["Altitude"] as? Double,
            gpsTimestamp: gps?["TimeStamp"] as? String,
            make: tiff?["Make"] as? String,
            model: tiff?["Model"] as? String,
            software: tiff?["Software"] as? String
        )
    }
    
    // MARK: - Image Processing
    
    func processImageForAnalysis(_ image: UIImage) -> UIImage {
        // Resize image to reasonable size for analysis
        let maxDimension: CGFloat = 1024
        let size = image.size
        
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    // MARK: - Setup
    
    private func setupImagePicker() {
        imagePicker.allowsEditing = false
        imagePicker.mediaTypes = ["public.image"]
    }
}

// MARK: - UIImagePickerControllerDelegate

extension PhotoService: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) {
            if let image = info[.originalImage] as? UIImage {
                self.completionHandler?(.success(image))
            } else {
                self.completionHandler?(.failure(.invalidImageFormat))
            }
            self.completionHandler = nil
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.completionHandler?(.failure(.userCancelled))
            self.completionHandler = nil
        }
    }
}

// MARK: - PHPickerViewControllerDelegate

extension PhotoService: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) {
            guard let result = results.first else {
                self.completionHandler?(.failure(.userCancelled))
                self.completionHandler = nil
                return
            }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self.completionHandler?(.success(image))
                    } else {
                        self.completionHandler?(.failure(.invalidImageFormat))
                    }
                    self.completionHandler = nil
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum PhotoError: LocalizedError {
    case cameraNotAvailable
    case photoLibraryNotAvailable
    case cameraPermissionDenied
    case photoLibraryPermissionDenied
    case invalidImageFormat
    case imageTooSmall
    case imageTooLarge
    case invalidAspectRatio
    case userCancelled
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "Camera is not available on this device"
        case .photoLibraryNotAvailable:
            return "Photo library is not available on this device"
        case .cameraPermissionDenied:
            return "Camera access is required to take photos"
        case .photoLibraryPermissionDenied:
            return "Photo library access is required to select photos"
        case .invalidImageFormat:
            return "Invalid image format"
        case .imageTooSmall:
            return "Image is too small for analysis"
        case .imageTooLarge:
            return "Image is too large for processing"
        case .invalidAspectRatio:
            return "Image aspect ratio is not suitable for scoreboard analysis"
        case .userCancelled:
            return "Photo selection was cancelled"
        case .processingFailed:
            return "Failed to process image"
        }
    }
}

enum PhotoValidationResult {
    case success(UIImage)
    case failure(PhotoError)
}

struct EXIFMetadata {
    let dateTime: String?
    let dateTimeDigitized: String?
    let dateTimeSubsec: String?
    let exposureTime: Double?
    let fNumber: Double?
    let iso: Int?
    let focalLength: Double?
    let flash: Int?
    let meteringMode: Int?
    let whiteBalance: Int?
    let gpsLatitude: Double?
    let gpsLongitude: Double?
    let gpsAltitude: Double?
    let gpsTimestamp: String?
    let make: String?
    let model: String?
    let software: String?
    
    var hasLocationData: Bool {
        return gpsLatitude != nil && gpsLongitude != nil
    }
    
    var hasDateTimeData: Bool {
        return dateTime != nil || dateTimeDigitized != nil
    }
    
    var formattedDateTime: String? {
        return dateTime ?? dateTimeDigitized
    }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = gpsLatitude, let lon = gpsLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
} 