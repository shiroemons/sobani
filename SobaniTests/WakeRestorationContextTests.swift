import Foundation
import Testing
@preconcurrency @testable import Sobani

/// WakeRestorationContextの初期化・クリア・変更操作を検証するテスト
@Suite struct WakeRestorationContextTests {

    /// 初期化時にすべてのプロパティが空/デフォルト値であることを検証
    @Test func initialization_AllPropertiesEmpty() {
        let context = WakeRestorationContext()
        #expect(context.states.isEmpty)
        #expect(context.displayIDs.isEmpty)
        #expect(context.screenFrames.isEmpty)
        #expect(context.windowOrigins.isEmpty)
        #expect(!context.isActive)
        #expect(context.retryCount == 0)
    }

    /// clear()で全プロパティが初期状態にリセットされることを検証
    @Test func clear_ResetsAllProperties() {
        var context = WakeRestorationContext()
        context.isActive = true
        context.retryCount = 5
        context.displayIDs[1] = 42
        context.windowOrigins[1] = NSPoint(x: 100, y: 200)

        context.clear()

        #expect(context.states.isEmpty)
        #expect(context.displayIDs.isEmpty)
        #expect(context.screenFrames.isEmpty)
        #expect(context.windowOrigins.isEmpty)
        #expect(!context.isActive)
        #expect(context.retryCount == 0)
    }

    /// statesディクショナリの変更が正しく動作することを検証
    @Test func statesMutation_WorksCorrectly() {
        var context = WakeRestorationContext()
        let state = WindowState(
            imageName: "test.png",
            originX: 100, originY: 200,
            width: 300, height: 400,
            isFlippedHorizontally: false,
            rotationAngle: 0,
            opacityLevel: 1.0,
            windowId: 1
        )
        context.states[1] = state
        #expect(context.states.count == 1)
        #expect(context.states[1]?.imageName == "test.png")
    }

    /// displayIDsディクショナリの変更が正しく動作することを検証
    @Test func displayIDsMutation_WorksCorrectly() {
        var context = WakeRestorationContext()
        context.displayIDs[1] = 100
        context.displayIDs[2] = 200
        #expect(context.displayIDs.count == 2)
        #expect(context.displayIDs[1] == 100)
        #expect(context.displayIDs[2] == 200)
    }

    /// screenFramesディクショナリの変更が正しく動作することを検証
    @Test func screenFramesMutation_WorksCorrectly() {
        var context = WakeRestorationContext()
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        context.screenFrames[1] = frame
        #expect(context.screenFrames.count == 1)
        #expect(context.screenFrames[1] == frame)
    }

    /// isActiveとretryCountの変更が正しく動作することを検証
    @Test func activeStateAndRetryCount_WorkCorrectly() {
        var context = WakeRestorationContext()
        context.isActive = true
        context.retryCount = 3
        #expect(context.isActive)
        #expect(context.retryCount == 3)
    }
}
