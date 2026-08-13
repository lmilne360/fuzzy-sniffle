import SwiftData
import XCTest
@testable import Bane

/// Tests for the timestamp-derived session clock, pause/resume, the "still
/// working out?" staleness check, and the rest-timer completion/pause paths
/// (ba-84b).
@MainActor
final class WorkoutTimerTests: XCTestCase {

    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        container = Persistence.inMemoryContainer()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func makeWorkout(startedAt: Date) -> Workout {
        let workout = Workout(startedAt: startedAt)
        container.mainContext.insert(workout)
        return workout
    }

    // MARK: - Session clock: elapsed derivation

    /// Elapsed is derived fresh from timestamps, matching the wall-clock gap
    /// exactly — never an accumulated counter that could drift.
    func testElapsedDerivedFromTimestamps() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let workout = makeWorkout(startedAt: start)

        let elapsed = workout.elapsed(at: start.addingTimeInterval(600))

        XCTAssertEqual(elapsed, 600, accuracy: 0.001)
    }

    /// Backgrounding for a while and returning reads the correct elapsed time
    /// on the very next call — no catch-up animation needed since nothing
    /// was ever accumulated (test case 1 from the design spec).
    func testElapsedCorrectAfterLongGapWithoutAnyIntermediateTicks() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let workout = makeWorkout(startedAt: start)

        // No ticks in between — simulates the app being backgrounded, then
        // asked for elapsed time exactly once on return.
        let elapsed = workout.elapsed(at: start.addingTimeInterval(10 * 60))

        XCTAssertEqual(elapsed, 10 * 60, accuracy: 0.001)
    }

    // MARK: - Session clock: pause / resume

    /// Pausing freezes elapsed at the paused instant, however far `now` moves on.
    func testPauseFreezesElapsed() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let workout = makeWorkout(startedAt: start)

        workout.pause(at: start.addingTimeInterval(120))

        XCTAssertEqual(workout.elapsed(at: start.addingTimeInterval(120)), 120, accuracy: 0.001)
        XCTAssertEqual(workout.elapsed(at: start.addingTimeInterval(420)), 120, accuracy: 0.001)
        XCTAssertTrue(workout.isPaused)
    }

    /// Pausing, waiting, then resuming advances elapsed by exactly zero across
    /// the paused window (test case 3 from the design spec).
    func testResumeAfterPauseAdvancesElapsedByZero() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let workout = makeWorkout(startedAt: start)

        let pauseAt = start.addingTimeInterval(120)
        workout.pause(at: pauseAt)
        let elapsedWhilePaused = workout.elapsed(at: pauseAt)

        // Backgrounded for 5 minutes while paused, then resumed.
        let resumeAt = pauseAt.addingTimeInterval(5 * 60)
        workout.resume(at: resumeAt)

        XCTAssertFalse(workout.isPaused)
        XCTAssertEqual(workout.elapsed(at: resumeAt), elapsedWhilePaused, accuracy: 0.001)
    }

    /// A second `pause(at:)` while already paused is a no-op — it must not
    /// move the frozen instant forward.
    func testPauseIsIdempotent() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let workout = makeWorkout(startedAt: start)

        workout.pause(at: start.addingTimeInterval(60))
        workout.pause(at: start.addingTimeInterval(600))

        XCTAssertEqual(workout.elapsed(at: start.addingTimeInterval(600)), 60, accuracy: 0.001)
    }

    /// `resume(at:)` without a preceding pause is a no-op.
    func testResumeWithoutPauseIsNoOp() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let workout = makeWorkout(startedAt: start)

        workout.resume(at: start.addingTimeInterval(60))

        XCTAssertFalse(workout.isPaused)
        XCTAssertEqual(workout.elapsed(at: start.addingTimeInterval(60)), 60, accuracy: 0.001)
    }

    // MARK: - Staleness check

    func testStaleAfterSixHoursWithoutPause() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let workout = makeWorkout(startedAt: start)

        XCTAssertFalse(StaleWorkoutCheck.isStale(workout, at: start.addingTimeInterval(5 * 3600)))
        XCTAssertTrue(StaleWorkoutCheck.isStale(workout, at: start.addingTimeInterval(6 * 3600 + 1)))
    }

    /// A session that has ever been paused is never flagged as stale, even
    /// well past the threshold — pausing already shows the user is tracking it.
    func testEverHavingPausedExcludesFromStaleCheck() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let workout = makeWorkout(startedAt: start)
        workout.pause(at: start.addingTimeInterval(60))
        workout.resume(at: start.addingTimeInterval(120))

        XCTAssertFalse(StaleWorkoutCheck.isStale(workout, at: start.addingTimeInterval(7 * 3600)))
    }

    // MARK: - Rest timer: extend, floor, and the unified completion path

    func testExtendBeyondZeroExtendsRemaining() {
        let controller = RestTimerController()
        controller.start(seconds: 45, exerciseName: "Squat")

        controller.extend(by: 30)

        XCTAssertEqual(controller.remaining(at: Date()), 75, accuracy: 1)
        XCTAssertTrue(controller.isRunning)
    }

    /// Repeated -15s taps floor at zero rather than going negative, and the
    /// completion routine fires exactly once — not once per tap past zero
    /// (test case 4 from the design spec).
    func testRepeatedNegativeExtendFloorsAtZeroAndCompletesOnce() {
        let controller = RestTimerController()
        controller.start(seconds: 45, exerciseName: "Bench Press")

        var completions = 0
        controller.onComplete = { completions += 1 }

        controller.extend(by: -15)
        controller.extend(by: -15)
        controller.extend(by: -15)
        controller.extend(by: -15)

        XCTAssertEqual(controller.remaining(at: Date()), 0)
        XCTAssertEqual(completions, 1)
        // Still "running" — sitting at zero, awaiting dismissal — not hidden.
        XCTAssertTrue(controller.isRunning)
    }

    /// `extend` crossing zero runs the completion routine immediately, rather
    /// than leaving the display at zero until the next `tick()`.
    func testExtendCrossingZeroSignalsImmediatelyWithoutWaitingForTick() {
        let controller = RestTimerController()
        controller.start(seconds: 10, exerciseName: nil)

        var completed = false
        controller.onComplete = { completed = true }

        controller.extend(by: -30)

        XCTAssertTrue(completed)
    }

    /// `tick()` after an already-signalled completion doesn't fire it again.
    func testTickAfterCompletionDoesNotDoubleSignal() {
        let controller = RestTimerController()
        controller.start(seconds: 5, exerciseName: nil)

        var completions = 0
        controller.onComplete = { completions += 1 }

        controller.tick(Date(timeIntervalSinceNow: 10))
        controller.tick(Date(timeIntervalSinceNow: 11))

        XCTAssertEqual(completions, 1)
    }

    /// Skip runs the completion routine (haptic/notification/focus-advance)
    /// and then fully dismisses the countdown, unlike a natural expiry which
    /// leaves it visible awaiting dismissal.
    func testSkipCompletesThenStops() {
        let controller = RestTimerController()
        controller.start(seconds: 60, exerciseName: "Deadlift")

        var completed = false
        controller.onComplete = { completed = true }

        controller.skip()

        XCTAssertTrue(completed)
        XCTAssertFalse(controller.isRunning)
    }

    // MARK: - Rest timer: pause / resume

    /// Pausing hides the countdown (nothing is counting) and resuming restores
    /// it with exactly the remaining time it had.
    func testRestPauseAndResumePreservesRemaining() {
        let controller = RestTimerController()
        controller.start(seconds: 90, exerciseName: "Row")

        let pauseAt = Date(timeIntervalSinceNow: 30)
        controller.pause(at: pauseAt)

        XCTAssertFalse(controller.isRunning)

        let resumeAt = pauseAt.addingTimeInterval(5 * 60)
        controller.resume(at: resumeAt)

        XCTAssertTrue(controller.isRunning)
        XCTAssertEqual(controller.remaining(at: resumeAt), 60, accuracy: 1)
    }

    /// Resuming a rest that had already hit zero before the pause is a no-op.
    func testResumeAfterRestAlreadyCompletedDoesNotRevive() {
        let controller = RestTimerController()
        controller.start(seconds: 5, exerciseName: nil)

        let pauseAt = Date(timeIntervalSinceNow: 10)
        controller.pause(at: pauseAt)
        controller.resume(at: pauseAt.addingTimeInterval(60))

        XCTAssertFalse(controller.isRunning)
    }
}
