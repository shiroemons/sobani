import Testing
@testable import Sobani

@Suite("ZOrderUtils Tests")
struct ZOrderUtilsTests {

    private final class Element {
        let identifier: Int
        init(_ identifier: Int) { self.identifier = identifier }
    }

    private func ids(_ elements: [Element]) -> [Int] {
        elements.map { $0.identifier }
    }

    // MARK: - moveToFront Tests

    @Test("先頭への移動: 中間要素")
    func moveToFrontMiddle() {
        let elemA = Element(1), elemB = Element(2), elemC = Element(3)
        let result = ZOrderUtils.moveToFront(elemB, in: [elemA, elemB, elemC])
        #expect(ids(result) == [2, 1, 3])
    }

    @Test("先頭への移動: 末尾要素")
    func moveToFrontFromBack() {
        let elemA = Element(1), elemB = Element(2), elemC = Element(3)
        let result = ZOrderUtils.moveToFront(elemC, in: [elemA, elemB, elemC])
        #expect(ids(result) == [3, 1, 2])
    }

    @Test("先頭への移動: 既に先頭")
    func moveToFrontAlreadyFront() {
        let elemA = Element(1), elemB = Element(2), elemC = Element(3)
        let result = ZOrderUtils.moveToFront(elemA, in: [elemA, elemB, elemC])
        #expect(ids(result) == [1, 2, 3])
    }

    @Test("先頭への移動: 単一要素")
    func moveToFrontSingleElement() {
        let elemA = Element(1)
        let result = ZOrderUtils.moveToFront(elemA, in: [elemA])
        #expect(ids(result) == [1])
    }

    // MARK: - moveForward Tests

    @Test("前方への移動: 中間要素")
    func moveForwardMiddle() {
        let elemA = Element(1), elemB = Element(2), elemC = Element(3)
        let result = ZOrderUtils.moveForward(elemB, in: [elemA, elemB, elemC])
        #expect(ids(result) == [2, 1, 3])
    }

    @Test("前方への移動: 末尾要素")
    func moveForwardFromBack() {
        let elemA = Element(1), elemB = Element(2), elemC = Element(3)
        let result = ZOrderUtils.moveForward(elemC, in: [elemA, elemB, elemC])
        #expect(ids(result) == [1, 3, 2])
    }

    @Test("前方への移動: 既に先頭（変更なし）")
    func moveForwardAlreadyFront() {
        let elemA = Element(1), elemB = Element(2), elemC = Element(3)
        let result = ZOrderUtils.moveForward(elemA, in: [elemA, elemB, elemC])
        #expect(ids(result) == [1, 2, 3])
    }

    // MARK: - moveBackward Tests

    @Test("後方への移動: 中間要素")
    func moveBackwardMiddle() {
        let elemA = Element(1), elemB = Element(2), elemC = Element(3)
        let result = ZOrderUtils.moveBackward(elemB, in: [elemA, elemB, elemC])
        #expect(ids(result) == [1, 3, 2])
    }

    @Test("後方への移動: 先頭要素")
    func moveBackwardFromFront() {
        let elemA = Element(1), elemB = Element(2), elemC = Element(3)
        let result = ZOrderUtils.moveBackward(elemA, in: [elemA, elemB, elemC])
        #expect(ids(result) == [2, 1, 3])
    }

    @Test("後方への移動: 既に末尾（変更なし）")
    func moveBackwardAlreadyBack() {
        let elemA = Element(1), elemB = Element(2), elemC = Element(3)
        let result = ZOrderUtils.moveBackward(elemC, in: [elemA, elemB, elemC])
        #expect(ids(result) == [1, 2, 3])
    }

    // MARK: - moveToBack Tests

    @Test("末尾への移動: 先頭要素")
    func moveToBackFromFront() {
        let elemA = Element(1), elemB = Element(2), elemC = Element(3)
        let result = ZOrderUtils.moveToBack(elemA, in: [elemA, elemB, elemC])
        #expect(ids(result) == [2, 3, 1])
    }

    @Test("末尾への移動: 中間要素")
    func moveToBackMiddle() {
        let elemA = Element(1), elemB = Element(2), elemC = Element(3)
        let result = ZOrderUtils.moveToBack(elemB, in: [elemA, elemB, elemC])
        #expect(ids(result) == [1, 3, 2])
    }

    @Test("末尾への移動: 既に末尾")
    func moveToBackAlreadyBack() {
        let elemA = Element(1), elemB = Element(2), elemC = Element(3)
        let result = ZOrderUtils.moveToBack(elemC, in: [elemA, elemB, elemC])
        #expect(ids(result) == [1, 2, 3])
    }

    // MARK: - nextId Tests

    @Test("nextId: 空配列")
    func nextIdEmpty() {
        #expect(ZOrderUtils.nextId(from: []) == 1)
    }

    @Test("nextId: 連続ID")
    func nextIdSequential() {
        #expect(ZOrderUtils.nextId(from: [1, 2, 3]) == 4)
    }

    @Test("nextId: ギャップあり")
    func nextIdWithGaps() {
        #expect(ZOrderUtils.nextId(from: [1, 5, 3]) == 6)
    }

    @Test("nextId: 0を含む（レガシー）")
    func nextIdWithZero() {
        #expect(ZOrderUtils.nextId(from: [0]) == 1)
    }
}
