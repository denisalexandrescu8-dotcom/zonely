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

final class KeyCodesTests: XCTestCase {
    func testParsesCombos() {
        XCTAssertEqual(KeyCodes.parse("^!z"), HotkeyCombo(control: true, option: true, shift: false, command: false, keyCode: 6))
        XCTAssertEqual(KeyCodes.parse("^!+Left"), HotkeyCombo(control: true, option: true, shift: true, command: false, keyCode: 123))
        XCTAssertEqual(KeyCodes.parse("#F5")?.command, true)
        XCTAssertEqual(KeyCodes.parse("^BackSpace")?.keyCode, 51)
    }

    func testRejectsWhatDoesNotExistOnAMac() {
        XCTAssertNil(KeyCodes.parse("^F24"))     // válido en AutoHotkey, sin tecla en el Mac
        XCTAssertNil(KeyCodes.parse("z"))        // sin modificador
    }

    func testEveryDefaultHotkeyCanBeRegistered() {
        for def in HotkeyTable.all { XCTAssertNotNil(KeyCodes.parse(def.defaultKey), def.id) }
    }
}

final class GeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    func testUsableRectExcludesMenuBarAndDock() {
        // Barra de menús de 25 arriba y Dock de 70 abajo (en NSScreen el origen está abajo a la izquierda).
        let visible = CGRect(x: 0, y: 70, width: 1920, height: 1080 - 25 - 70)
        let usable = Geometry.usableRect(frame: screen, visibleFrame: visible)
        XCTAssertEqual(usable, CGRect(x: 0, y: 25, width: 1920, height: 985))
    }

    func testZoneIsScaledToTheRealScreen() {
        let zone = Zone(name: "A", x: 0, y: 0, w: 2560, h: 1440)               // mitad de un monitor de 5120×1440
        let r = Geometry.rect(of: zone, monitorWidth: 5120, monitorHeight: 1440, in: CGRect(x: 0, y: 25, width: 1920, height: 1000))
        XCTAssertEqual(r, CGRect(x: 0, y: 25, width: 960, height: 1000))
    }

    func testZoneContainingAndNeighbours() throws {
        let config = try Config(ini: IniFile(text: "[Monitor]\nWidth=5120\nHeight=1440\n[Profile.c]\nA=1280,0,2560,1440\nB=3840,0,1280,1440\nC=0,0,1280,1440\n"))
        let profile = try XCTUnwrap(config.profile(named: "c"))
        let usable = CGRect(x: 0, y: 0, width: 5120, height: 1440)
        XCTAssertEqual(Geometry.zonesByX(profile).map { $0.name }, ["C", "A", "B"])
        XCTAssertEqual(Geometry.zoneName(containing: CGRect(x: 100, y: 0, width: 200, height: 200), profile: profile, monitorWidth: 5120, monitorHeight: 1440, usable: usable), "C")
        XCTAssertEqual(Geometry.zoneName(containing: CGRect(x: 2000, y: 0, width: 200, height: 200), profile: profile, monitorWidth: 5120, monitorHeight: 1440, usable: usable), "A")
        XCTAssertEqual(Geometry.neighbour(of: "A", direction: 1, profile: profile), "B")
        XCTAssertEqual(Geometry.neighbour(of: "A", direction: -1, profile: profile), "C")
        XCTAssertEqual(Geometry.neighbour(of: "B", direction: 1, profile: profile), "B")      // no se sale por el extremo
    }

    func testHalvesAndCentering() {
        let r = CGRect(x: 100, y: 50, width: 400, height: 301)
        let (top, bottom) = Geometry.halves(of: r)
        XCTAssertEqual(top.height + bottom.height, r.height)
        XCTAssertEqual(bottom.minY, top.maxY)
        XCTAssertEqual(Geometry.centered(size: CGSize(width: 200, height: 100), in: r), CGRect(x: 200, y: 150 + 1, width: 200, height: 100))
        XCTAssertEqual(Geometry.centered(size: CGSize(width: 900, height: 900), in: r).origin, r.origin)   // más grande que la zona: pegada arriba a la izquierda
    }
}

