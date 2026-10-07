import Foundation

/// Bundled, original textile compositions. Raw values are stable preference keys.
enum RugStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case ningxia
    case songBrocade
    case inkLandscape
    case seaCliff
    case cinnabar
    case hiddenPanda

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ningxia: "宁夏毯 · 祥云"
        case .songBrocade: "宋锦 · 青织"
        case .inkLandscape: "水墨山河"
        case .seaCliff: "海水江崖"
        case .cinnabar: "中国红 · 朱砂"
        case .hiddenPanda: "隐山 · 熊猫"
        }
    }

    var detail: String {
        switch self {
        case .ningxia: "米白羊毛，靛青祥云与回纹"
        case .songBrocade: "深青菱格，暗金缠枝与莲瓣"
        case .inkLandscape: "灰白山脊，留白水线与薄雾"
        case .seaCliff: "深蓝海浪，岩石与淡色云纹"
        case .cinnabar: "低饱和朱砂，米白团花与枝蔓"
        case .hiddenPanda: "黑白云纹间，藏着几只小熊猫"
        }
    }
}
