import SwiftUI
import PhotosUI

/// The "Prove It" flow: capture a quick evidence photo (or pick one, if no camera is
/// available), watch it get analyzed, then see a hedged, human verification result.
struct CameraVerificationView: View {
    let habit: Habit
    let onVerified: (VerificationOutcome, String?) -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var camera = CameraController()
    @State private var verification: VerificationViewModel?
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let verification {
                    switch verification.phase {
                    case .ready:
                        readyState
                    case .captured, .scanning:
                        reviewAndScanState(verification)
                    case .result(let box):
                        VerificationResultView(outcome: box.outcome) {
                            finish(outcome: box.outcome, verification: verification)
                        } onRetake: {
                            verification.retake()
                        }
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.tint(.white)
                }
            }
            .task {
                if verification == nil {
                    verification = VerificationViewModel(service: services.verification)
                }
                await camera.requestAccessAndConfigure()
            }
            .onDisappear { camera.stop() }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var readyState: some View {
        switch camera.authorizationState {
        case .unknown:
            ProgressView().tint(.white)
        case .authorized:
            liveCameraView
        case .denied, .unavailable:
            fallbackPickerView
        }
    }

    private var liveCameraView: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack {
                VStack(spacing: 4) {
                    Text("Prove you showed up.")
                        .font(FMTheme.Typography.title2)
                        .foregroundStyle(.white)
                    Text(promptText)
                        .font(FMTheme.Typography.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, FMTheme.Spacing.lg)

                Spacer()

                RoundedRectangle(cornerRadius: FMTheme.Radius.xl, style: .continuous)
                    .stroke(.white.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .frame(width: 260, height: 260)
                    .overlay(
                        Text("Face inside the frame")
                            .font(FMTheme.Typography.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 280)
                    )

                Spacer()

                Button {
                    Task {
                        if let image = await camera.capturePhoto() {
                            verification?.setCaptured(image)
                        }
                    }
                } label: {
                    Circle()
                        .fill(.white)
                        .frame(width: 76, height: 76)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 4).frame(width: 88, height: 88))
                }
                .padding(.bottom, FMTheme.Spacing.xl)
            }
        }
    }

    private var fallbackPickerView: some View {
        VStack(spacing: FMTheme.Spacing.lg) {
            Spacer()
            Image(systemName: "camera.fill").font(.system(size: 40)).foregroundStyle(.white.opacity(0.6))
            Text("Camera unavailable")
                .font(FMTheme.Typography.title2)
                .foregroundStyle(.white)
            Text("Choose a photo instead to prove it.")
                .font(FMTheme.Typography.body)
                .foregroundStyle(.white.opacity(0.7))

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Choose Photo")
                    .font(FMTheme.Typography.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, FMTheme.Spacing.lg)
                    .padding(.vertical, FMTheme.Spacing.sm)
                    .background(.white)
                    .clipShape(Capsule())
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        verification?.setCaptured(image)
                    }
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func reviewAndScanState(_ verification: VerificationViewModel) -> some View {
        VStack(spacing: FMTheme.Spacing.lg) {
            Spacer()

            if let image = verification.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
                    .padding(.horizontal, FMTheme.Spacing.lg)
                    .overlay {
                        if case .scanning = verification.phase {
                            ScanningOverlay()
                        }
                    }
            }

            if case .scanning = verification.phase {
                Text("Checking...")
                    .font(FMTheme.Typography.headline)
                    .foregroundStyle(.white)
            }

            Spacer()

            if case .captured = verification.phase {
                HStack(spacing: FMTheme.Spacing.md) {
                    FMSecondaryButton(title: "Retake") { verification.retake() }
                    FMPrimaryButton(title: "Submit") {
                        Task { await verification.submit(for: habit) }
                    }
                }
                .padding(.horizontal, FMTheme.Spacing.lg)
                .padding(.bottom, FMTheme.Spacing.xl)
            }
        }
    }

    private var promptText: String {
        switch habit.name.lowercased() {
        case let n where n.contains("wake"): return "Take a quick photo showing you're awake."
        case let n where n.contains("workout"): return "Show us your workout in progress."
        case let n where n.contains("read"): return "Show your book or reading spot."
        default: return "Take a quick photo as evidence."
        }
    }

    private func finish(outcome: VerificationOutcome, verification: VerificationViewModel) {
        var fileName: String?
        if let image = verification.capturedImage {
            fileName = ImageStore.save(image)
        }
        onVerified(outcome, fileName)
        dismiss()
    }
}

#Preview {
    CameraVerificationView(habit: HabitCatalog.all[0].makeHabit()) { _, _ in }
}
