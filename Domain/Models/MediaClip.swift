//
//  MediaClip.swift
//  VideoEditor
//
//  Bir kaynak medya parçasının composition timeline üzerindeki yerleşimini
//  ve uygulanacak efektleri tanımlar.
//
//  İki zaman uzayı neden ayrıdır?
//  - timelineRange: Klibin composition üzeindeki pozisyonu ve görünürleşme süresi.
//  - sourceRange:   Kaynak asset'ten hangi bölümün kullanılacağı (trim aralığı).
//  Bu ayrım AVCompositionTrackSegment.timeMapping ile birebir örtüşür ve
//  speed ramping gibi gelişmiş özelliklere zemin hazırlar.

import Foundation

nonisolated struct MediaClip: Identifiable, Sendable {

    let id: UUID

    /// Klibin medya kaynağı ve tipi.
    let asset: AssetIdentifier

    /// Klibin composition timeline üzerindeki pozisyonu ve görünürleşme süresi.
    var timelineRange: ClipTimeRange

    /// Kaynak asset'ten hangi bölümün kullanılacağı (trim aralığı).
    /// image / text asset'ler için engine bu alanı görmezden gelir.
    var sourceRange: ClipTimeRange

    /// Canvas / composition üzerinde normalize yerleşim (tüm görsel klibi türleri için ortak).
    var transform: TransformEffect

    /// Bu clip'in bitişinde bir sonraki clip'e geçiş efekti.
    /// nil = hard cut (geçişsiz kesim).
    var transitionOut: ClipTransition?

    /// Sıralı efekt listesi. Uygulama sırası render sonucunu etkiler.
    /// Şimdilik boş; ilerleyen aşamalarda doldurulacak.
    var effects: [EffectConfiguration]

    /// Overlay track'lerde saydamlık düzeyi. 0.0 = tamamen şeffaf, 1.0 = opak.
    var opacity: Float

    // MARK: - Constants

    /// Fotoğraf (image) clip'ler için varsayılan timeline süresi.
    /// UI, yeni bir fotoğraf eklenirken bu değeri kullanır;
    /// kullanıcı daha sonra timeline'da süreyi değiştirebilir.
    static let defaultImageDuration: Double = 3.0

    // MARK: - Init (Video / Audio)

    /// Video veya ses clip'i oluşturmak için genel init.
    init(
        id: UUID = UUID(),
        asset: AssetIdentifier,
        timelineRange: ClipTimeRange,
        sourceRange: ClipTimeRange,
        transitionOut: ClipTransition? = nil,
        effects: [EffectConfiguration] = [],
        transform: TransformEffect = .identity,
        opacity: Float = 1.0
    ) {
        self.id = id
        self.asset = asset
        self.timelineRange = timelineRange
        self.sourceRange = sourceRange
        self.transitionOut = transitionOut
        self.effects = effects
        self.transform = transform
        self.opacity = opacity
    }

    // MARK: - Init (Image)

    /// Bir fotoğraf asset'inden clip oluşturmak için kolaylık init'i.
    /// sourceRange, still-frame olduğundan otomatik olarak sıfırlanmış seçilir.
    /// - Parameters:
    ///   - imageAsset: `.image`, `.phAssetImage` veya `.text` case'i kullanılmalıdır (yine de tek kare).
    ///   - timelineOffset: Timeline'daki başlangıç noktası (hangi saniyeden başlayacak).
    ///   - duration: Görüntülenme süresi; varsayılan `defaultImageDuration` (3 saniye).
    init(
        id: UUID = UUID(),
        imageAsset: AssetIdentifier,
        timelineOffset: Double,
        duration: Double = MediaClip.defaultImageDuration,
        transitionOut: ClipTransition? = nil,
        transform: TransformEffect = .identity,
        opacity: Float = 1.0
    ) {
        self.id = id
        self.asset = imageAsset
        self.timelineRange = ClipTimeRange(startSeconds: timelineOffset, durationSeconds: duration)
        // Still frame için source zaman aralığı anlamsızdır; sıfırdan başlatılır.
        self.sourceRange = ClipTimeRange(startSeconds: 0, durationSeconds: duration)
        self.transitionOut = transitionOut
        self.effects = []
        self.transform = transform
        self.opacity = opacity
    }
}

// MARK: - Codable

extension MediaClip: Codable {

    private enum CodingKeys: String, CodingKey {
        case id
        case asset
        case timelineRange
        case sourceRange
        case transform
        case transitionOut
        case effects
        case opacity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        asset = try c.decode(AssetIdentifier.self, forKey: .asset)
        timelineRange = try c.decode(ClipTimeRange.self, forKey: .timelineRange)
        sourceRange = try c.decode(ClipTimeRange.self, forKey: .sourceRange)
        transform = try c.decodeIfPresent(TransformEffect.self, forKey: .transform) ?? .identity
        transitionOut = try c.decodeIfPresent(ClipTransition.self, forKey: .transitionOut)
        effects = try c.decodeIfPresent([EffectConfiguration].self, forKey: .effects) ?? []
        opacity = try c.decodeIfPresent(Float.self, forKey: .opacity) ?? 1.0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(asset, forKey: .asset)
        try c.encode(timelineRange, forKey: .timelineRange)
        try c.encode(sourceRange, forKey: .sourceRange)
        try c.encode(transform, forKey: .transform)
        try c.encodeIfPresent(transitionOut, forKey: .transitionOut)
        try c.encode(effects, forKey: .effects)
        try c.encode(opacity, forKey: .opacity)
    }
}
