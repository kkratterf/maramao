import XCTest
@testable import MaramaoCore

final class CatCompanionTests: XCTestCase {
    func testDefaults() {
        let cat = CatCompanion()
        XCTAssertEqual(cat.name, "Maramao")
        XCTAssertEqual(cat.affection, CatCompanion.startingAffection)
        XCTAssertEqual(cat.mood, .calm)
        XCTAssertEqual(cat.treats, 0)
        XCTAssertFalse(cat.canGiveTreat)
        XCTAssertNil(cat.favouriteMode)
    }

    func testMoodThresholds() {
        XCTAssertEqual(CatMood.from(affection: 0), .grumpy)
        XCTAssertEqual(CatMood.from(affection: 19), .grumpy)
        XCTAssertEqual(CatMood.from(affection: 20), .sulky)
        XCTAssertEqual(CatMood.from(affection: 39), .sulky)
        XCTAssertEqual(CatMood.from(affection: 40), .calm)
        XCTAssertEqual(CatMood.from(affection: 60), .happy)
        XCTAssertEqual(CatMood.from(affection: 80), .delighted)
        XCTAssertEqual(CatMood.from(affection: 100), .delighted)
        XCTAssertTrue(CatMood.delighted.isHappy)
        XCTAssertTrue(CatMood.grumpy.isGrumpy)
        XCTAssertFalse(CatMood.calm.isHappy || CatMood.calm.isGrumpy)
    }

    func testRespectedBreakEarnsTreatAffectionAndStreak() {
        var cat = CatCompanion()
        XCTAssertTrue(cat.recordBreak(respected: true, mode: "walkingCat"))
        XCTAssertEqual(cat.treats, 1)
        XCTAssertEqual(cat.affection, 50 + CatCompanion.respectedBreakBonus)
        XCTAssertEqual(cat.streak, 1)
        XCTAssertEqual(cat.bestStreak, 1)
        XCTAssertEqual(cat.favouriteMode, "walkingCat")
    }

    func testSkippedBreakCostsAffectionAndStreakButNotTreats() {
        var cat = CatCompanion()
        cat.recordBreak(respected: true, mode: "catPile")
        cat.recordBreak(respected: true, mode: "catPile")
        XCTAssertFalse(cat.recordBreak(respected: false, mode: "catPile"))
        XCTAssertEqual(cat.treats, 2)
        XCTAssertEqual(cat.streak, 0)
        XCTAssertEqual(cat.bestStreak, 2)
        XCTAssertEqual(cat.affection, 50 + 2 * CatCompanion.respectedBreakBonus - CatCompanion.skippedBreakPenalty)
        XCTAssertEqual(cat.modeCounts["catPile"], 2, "Only respected breaks count towards the favourite mode")
    }

    func testStreakMakesTheCatHappierAndSkipsGrumpier() {
        var happy = CatCompanion()
        for _ in 0..<8 { happy.recordBreak(respected: true, mode: nil) }
        XCTAssertEqual(happy.mood, .delighted)

        var grumpy = CatCompanion()
        for _ in 0..<6 { grumpy.recordBreak(respected: false, mode: nil) }
        XCTAssertEqual(grumpy.mood, .grumpy)
        XCTAssertEqual(grumpy.affection, 14)
    }

    func testAffectionIsClamped() {
        var cat = CatCompanion(affection: 500)
        XCTAssertEqual(cat.affection, 100)
        cat.recordBreak(respected: true, mode: nil)
        XCTAssertEqual(cat.affection, 100)
        var low = CatCompanion(affection: -3)
        XCTAssertEqual(low.affection, 0)
        low.recordBreak(respected: false, mode: nil)
        XCTAssertEqual(low.affection, 0)
    }

    func testTreatsAreCapped() {
        var cat = CatCompanion()
        for _ in 0..<CatCompanion.maxTreats {
            XCTAssertTrue(cat.recordBreak(respected: true, mode: nil))
        }
        XCTAssertFalse(cat.recordBreak(respected: true, mode: nil))
        XCTAssertEqual(cat.treats, CatCompanion.maxTreats)
        XCTAssertEqual(cat.streak, CatCompanion.maxTreats + 1, "A full bowl still counts the break")
    }

