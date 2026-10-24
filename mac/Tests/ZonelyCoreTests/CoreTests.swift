import XCTest
@testable import ZonelyCore

final class IniFileTests: XCTestCase {
    func testParsesSectionsKeysAndIgnoresComments() {
        let ini = IniFile(text: """
        ; comentario
        [General]
        Profile=dual   ; perfil al arrancar
        RestoreOnLeave=1

        [Exclusions]
        Processes=obs64.exe, vlc.exe
        Classes=
        """)
        XCTAssertEqual(ini.value("General", "Profile"), "dual")
        XCTAssertTrue(ini.bool("General", "RestoreOnLeave", default: false))
        XCTAssertEqual(ini.list("Exclusions", "Processes"), ["obs64.exe", "vlc.exe"])
        XCTAssertEqual(ini.list("Exclusions", "Classes"), [])
        XCTAssertEqual(ini.int("General", "Falta", default: 7), 7)
        XCTAssertEqual(ini.sectionOrder, ["General", "Exclusions"])
    }
}

final class ConfigTests: XCTestCase {
    private let sample = """
    [General]
    Profile=dual
    [Monitor]
    Width=5120
    Height=1440
    [Profile.ultrawide]
    A=0,0,3440,1440
    B=3440,0,1680,1440
    GameZone=B
    [Profile.dual]
    A=0,0,2560,1440
    B=2560,0,2560,1440
    [Profile.normal]
    A=0,0,5120,1440
    [Exclusions]
    Games=RainbowSix.exe, Siege.exe
    """

    func testLoadsProfilesInOrder() throws {
        let config = try Config(ini: IniFile(text: sample))
        XCTAssertEqual(config.profiles.map { $0.name }, ["ultrawide", "dual", "normal"])
        XCTAssertEqual(config.startProfile, "dual")
        XCTAssertEqual(config.profile(named: "ultrawide")?.zones["B"], Zone(name: "B", x: 3440, y: 0, w: 1680, h: 1440))
        XCTAssertEqual(config.profile(named: "ultrawide")?.gameZone, "B")
        XCTAssertEqual(config.profile(named: "dual")?.gameZone, "auto")
        XCTAssertTrue(config.profile(named: "dual")?.isZoned ?? false)
        XCTAssertFalse(config.profile(named: "normal")?.isZoned ?? true)
        XCTAssertEqual(config.gameProcesses, ["RainbowSix.exe", "Siege.exe"])
    }

    func testRejectsZoneOutsideMonitor() {
        let bad = sample.replacingOccurrences(of: "B=3440,0,1680,1440", with: "B=3440,0,2000,1440")
        XCTAssertThrowsError(try Config(ini: IniFile(text: bad)))
    }

    func testFallsBackToFirstProfileWhenStartProfileIsMissing() throws {
        let text = sample.replacingOccurrences(of: "Profile=dual", with: "Profile=inexistente")
        XCTAssertEqual(try Config(ini: IniFile(text: text)).startProfile, "ultrawide")
    }
}

final class DefaultIniTests: XCTestCase {
    func testUltrawideMonitorGetsTheAuthorsProfiles() {
        let text = DefaultIni.profilesText(width: 5120, height: 1440)
        XCTAssertTrue(text.contains("A=0,0,3440,1440\nB=3440,0,1680,1440"))
        XCTAssertTrue(text.contains("A=0,0,2560,1440\nB=2560,0,2560,1440"))
        XCTAssertTrue(text.contains("A=1280,0,2560,1440\nB=3840,0,1280,1440\nC=0,0,1280,1440"))
        XCTAssertTrue(text.contains("[Profile.normal]"))
    }

    func testSmallMonitorOnlyGetsDualAndNormal() {
        let text = DefaultIni.profilesText(width: 1920, height: 1080)
        XCTAssertTrue(text.contains("[Profile.dual]"))
        XCTAssertTrue(text.contains("[Profile.normal]"))
        XCTAssertFalse(text.contains("[Profile.ultrawide]"))
        XCTAssertFalse(text.contains("[Profile.centrado]"))
    }

    func testRenderedTemplateIsAValidConfig() throws {
        let template = "[General]\nProfile=normal\n[Monitor]\nWidth={{WIDTH}}\nHeight={{HEIGHT}}\n{{PROFILES}}"
        for (w, h) in [(1920, 1080), (2560, 1440), (3440, 1440), (5120, 1440), (3840, 1080), (1366, 768)] {
            let ini = DefaultIni.render(template: template, width: w, height: h)
            let config = try Config(ini: IniFile(text: ini))
            XCTAssertEqual(config.monitorWidth, w)
            XCTAssertNotNil(config.profile(named: "normal"), "\(w)x\(h)")
        }
    }
}

final class HotkeyTests: XCTestCase {
    func testValidation() {
        XCTAssertTrue(HotkeyTable.isValid("^!z"))
        XCTAssertTrue(HotkeyTable.isValid("^!+Left"))
        XCTAssertTrue(HotkeyTable.isValid("#F5"))
        XCTAssertTrue(HotkeyTable.isValid("^Numpad3"))
        XCTAssertFalse(HotkeyTable.isValid("z"))          // sin modificador
        XCTAssertFalse(HotkeyTable.isValid("^!"))         // sin tecla
        XCTAssertFalse(HotkeyTable.isValid("^!F99"))
    }

    func testResolveUsesDefaultsAndFlagsConflicts() {
        let rows = HotkeyTable.resolve(overrides: ["MoveToA": "^!z"])    // choca con ZoneMaximize
        let moveA = rows.first { $0.def.id == "MoveToA" }
        XCTAssertEqual(moveA?.key, moveA?.def.defaultKey)
        XCTAssertFalse(moveA?.error.isEmpty ?? true)
        XCTAssertEqual(rows.count, HotkeyTable.all.count)
    }
}

final class IpcTests: XCTestCase {
    func testParsesCommands() {
        let commands = Ipc.parse("profile dual\nwatcher off\ndim A+C\ndim lo-que-sea\ndimlevel 250\nreload\nbasura 1\n\n")
        XCTAssertEqual(commands, [.profile("dual"), .watcher(false), .dim("A+C"), .dim(""), .dimLevel(100), .reload])
    }

    func testStateJsonHasTheKeysThePanelReads() throws {
        let data = Ipc.stateData(version: "1.2.3", state: EngineState(profile: "dual", watcher: true, snap: false, dim: "B", dimLevel: 70, paused: false),
                                 now: Date(timeIntervalSince1970: 1_000))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["ts"] as? Int, 1_000)
        XCTAssertEqual(object["version"] as? String, "1.2.3")
        XCTAssertEqual(object["profile"] as? String, "dual")
        XCTAssertEqual(object["watcher"] as? Bool, true)
        XCTAssertEqual(object["snap"] as? Bool, false)
        XCTAssertEqual(object["dim"] as? String, "B")
        XCTAssertEqual(object["dimLevel"] as? Int, 70)
        XCTAssertEqual(object["paused"] as? Bool, false)
        XCTAssertTrue(object["target"] is NSNull)
    }

    func testHotkeysJson() throws {
        let rows = HotkeyTable.resolve(overrides: [:])
        let array = try XCTUnwrap(JSONSerialization.jsonObject(with: Ipc.hotkeysData(rows)) as? [[String: String]])
        XCTAssertEqual(array.count, rows.count)
        XCTAssertEqual(array.first?["id"], "ZoneMaximize")
        XCTAssertEqual(array.first?["default"], "^!z")
    }
}
