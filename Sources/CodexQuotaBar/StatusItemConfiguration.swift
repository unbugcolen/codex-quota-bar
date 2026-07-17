import Foundation

enum StatusItemConfiguration {
    static let autosaveName = "CodexQuotaBar.menuBarItem.v3"

    static func visibleLength(
        baseLength: CGFloat,
        itemFrame: CGRect,
        leftSafeArea: CGRect?,
        rightSafeArea: CGRect?
    ) -> CGFloat {
        guard let leftSafeArea, let rightSafeArea,
              itemFrame.minX >= leftSafeArea.maxX,
              itemFrame.minX < rightSafeArea.minX else {
            return baseLength
        }
        return baseLength + rightSafeArea.minX - itemFrame.minX
    }
}