    func testGivingTreats() {
        var cat = CatCompanion(affection: 30)
        XCTAssertFalse(cat.giveTreat())
        XCTAssertEqual(cat.affection, 30)
        cat.recordBreak(respected: true, mode: nil)
        XCTAssertTrue(cat.giveTreat())
        XCTAssertEqual(cat.treats, 0)
        XCTAssertEqual(cat.treatsGiven, 1)
        XCTAssertEqual(cat.affection, 30 + CatCompanion.respectedBreakBonus + CatCompanion.treatBonus)
        XCTAssertFalse(cat.giveTreat())
    }

    func testOnlyTheFirstPetsOfABreakCount() {
        var cat = CatCompanion()
        for index in 0..<CatCompanion.petsCountedPerBreak {
            XCTAssertTrue(cat.pet(alreadyThisBreak: index))
        }
        XCTAssertFalse(cat.pet(alreadyThisBreak: CatCompanion.petsCountedPerBreak))
        XCTAssertEqual(cat.pets, CatCompanion.petsCountedPerBreak)
        XCTAssertEqual(cat.affection, 50 + CatCompanion.petsCountedPerBreak * CatCompanion.petBonus)
    }

    func testFavouriteModeTieBreaksAlphabetically() {
        var cat = CatCompanion()
        cat.recordBreak(respected: true, mode: "walkingCat")
        cat.recordBreak(respected: true, mode: "catPile")
        XCTAssertEqual(cat.favouriteMode, "catPile")
        cat.recordBreak(respected: true, mode: "walkingCat")
        XCTAssertEqual(cat.favouriteMode, "walkingCat")
    }

    func testRenameSanitizes() {
        var cat = CatCompanion()
        cat.rename("  Fuffi \n  Gatto ")
        XCTAssertEqual(cat.name, "Fuffi Gatto")
        cat.rename("   ")
        XCTAssertEqual(cat.name, CatCompanion.defaultName)
        cat.rename(String(repeating: "a", count: 60))
        XCTAssertEqual(cat.name.count, CatCompanion.maxNameLength)
    }

    func testRoundTripsThroughJSON() throws {
        var cat = CatCompanion(name: "Pippo", affection: 70)
        cat.recordBreak(respected: true, mode: "laserChase")
        cat.pet(alreadyThisBreak: 0)
        cat.giveTreat()
        let data = try JSONEncoder().encode(cat)
        let decoded = try JSONDecoder().decode(CatCompanion.self, from: data)
        XCTAssertEqual(decoded, cat)
    }

    func testDecodingIsTolerant() throws {
        let empty = try JSONDecoder().decode(CatCompanion.self, from: Data("{}".utf8))
        XCTAssertEqual(empty, CatCompanion())

        let odd = Data(#"{"name":"  ","affection":250,"treats":99,"streak":4,"bestStreak":1,"modeCounts":{"a":0,"b":2}}"#.utf8)
        let decoded = try JSONDecoder().decode(CatCompanion.self, from: odd)
        XCTAssertEqual(decoded.name, CatCompanion.defaultName)
        XCTAssertEqual(decoded.affection, 100)
        XCTAssertEqual(decoded.treats, CatCompanion.maxTreats)
        XCTAssertEqual(decoded.bestStreak, 4)
        XCTAssertEqual(decoded.modeCounts, ["b": 2])
    }

    func testTextIsGentleAndComplete() {
        for mood in CatMood.allCases {
            XCTAssertFalse(mood.label.isEmpty)
            XCTAssertFalse(mood.emoji.isEmpty)
            XCTAssertFalse(CatCompanionText.greetings(mood: mood, name: "Fuffi").isEmpty)
            XCTAssertFalse(CatCompanionText.petReactions(mood: mood).isEmpty)
            XCTAssertFalse(CatCompanionText.treatReaction(mood: mood).isEmpty)
            for line in CatCompanionText.greetings(mood: mood, name: "Fuffi") + CatCompanionText.petReactions(mood: mood) {
                XCTAssertLessThanOrEqual(line.count, 48, "Lines must fit in a bubble: \(line)")
            }
        }
        XCTAssertEqual(CatCompanionText.treatsLine(0), "Nessun croccantino")
        XCTAssertEqual(CatCompanionText.treatsLine(1), "1 croccantino")
        XCTAssertEqual(CatCompanionText.treatsLine(3), "3 croccantini")
        XCTAssertEqual(CatCompanionText.moodLine(CatCompanion(affection: 90)), "Al settimo cielo 😻")
    }
}
