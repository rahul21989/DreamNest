//
//  DreamNestTests.swift
//  DreamNestTests
//
//  Created by Rahul Goyal on 30/03/26.
//

import Testing

@testable import DreamNest

struct DreamNestTests {
    @Test func sleepTimerFadeIsLastFadeOutSeconds() throws {
        let logic = SleepTimerLogic(totalSeconds: 60, fadeOutSeconds: 20)

        // No fade yet.
        #expect(logic.phase(atElapsed: 39.9) == .playing)
        #expect(logic.volumeMultiplier(atElapsed: 39.9) == 1)

        // Fade begins when remaining time reaches fadeOutSeconds (elapsed = 40).
        switch logic.phase(atElapsed: 40) {
        case .fading(let progress):
            #expect(progress == 0)
        default:
            #expect(false, "Expected fading phase at elapsed=40s")
        }

        // Halfway through fade (elapsed = 50 => remaining=10s => multiplier=0.5).
        let m = logic.volumeMultiplier(atElapsed: 50)
        #expect(abs(m - 0.5) < 0.000_1)

        // Finished at the end.
        #expect(logic.phase(atElapsed: 60) == .finished)
        #expect(logic.volumeMultiplier(atElapsed: 60) == 0)
    }

    @Test func routineSequencerAdvancesAtBoundaries() throws {
        let seq = RoutineSequencer(steps: [
            .init(trackID: "t1", durationSeconds: 10),
            .init(trackID: "t2", durationSeconds: 20)
        ])

        #expect(seq.state(atElapsed: 0) == .step(index: 0))
        #expect(seq.state(atElapsed: 9.999) == .step(index: 0))

        // Exactly at boundary should advance.
        #expect(seq.state(atElapsed: 10) == .step(index: 1))
        #expect(seq.state(atElapsed: 29.999) == .step(index: 1))

        // Exactly at total should finish.
        #expect(seq.state(atElapsed: 30) == .finished)
    }
}
