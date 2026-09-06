import Foundation

extension ReelInput {
    /// Flattens a live journey into reel material.
    ///
    /// Everything here is already on the device — daily photos, completions, quit runs.
    /// The reel is the first feature that reads it back out as a story.
    init(journey: Journey, user: User?, calendar: Calendar = .current, now: Date = .now) {
        let currentDay = journey.dayNumber(for: now, calendar: calendar)

        let photos = journey.dayProgresses
            .compactMap { progress -> ReelInput.Photo? in
                guard let photo = progress.photo else { return nil }
                return ReelInput.Photo(fileName: photo.fileName, dayNumber: progress.dayNumber)
            }
            .sorted { $0.dayNumber < $1.dayNumber }

        // "Shown up" means any habit was kept that day — not that the user also sat down
        // and finished an evening review. Counting only completed reviews would undersell
        // most people's actual run.
        let activeDays = Set(
            journey.habits
                .flatMap(\.completions)
                .filter { $0.state.isDone }
                .map { calendar.startOfDay(for: $0.date) }
        )

        let buildHabits = journey.habits.filter { !$0.isQuit }
        let quitHabit = journey.habits.first(where: \.isQuit)

        self.init(
            name: user?.name ?? "",
            currentDay: currentDay,
            totalDays: journey.lengthInDays,
            photos: photos,
            daysShownUp: activeDays.count,
            longestStreak: buildHabits.map { $0.currentStreak(calendar: calendar, today: now) }.max() ?? 0,
            habitsKept: buildHabits.count,
            quit: quitHabit.flatMap { Self.quit(from: $0, calendar: calendar, now: now) },
            referralCode: user?.referralCode ?? ""
        )
    }

    private static func quit(from habit: Habit, calendar: Calendar, now: Date) -> ReelInput.Quit? {
        guard let start = habit.quitStartDate else { return nil }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return ReelInput.Quit(
            title: habit.quitProgram?.title ?? habit.name,
            cleanDays: max(days, 0),
            moneySaved: habit.moneySaved(now: now),
            cravingsResisted: habit.cravings.filter(\.didResist).count
        )
    }
}
