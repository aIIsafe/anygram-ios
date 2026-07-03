import Foundation

/// Pagination helper for lazy-loaded lists.
enum PaginationHelper {
    static func pageRange(page: Int, pageSize: Int, totalCount: Int) -> Range<Int>? {
        let end = totalCount - page * pageSize
        let start = max(0, end - pageSize)
        guard start < end else { return nil }
        return start..<end
    }
}
