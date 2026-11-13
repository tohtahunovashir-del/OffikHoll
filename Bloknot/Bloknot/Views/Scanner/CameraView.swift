import Foundation
import AVFoundation
import Combine
import PhotosUI
import SwiftUI
import UIKit

// MARK: - Controller

final class CameraController: NSObject, ObservableObject {
    @Published private(set) var isAvailable = true
    @Published private(set) var isRunning = false
    @Published var errorMessage: String?
    @Published var capturedImage: UIImage?

    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.bloknot.camera.session")
    private var isConfigured = false

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                DispatchQueue.main.async {
                    self.isAvailable = false
                    self.errorMessage = "Нет доступа к камере. Разрешите его в настройках iPhone."
                }
                return
            }
            self.sessionQueue.async {
                self.configureIfNeeded()
                guard self.isConfigured else { return }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                DispatchQueue.main.async {
                    self.isRunning = true
                }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    func capture() {
        guard isConfigured else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func resetCapture() {
        capturedImage = nil
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            DispatchQueue.main.async {
                self.isAvailable = false
                self.errorMessage = "Камера недоступна. Выберите снимок из галереи."
            }
            return
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            DispatchQueue.main.async {
                self.isAvailable = false
                self.errorMessage = "Не удалось подготовить камеру."
            }
            return
        }
        session.addOutput(photoOutput)
        isConfigured = true
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async {
                self.errorMessage = "Снимок не получился. Попробуйте ещё раз."
            }
            return
        }
        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}

// MARK: - Preview

struct CameraView: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = layer as? AVCaptureVideoPreviewLayer else {
                return AVCaptureVideoPreviewLayer()
            }
            return layer
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

// MARK: - Screen

struct CameraScreen: View {
    @StateObject private var controller = CameraController()
    @State private var pickerItem: PhotosPickerItem?

    let onCapture: (UIImage) -> Void

    init(onCapture: @escaping (UIImage) -> Void) {
        self.onCapture = onCapture
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if controller.isAvailable {
                CameraView(session: controller.session)
                    .ignoresSafeArea()
            } else {
                unavailableState
            }

            VStack {
                Spacer()
                if let message = controller.errorMessage {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
                controls
            }
        }
        .onAppear {
            controller.start()
        }
        .onDisappear {
            controller.stop()
        }
        .onChange(of: controller.capturedImage) { image in
            guard let image = image else { return }
            controller.resetCapture()
            onCapture(image)
        }
    }

    private var controls: some View {
        HStack(alignment: .center, spacing: 24) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20, weight: .medium))
                    Text("Галерея")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 66, height: 58)
            }
            .onChange(of: pickerItem) { item in
                loadPickedImage(item)
            }

            Button {
                controller.capture()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 4)
                        .frame(width: 74, height: 74)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                }
            }
            .buttonStyle(.plain)
            .disabled(!controller.isAvailable)
            .opacity(controller.isAvailable ? 1 : 0.4)

            VStack(spacing: 4) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 20, weight: .medium))
                Text("Ровно")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.65))
            .frame(width: 66, height: 58)
        }
        .padding(.bottom, 28)
    }

    private var unavailableState: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(.white.opacity(0.7))
            Text("Камера недоступна")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text("На симуляторе камеры нет. Снимите меню на устройстве или выберите готовое фото.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func loadPickedImage(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    pickerItem = nil
                    onCapture(image)
                }
            } else {
                await MainActor.run {
                    pickerItem = nil
                }
            }
        }
    }
}
