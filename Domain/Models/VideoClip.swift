//
//  VideoClip.swift
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

struct VideoClip: Identifiable, Codable {

    let id: UUID

    /// Klibin medya kaynağı ve tipi.
    let asset: AssetIdentifier

    /// Klibin composition timeline üzerindeki pozisyonu ve görünürleşme süresi.
    var timelineRange: ClipTimeRange

    /// Kaynak asset'ten hangi bölümün kullanılacağı (trim aralığı).
    /// image asset'ler için engine bu alanı görmezden gelir.
    var sourceRange: ClipTimeRange

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
        opacity: Float = 1.0
    ) {
        self.id = id
        self.asset = asset
        self.timelineRange = timelineRange
        self.sourceRange = sourceRange
        self.transitionOut = transitionOut
        self.effects = effects
        self.opacity = opacity
    }

    // MARK: - Init (Image)

    /// Bir fotoğraf asset'inden clip oluşturmak için kolaylık init'i.
    /// sourceRange, still-frame olduğundan otomatik olarak sıfırlanmış seçilir.
    /// - Parameters:
    ///   - imageAsset: `.image(URL)` veya `.phAssetImage(String)` case'i kullanılmalıdır.
    ///   - timelineOffset: Timeline'daki başlangıç noktası (saniye).
    ///   - duration: Görüntülenme süresi; varsayılan `defaultImageDuration` (3 saniye).
    init(
        id: UUID = UUID(),
        imageAsset: AssetIdentifier,
        timelineOffset: Double,
        duration: Double = VideoClip.defaultImageDuration,
        transitionOut: ClipTransition? = nil,
        opacity: Float = 1.0
    ) {
        self.id = id
        self.asset = imageAsset
        self.timelineRange = ClipTimeRange(startSeconds: timelineOffset, durationSeconds: duration)
        // Still frame için source zaman aralığı anlamsızdır; sıfırdan başlatılır.
        self.sourceRange = ClipTimeRange(startSeconds: 0, durationSeconds: duration)
        self.transitionOut = transitionOut
        self.effects = []
        self.opacity = opacity
    }
}
