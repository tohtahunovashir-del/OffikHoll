import Foundation
import SwiftUI

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var editor: MenuEditorViewModel
    @StateObject private var viewModel = ScannerViewModel()

    init(editor: MenuEditorViewModel) {
        self.editor = editor
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.showReview {
                    ScanResultView(viewModel: viewModel, editor: editor)
                } else {
                    CameraScreen { image in
                        viewModel.process(image: image)
                    }

                    if viewModel.isProcessing {
                        processingOverlay
                    }
                }
            }
            .navigationTitle(viewModel.showReview ? "Проверка меню" : "Сканировать меню")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.showReview ? "Заново" : "Закрыть") {
                        if viewModel.showReview {
                            viewModel.reset()
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Ошибка", isPresented: errorBinding) {
                Button("Понятно", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text("Распознаём меню…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text("Предобработка, Vision и разбор строк")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.55))
            )
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && !viewModel.isProcessing },
            set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            }
        )
    }
}
