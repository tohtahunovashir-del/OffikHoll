import SwiftUI
import PhotosUI
import AVFoundation

struct MenuScannerView: View {
    @EnvironmentObject private var store: RestaurantStore
    @Environment(\.dismiss) private var dismiss
    @State private var pages: [UIImage] = []
    @State private var selection: [PhotosPickerItem] = []
    @State private var recognizedText = ""
    @State private var parsedItems: [ParsedMenuItem] = []
    @State private var isRecognizing = false
    @State private var showingCamera = false
    @State private var exportURL: URL?
    @State private var scanError: String?

    var body: some View {
        VStack(spacing: 0) {
            if parsedItems.isEmpty {
                captureStage
            } else {
                confirmationStage
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(parsedItems.isEmpty ? "Сканер меню" : "Проверьте распознавание")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("Закрыть") { dismiss() } }
            if !parsedItems.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { exportRecognized(format: "json") } label: { Label("Экспорт JSON", systemImage: "curlybraces") }
                        Button { exportRecognized(format: "csv") } label: { Label("Экспорт CSV", systemImage: "tablecells") }
                    } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Экспорт распознанных блюд")
                }
            }
        }
        .sheet(isPresented: Binding(get: { exportURL != nil }, set: { if !$0 { exportURL = nil } })) {
            if let exportURL { ShareSheet(activityItems: [exportURL]) }
        }
        .onChange(of: selection) { newSelection in loadPages(newSelection) }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCapture { image in pages.append(image) }
                .ignoresSafeArea()
        }
        .alert("Сканирование не удалось", isPresented: Binding(get: { scanError != nil }, set: { if !$0 { scanError = nil } })) {
            Button("Понятно", role: .cancel) { scanError = nil }
        } message: { Text(scanError ?? "") }
    }

    private var captureStage: some View {
        VStack(spacing: 18) {
            if pages.isEmpty {
                Spacer()
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 116, height: 116)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 32))
                Text("Оцифруйте меню")
                    .font(.title2.weight(.bold))
                Text("Добавьте одну или несколько страниц. Распознавание выполняется на устройстве, без интернета.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 320)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Страницы меню").font(.headline)
                        Spacer()
                        Text("\(pages.count)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(pages.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: pages[index])
                                        .resizable().scaledToFill()
                                        .frame(width: 128, height: 168)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    Button { pages.remove(at: index) } label: {
                                        Image(systemName: "xmark.circle.fill").font(.title3).symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, Color.black.opacity(0.68))
                                    }
                                    .padding(7).frame(minWidth: 44, minHeight: 44)
                                }
                            }
                        }
                    }
                    if !recognizedText.isEmpty {
                        Text("Проверьте или исправьте распознанный текст, если блюда не извлеклись автоматически.")
                            .font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $recognizedText)
                            .font(.footnote.monospaced())
                            .frame(height: 130)
                            .padding(6)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        Button("Повторить разбор текста") {
                            parsedItems = MenuOCR.parseMenuItems(from: recognizedText)
                            if parsedItems.isEmpty { scanError = "Не найдены строки с названиями и ценами. Формат строки: «Блюдо 450 ₽»." }
                        }
                        .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 20)
                Spacer(minLength: 12)
            }
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button { showingCamera = true } label: {
                        Label("Камера", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .buttonStyle(.bordered)
                    PhotosPicker(selection: $selection, maxSelectionCount: 10, matching: .images) {
                        Label("Фото", systemImage: "photo.on.rectangle.angled")
                            .frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .buttonStyle(.bordered)
                }
                if !pages.isEmpty {
                    Button(action: recognize) {
                        HStack(spacing: 9) {
                            if isRecognizing { ProgressView().tint(.white) }
                            Text(isRecognizing ? "Распознаём страницы…" : "Распознать меню")
                        }
                        .font(.headline).frame(maxWidth: .infinity).frame(height: 54)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRecognizing)
                }
            }
            .padding(16)
            .background(.regularMaterial)
        }
    }

    private var confirmationStage: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("Выбрано: \(parsedItems.filter(\.isSelected).count) из \(parsedItems.count)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Label("Страниц: \(pages.count)", systemImage: "doc.on.doc")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            List {
                Section {
                    ForEach($parsedItems) { $item in
                        HStack(alignment: .top, spacing: 11) {
                            Button { item.isSelected.toggle() } label: {
                                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.title3).foregroundStyle(item.isSelected ? Color.accentColor : Color.secondary)
                                    .frame(width: 36, height: 44)
                            }
                            .buttonStyle(.plain).accessibilityLabel(item.isSelected ? "Исключить блюдо" : "Включить блюдо")
                            VStack(spacing: 7) {
                                TextField("Название блюда", text: $item.name)
                                    .font(.subheadline.weight(.semibold))
                                    .textInputAutocapitalization(.sentences)
                                HStack(spacing: 9) {
                                    TextField("Цена", value: $item.price, format: .number)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 90)
                                    Text("₽").foregroundStyle(.secondary)
                                    TextField("Категория", text: $item.category)
                                        .font(.caption).multilineTextAlignment(.trailing)
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 7)
                            .opacity(item.isSelected ? 1 : 0.48)
                        }
                        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                    }
                } header: { Text("Распознанные блюда · можно отредактировать") }
                Section("Распознанный текст") {
                    TextEditor(text: $recognizedText)
                        .frame(minHeight: 100)
                        .font(.footnote.monospaced())
                }
            }
            .listStyle(.insetGrouped)
            VStack(spacing: 9) {
                Button {
                    store.addScannedItems(parsedItems)
                    dismiss()
                } label: {
                    Text("Добавить в меню · \(parsedItems.filter(\.isSelected).count)")
                        .font(.headline).frame(maxWidth: .infinity).frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!parsedItems.contains(where: { $0.isSelected && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && $0.price > 0 }))
                Button("Сканировать ещё страницы") {
                    parsedItems = []
                    recognizedText = ""
                }
                .font(.subheadline.weight(.medium)).frame(minHeight: 40)
            }
            .padding(.horizontal, 16).padding(.bottom, 10).background(.regularMaterial)
        }
    }

    private func loadPages(_ selections: [PhotosPickerItem]) {
        guard !selections.isEmpty else { return }
        Task {
            var images: [UIImage] = []
            for item in selections {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            pages.append(contentsOf: images)
            selection = []
            if images.isEmpty { scanError = "Не удалось загрузить выбранные изображения." }
        }
    }

    private func exportRecognized(format: String) {
        do {
            let selected = parsedItems.filter(\.isSelected)
            let data: Data
            let fileName: String
            if format == "json" {
                let records = selected.map { ["name": $0.name, "price": $0.price, "category": $0.category] as [String: Any] }
                data = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
                fileName = "Распознанное-меню.json"
            } else {
                let rows = ["Название;Цена;Категория"] + selected.map { item in
                    "\"\(item.name.replacingOccurrences(of: "\"", with: "\"\""))\";\(item.price);\"\(item.category.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                data = ("\u{FEFF}" + rows.joined(separator: "\n")).data(using: .utf8) ?? Data()
                fileName = "Распознанное-меню.csv"
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch { scanError = "Не удалось создать файл экспорта: \(error.localizedDescription)" }
    }

    private func recognize() {
        guard !pages.isEmpty else { return }
        isRecognizing = true
        Task {
            do {
                var pageTexts: [String] = []
                for (index, image) in pages.enumerated() {
                    let text = try await MenuOCR.recognizeText(from: image)
                    pageTexts.append("— Страница \(index + 1) —\n\(text)")
                }
                recognizedText = pageTexts.joined(separator: "\n\n")
                parsedItems = MenuOCR.parseMenuItems(from: recognizedText)
                if parsedItems.isEmpty {
                    scanError = "Текст найден, но не удалось автоматически извлечь блюда с ценами. Проверьте качество фото или отредактируйте распознанный текст и попробуйте снова."
                }
            } catch { scanError = error.localizedDescription }
            isRecognizing = false
        }
    }
}

struct CameraCapture: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCapture
        init(parent: CameraCapture) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss.wrappedValue.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss.wrappedValue.dismiss() }
    }
}
