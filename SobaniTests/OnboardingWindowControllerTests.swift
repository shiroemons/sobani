import Foundation
import Testing
@testable import Sobani

/// OnboardingWindowController の静的ヘルパーメソッドを検証するテスト
@Suite @MainActor struct OnboardingWindowControllerTests {

    // MARK: - navigationButtonConfig Tests

    /// 最初のステップではback非表示、skip・next表示を検証
    @Test func navigationButtonConfig_firstStep() {
        let config = OnboardingWindowController.navigationButtonConfig(currentStep: 0, totalSteps: 4)
        #expect(config.showBack == false)
        #expect(config.showSkip == true)
        #expect(config.showNext == true)
        #expect(config.showStart == false)
        #expect(config.showClose == false)
    }

    /// 中間ステップではback・skip・next表示を検証
    @Test func navigationButtonConfig_middleStep() {
        let config = OnboardingWindowController.navigationButtonConfig(currentStep: 1, totalSteps: 4)
        #expect(config.showBack == true)
        #expect(config.showSkip == true)
        #expect(config.showNext == true)
        #expect(config.showStart == false)
        #expect(config.showClose == false)
    }

    /// 最終ステップではstart・close表示、skip・next非表示を検証
    @Test func navigationButtonConfig_lastStep() {
        let config = OnboardingWindowController.navigationButtonConfig(currentStep: 3, totalSteps: 4)
        #expect(config.showBack == true)
        #expect(config.showSkip == false)
        #expect(config.showNext == false)
        #expect(config.showStart == true)
        #expect(config.showClose == true)
    }

    /// totalSteps=1の場合、最初かつ最終ステップとして扱われることを検証
    @Test func navigationButtonConfig_singleStep() {
        let config = OnboardingWindowController.navigationButtonConfig(currentStep: 0, totalSteps: 1)
        #expect(config.showBack == false)
        #expect(config.showSkip == false)
        #expect(config.showNext == false)
        #expect(config.showStart == true)
        #expect(config.showClose == true)
    }

    // MARK: - pageIndicatorDotFrames Tests

    /// 4ステップで正しい数のフレームが返ることを検証
    @Test func pageIndicatorDotFrames_fourSteps_returnsCorrectCount() {
        let frames = OnboardingWindowController.pageIndicatorDotFrames(
            totalSteps: 4, containerWidth: 400, dotSize: 8, dotSpacing: 12
        )
        #expect(frames.count == 4)
    }

    /// 各フレームのサイズがdotSizeに一致することを検証
    @Test func pageIndicatorDotFrames_dotSizeMatchesFrameSize() {
        let dotSize: CGFloat = 8
        let frames = OnboardingWindowController.pageIndicatorDotFrames(
            totalSteps: 4, containerWidth: 400, dotSize: dotSize, dotSpacing: 12
        )
        for frame in frames {
            #expect(frame.width == dotSize)
            #expect(frame.height == dotSize)
        }
    }

    /// フレームが中央揃えになっていることを検証
    @Test func pageIndicatorDotFrames_centeredInContainer() throws {
        let containerWidth: CGFloat = 400
        let dotSize: CGFloat = 8
        let dotSpacing: CGFloat = 12
        let totalSteps = 4
        let frames = OnboardingWindowController.pageIndicatorDotFrames(
            totalSteps: totalSteps, containerWidth: containerWidth, dotSize: dotSize, dotSpacing: dotSpacing
        )
        let firstFrame = try #require(frames.first)
        let lastFrame = try #require(frames.last)
        let totalWidth = CGFloat(totalSteps) * dotSize + CGFloat(totalSteps - 1) * dotSpacing
        let expectedStartX = (containerWidth - totalWidth) / 2
        #expect(abs(firstFrame.origin.x - expectedStartX) < AppConstants.floatingPointTolerance)
        let expectedEndX = expectedStartX + totalWidth
        #expect(abs((lastFrame.origin.x + lastFrame.width) - expectedEndX) < AppConstants.floatingPointTolerance)
    }

    /// 1ステップの場合、1つのフレームが中央に配置されることを検証
    @Test func pageIndicatorDotFrames_singleStep() throws {
        let containerWidth: CGFloat = 400
        let dotSize: CGFloat = 8
        let frames = OnboardingWindowController.pageIndicatorDotFrames(
            totalSteps: 1, containerWidth: containerWidth, dotSize: dotSize, dotSpacing: 12
        )
        #expect(frames.count == 1)
        let frame = try #require(frames.first)
        let expectedX = (containerWidth - dotSize) / 2
        #expect(abs(frame.origin.x - expectedX) < AppConstants.floatingPointTolerance)
    }
}
