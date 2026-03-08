import Foundation

/// Z-order 配列操作のユーティリティ
enum ZOrderUtils {
    /// 要素を配列の先頭（最前面）に移動
    static func moveToFront<T: AnyObject>(_ element: T, in array: [T]) -> [T] {
        var result = array.filter { $0 !== element }
        result.insert(element, at: 0)
        return result
    }

    /// 要素を配列内で1つ前方（先頭方向）に移動
    static func moveForward<T: AnyObject>(_ element: T, in array: [T]) -> [T] {
        guard let currentIndex = array.firstIndex(where: { $0 === element }),
              currentIndex > 0 else { return array }
        var result = array
        result.swapAt(currentIndex, currentIndex - 1)
        return result
    }

    /// 要素を配列内で1つ後方（末尾方向）に移動
    static func moveBackward<T: AnyObject>(_ element: T, in array: [T]) -> [T] {
        guard let currentIndex = array.firstIndex(where: { $0 === element }),
              currentIndex < array.count - 1 else { return array }
        var result = array
        result.swapAt(currentIndex, currentIndex + 1)
        return result
    }

    /// 要素を配列の末尾（最背面）に移動
    static func moveToBack<T: AnyObject>(_ element: T, in array: [T]) -> [T] {
        var result = array.filter { $0 !== element }
        result.append(element)
        return result
    }

    /// 既存IDの配列から次のウィンドウIDを計算
    static func nextId(from existingIds: [Int]) -> Int {
        return (existingIds.max() ?? 0) + 1
    }
}
