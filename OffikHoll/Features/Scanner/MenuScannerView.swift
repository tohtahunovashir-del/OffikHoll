import SwiftUI
import PhotosUI
import VisionKit

/// Full-screen scanning flow presented from the menu editor.
///
/// 1. Capture pages with the document camera (or import photos / paste text).
/// 2. Vision OCR + preprocessing with a live progress screen.
/// 3. Interactive review where every dish stays editable.
/// 4. The waiter confirms, and only checked rows are written to GRDB.
struct MenuScannerView: View {
    @EnvironmentObject private var menu: MenuStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model = ScannerViewModel()

    @State private var showCamera = false
    @State private var showPasteSheet = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var importResult: MenuImportResult?

    var body: some View {
        ZStack {
            AppBackground()

            switch model.stage {
            case .capture:
                captureScreen
                    .transition(.opacity)
            case .processing:
                processingScreen
                    .transition(.opacity)
            case .review:
                ScanReviewView(
                    drafts: $model.drafts,
                    onBack: { model.stage = .capture },
                    onImported: { result in
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            importResult = result
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if let result = importResult {
                successOverlay(result)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: model.stage)
        .fullScreenCover(isPresented: $showCamera) {
            DocumentScannerView(
                onScan: { images in
                    showCamera = false
                    appendScannedImages(images)
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPasteSheet) {
            PasteMenuSheet { text in
                model.parsePastedText(text, existingCategories: menu.categories.map(\.name))
            }
        }
        .errorAlert($model.errorMessage)
        .onChange(of: photoSelectionKey) { _ in
            loadPhotos(photoItems)
        }
        .interactiveDismissDisabled(model.stage == .processing || importResult != nil)
    }

    private var photoSelectionKey: [String] {
        photoItems.compactMap(\.itemIdentifier)
    }

    // MARK: - Capture

    private var captureScreen: some View {
        VStack(spacing: 0) {
            captureHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    heroCard

                    if !model.pages.isEmpty {
                        pagesSection
                    }

                    scanActions

                    offlineNote
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
            .safeAreaInset(edge: .bottom) {
                if !model.pages.isEmpty {
                    recognizeBar
                }
            }
        }
    }

    private var captureHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            CircleIconButton(icon: "xmark", accessibilityTitle: "Закрыть сканер") {
                dismiss()
            }

            VStack(alignment: .leading, spacing: 3) {
                SectionLabel(text: "Импорт меню")
                Text("Сканировать меню")
                    .font(Typeface.display(27, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 6)

            HStack(spacing: 5) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 10, weight: .semibold))
                Text("VISION")
                    .font(.system(size: 9.5, weight: .bold))
                    .kerning(0.8)
            }
            .foregroundColor(Palette.gold)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(Capsule().fill(Palette.goldSoft))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Palette.gold.opacity(0.22), Palette.gold.opacity(0.07)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(Palette.gold)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Фото или скан")
                        .font(Typeface.display(20, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    Text("Сфотографируйте страницу меню — приложение найдёт названия, цены и категории прямо на устройстве.")
                        .font(.system(size: 12.5))
                        .foregroundColor(Palette.inkSecondary)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            DividerLine()

            VStack(spacing: 10) {
                pipelineRow(index: 1, icon: "crop.rotate", title: "Документ-камера", detail: "Автоматически выравнивает страницу")
                pipelineRow(index: 2, icon: "text.viewfinder", title: "Vision OCR", detail: "Русский, английский и ещё 6 языков")
                pipelineRow(index: 3, icon: "slider.horizontal.3", title: "Разбор меню", detail: "Названия, цены, порции, категории")
                pipelineRow(index: 4, icon: "checklist", title: "Проверка", detail: "Правите всё перед добавлением")
            }
        }
        .padding(16)
        .premiumCard()
    }

    private func pipelineRow(index: Int, icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(Palette.accentSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(Palette.inkSecondary)
            }
            Spacer(minLength: 4)
            Text("0\(index)")
                .font(Typeface.number(11, weight: .semibold))
                .foregroundColor(Palette.inkTertiary)
        }
    }

    // MARK: - Pages

    private var pagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Страницы · \(model.pages.count)")
                Spacer()
                Button {
                    model.pages.removeAll()
                    Haptics.impact(.light)
                } label: {
                    Text("Очистить")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Palette.danger)
                        .frame(minHeight: 32)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(model.pages.indices), id: \.self) { index in
                        pageThumbnail(index: index)
                    }
                    addPageTile
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func pageThumbnail(index: Int) -> some View {
        let page = model.pages[index]
        return ZStack(alignment: .topTrailing) {
            Image(uiImage: page.image)
                .resizable()
                .scaledToFill()
                .frame(width: 116, height: 152)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                model.removePage(id: page.id)
                Haptics.impact(.light)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .padding(6)

            VStack {
                Spacer()
                Text(page.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 26)
                    .background(Color.black.opacity(0.55))
            }
            .frame(width: 116, height: 152)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.stroke, lineWidth: 1)
        )
    }

    private var addPageTile: some View {
        Button {
            openCamera()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 22, weight: .light))
                Text("Страница")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(Palette.inkSecondary)
            .frame(width: 116, height: 152)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.surface.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        Palette.strokeStrong,
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var scanActions: some View {
        VStack(spacing: 10) {
            Button {
                openCamera()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                    Text(model.pages.isEmpty ? "Сканировать страницу" : "Добавить страницу")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!VNDocumentCameraViewController.isSupported)
            .opacity(VNDocumentCameraViewController.isSupported ? 1 : 0.5)

            if !VNDocumentCameraViewController.isSupported {
                Text("Документ-камера недоступна на этом устройстве. Используйте галерею или вставку текста.")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            HStack(spacing: 10) {
                PhotosPicker(
                    selection: $photoItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    actionTile(
                        icon: isLoadingPhotos ? "hourglass" : "photo.on.rectangle.angled",
                        title: "Из галереи",
                        subtitle: "До 10 страниц"
                    )
                }

                Button {
                    showPasteSheet = true
                } label: {
                    actionTile(
                        icon: "text.alignleft",
                        title: "Вставить текст",
                        subtitle: "Строки с ценами"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionTile(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(Palette.accent)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Palette.ink)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.stroke, lineWidth: 1)
        )
    }

    private var offlineNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Palette.accent)
            Text("Распознавание выполняется на устройстве. Фотографии никуда не отправляются и работают без сети.")
                .font(.system(size: 10.5))
                .foregroundColor(Palette.inkSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.accentSoft.opacity(0.7))
        )
    }

    private var recognizeBar: some View {
        VStack(spacing: 0) {
            Button {
                startRecognition()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Распознать · \(AppFormat.plural(model.pages.count, "страница", "страницы", "страниц"))")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            Palette.surface
                .overlay(alignment: .top) {
                    Rectangle().fill(Palette.stroke).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Processing

    private var processingScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    model.cancelRecognition()
                } label: {
                    Text("Отменить")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Palette.inkSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(Capsule().fill(Palette.surface))
                        .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer(minLength: 10)

            ZStack {
                Circle()
                    .stroke(Palette.stroke, lineWidth: 10)
                    .frame(width: 176, height: 176)
                Circle()
                    .trim(from: 0, to: max(0.02, model.progress))
                    .stroke(
                        AngularGradient(
                            colors: [Palette.gold, Palette.accent, Palette.gold],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 176, height: 176)
                    .animation(.easeInOut(duration: 0.35), value: model.progress)

                VStack(spacing: 2) {
                    Text("\(Int(model.progress * 100))%")
                        .font(Typeface.number(36, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    Text("на устройстве")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Palette.inkTertiary)
                }
            }
            .padding(.bottom, 26)

            VStack(spacing: 6) {
                Text("Распознаём меню")
                    .font(Typeface.display(28, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Text(model.stageTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 12) {
                processingStep(icon: "wand.and.rays", title: "Улучшение изображения", threshold: 0.02)
                processingStep(icon: "text.viewfinder", title: "Vision OCR", threshold: 0.05)
                processingStep(icon: "list.bullet.indent", title: "Строки и колонки", threshold: 0.78)
                processingStep(icon: "fork.knife", title: "Блюда и цены", threshold: 0.92)
            }
            .padding(16)
            .premiumCard()
            .padding(.horizontal, 16)

            Spacer(minLength: 20)

            Text("Обычно занимает 3–8 секунд на страницу")
                .font(.system(size: 11))
                .foregroundColor(Palette.inkTertiary)
                .padding(.bottom, 18)
        }
    }

    private func processingStep(icon: String, title: String, threshold: Double) -> some View {
        let isDone = model.progress > threshold + 0.01
        let isActive = !isDone && model.progress >= threshold
        return HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(isDone ? Palette.accentSoft : (isActive ? Palette.goldSoft : Palette.surfaceMuted))
                    .frame(width: 30, height: 30)
                Image(systemName: isDone ? "checkmark" : icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isDone ? Palette.accent : (isActive ? Palette.gold : Palette.inkTertiary))
            }
            Text(title)
                .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                .foregroundColor(isDone || isActive ? Palette.ink : Palette.inkTertiary)
            Spacer()
            if isActive {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
            } else if isDone {
                Text("готово")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(Palette.accent)
            }
        }
    }

    // MARK: - Success

    private func successOverlay(_ result: MenuImportResult) -> some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Palette.accentSoft)
                        .frame(width: 76, height: 76)
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(Palette.accent)
                }

                VStack(spacing: 5) {
                    Text("Меню обновлено")
                        .font(Typeface.display(24, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    Text(result.summaryText)
                        .font(.system(size: 13))
                        .foregroundColor(Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 9) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Готово")
                    }
                    .buttonStyle(PrimaryButtonStyle(compact: true))

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            importResult = nil
                        }
                        model.reset()
                    } label: {
                        Text("Сканировать ещё")
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
            .shadow(color: Palette.shadow.opacity(0.22), radius: 36, x: 0, y: 18)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Helpers

    private func openCamera() {
        guard VNDocumentCameraViewController.isSupported else {
            model.errorMessage = "Документ-камера недоступна на этом устройстве. Выберите фото из галереи или вставьте текст меню."
            return
        }
        Haptics.impact(.light)
        showCamera = true
    }

    private func appendScannedImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        for image in images {
            model.addPage(image)
        }
        Haptics.success()
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isLoadingPhotos = true
        Task {
            var loaded: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loaded.append(image)
                }
            }
            await MainActor.run {
                for image in loaded {
                    model.addPage(image)
                }
                isLoadingPhotos = false
                photoItems = []
                if loaded.isEmpty {
                    model.errorMessage = "Не удалось прочитать выбранные фотографии."
                } else {
                    Haptics.success()
                }
            }
        }
    }

    private func startRecognition() {
        guard !model.pages.isEmpty else { return }
        Haptics.impact(.medium)
        let existingCategories = menu.categories.map(\.name)
        var customWords = existingCategories
        customWords.append(contentsOf: menu.items.map(\.name))
        let uniqueWords = Array(Set(customWords)).sorted()
        Task {
            await model.recognize(
                existingCategories: existingCategories,
                customWords: uniqueWords
            )
        }
    }
}