final class Phase3Tests: XCTestCase {
    private func profile() throws -> Profile {
        let ini = "[Monitor]\nWidth=5120\nHeight=1440\n[Profile.u]\nA=0,0,3440,1440\nB=3440,0,1680,1440\n[Profile.c]\nA=1280,0,2560,1440\nB=3840,0,1280,1440\nC=0,0,1280,1440\n"
        return try XCTUnwrap(Config(ini: IniFile(text: ini)).profile(named: "u"))
    }

    func testNameMatchIgnoresCaseExeAndApp() {
        XCTAssertTrue(NameMatch.matches(candidates: ["Rainbow Six", "RainbowSix"], list: ["RainbowSix.exe"]))
        XCTAssertTrue(NameMatch.matches(candidates: ["OBS"], list: ["obs.app", "vlc.exe"]))
        XCTAssertFalse(NameMatch.matches(candidates: ["Safari"], list: ["obs64.exe"]))
        XCTAssertFalse(NameMatch.matches(candidates: ["Safari"], list: []))
    }

    func testAppKitConversion() {
        let r = Geometry.appKitRect(fromAX: CGRect(x: 10, y: 25, width: 100, height: 200), primaryHeight: 1080)
        XCTAssertEqual(r, CGRect(x: 10, y: 855, width: 100, height: 200))
    }

    func testMaximizedAndOutside() {
        let usable = CGRect(x: 0, y: 25, width: 1920, height: 1000)
        XCTAssertTrue(Geometry.isMaximized(CGRect(x: 0, y: 25, width: 1920, height: 1000), in: usable))
        XCTAssertFalse(Geometry.isMaximized(CGRect(x: 0, y: 25, width: 1280, height: 1000), in: usable))
        let zone = CGRect(x: 0, y: 25, width: 1280, height: 1000)
        XCTAssertFalse(Geometry.isOutside(CGRect(x: 5, y: 30, width: 1270, height: 990), of: zone))
        XCTAssertTrue(Geometry.isOutside(CGRect(x: 600, y: 30, width: 1000, height: 500), of: zone))
    }

    func testSnapTargetPicksZoneAndHalves() throws {
        let p = try profile()
        let usable = CGRect(x: 0, y: 0, width: 5120, height: 1440)
        let left = Geometry.snapTarget(at: CGPoint(x: 100, y: 700), profile: p, monitorWidth: 5120, monitorHeight: 1440, usable: usable, halves: true)
        XCTAssertEqual(left?.zone, "A")
        XCTAssertEqual(left?.rect, CGRect(x: 0, y: 0, width: 3440, height: 1440))
        let full = Geometry.snapTarget(at: CGPoint(x: 4000, y: 700), profile: p, monitorWidth: 5120, monitorHeight: 1440, usable: usable, halves: true)
        XCTAssertEqual(full?.rect, CGRect(x: 3440, y: 0, width: 1680, height: 1440))
        let top = Geometry.snapTarget(at: CGPoint(x: 4000, y: 100), profile: p, monitorWidth: 5120, monitorHeight: 1440, usable: usable, halves: true)
        XCTAssertEqual(top?.rect, CGRect(x: 3440, y: 0, width: 1680, height: 720))
        let bottom = Geometry.snapTarget(at: CGPoint(x: 4000, y: 1300), profile: p, monitorWidth: 5120, monitorHeight: 1440, usable: usable, halves: true)
        XCTAssertEqual(bottom?.rect, CGRect(x: 3440, y: 720, width: 1680, height: 720))
        let noHalves = Geometry.snapTarget(at: CGPoint(x: 4000, y: 100), profile: p, monitorWidth: 5120, monitorHeight: 1440, usable: usable, halves: false)
        XCTAssertEqual(noHalves?.rect, CGRect(x: 3440, y: 0, width: 1680, height: 1440))
    }

    func testOtherZones() throws {
        let p = try profile()
        XCTAssertEqual(Geometry.otherZones(than: "A", in: p), "B")
        XCTAssertEqual(Geometry.otherZones(than: "B", in: p), "A")
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
