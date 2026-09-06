import SwiftUI
import SwiftData
import PhotosUI

/// End-of-day flow: review what got done, add a journal entry and optional daily photo,
/// then lock in the day. Never frames a missed habit as a failure.
struct NightReviewView: View {
    let journey: Journey
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var journalText = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showRecap = false

    private var habits: [Habit] { journey.habits.sorted { $0.sortOrder < $1.sortOrder } }
    private var doneCount: Int { habits.filter { $0.completion(on: .now)?.state.isDone == true }.count }
    private var dailyScore: Int {
        guard !habits.isEmpty else { return 0 }
        return Int((Double(doneCount) / Double(habits.count) * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FMTheme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How did today go?").font(FMTheme.Typography.largeTitle)
                        Text("\(doneCount) of \(habits.count) habits done. \(dailyScore >= 70 ? "Nice work." : "That counts.")")
                            .font(FMTheme.Typography.body)
                            .foregroundStyle(FMTheme.Colors.textSecondary)
                    }

                    VStack(spacing: FMTheme.Spacing.xs) {
                        ForEach(habits) { habit in
                            let done = habit.completion(on: .now)?.state.isDone ?? false
                            HStack {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle.dashed")
                                    .foregroundStyle(done ? FMTheme.Colors.success : FMTheme.Colors.textTertiary)
                                Text(habit.name).foregroundStyle(FMTheme.Colors.textPrimary)
                                Spacer()
                            }
                            .padding(FMTheme.Spacing.sm)
                            .background(FMTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                        Text("Journal").font(FMTheme.Typography.headline).foregroundStyle(FMTheme.Colors.textPrimary)
                        TextEditor(text: $journalText)
                            .frame(height: 100)
                            .padding(FMTheme.Spacing.xs)
                            .background(FMTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.md, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: FMTheme.Spacing.xs) {
                        Text("Daily photo").font(FMTheme.Typography.headline).foregroundStyle(FMTheme.Colors.textPrimary)
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            if let selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable().scaledToFill()
                                    .frame(height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: FMTheme.Radius.lg, style: .continuous)
                                    .fill(FMTheme.Colors.surface)
                                    .frame(height: 160)
                                    .overlay(Image(systemName: "camera.fill").foregroundStyle(FMTheme.Colors.textTertiary))
                            }
                        }
                        .onChange(of: pickerItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedImage = UIImage(data: data)
                                }
                            }
                        }
                    }

                    FMPrimaryButton(title: "Complete Day", icon: "checkmark.seal.fill") {
                        completeDay()
                    }
                }
                .padding(FMTheme.Spacing.lg)
            }
            .background(FMTheme.Colors.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
            .fullScreenCover(isPresented: $showRecap) {
                DailyRecapView(journey: journey, dailyScore: dailyScore, doneCount: doneCount, totalCount: habits.count) {
                    dismiss()
                }
            }
        }
    }

    private func completeDay() {
        let dayNumber = journey.dayNumber()
        let progress = journey.dayProgresses.first { Calendar.current.isDate($0.date, inSameDayAs: .now) }
            ?? DayProgress(date: .now, dayNumber: dayNumber)
        progress.journey = journey
        progress.dailyScore = dailyScore
        progress.journalEntry = journalText.isEmpty ? nil : journalText
        progress.isDayComplete = true
        if let selectedImage, let fileName = ImageStore.save(selectedImage) {
            progress.photo = DailyPhoto(fileName: fileName)
        }
        if !journey.dayProgresses.contains(where: { $0.id == progress.id }) {
            journey.dayProgresses.append(progress)
        }
        modelContext.insert(progress)
        try? modelContext.save()
        Haptics.notify(.success)
        showRecap = true
    }
}

#Preview {
    NightReviewView(journey: Journey())
        .modelContainer(PreviewData.container)
}
