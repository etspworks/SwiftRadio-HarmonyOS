import { curves } from '@kit.ArkUI';
// Port of SwiftRadio/Views/AlbumArtworkView.swift: outer view (shadow) > square container
// (corner 20, scale 1.0 playing / 0.85 paused) > [imageView, bufferingOverlay > ballPulse].
@Component
export struct AlbumArtworkView {
  @Prop image: ResourceStr = $r('app.media.stationImage');
  @Prop isPlaying: boolean = false;
  @Prop isBuffering: boolean = false;

  build() {
    // outer view: shadow black@0.4, offset (0,10), radius 20.
    Stack() {
      // containerView: square, cornerRadius 20, clipsToBounds.
      Stack() {
        Image(this.image)
          .alt($r('app.media.stationImage'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
        // bufferingOverlay: black@0.4, shown while player.state == .loading (NVActivityIndicator ballPulse).
        if (this.isBuffering) {
          Stack() {
            LoadingProgress()
              .width(40)
              .height(30)
              .color('#FFFFFF')
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .hitTestBehavior(HitTestMode.Transparent)
          // setBuffering: overlay alpha 0 <-> 1 over 0.3 s.
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
        }
      }
      .width('100%')
      .height('100%')
      .borderRadius(20)
      .clip(true)
    }
    // definite square: without a width the inner 100% resolved against the whole slot and the
    // artwork overflowed it (note: assumes the slot is taller than wide, as on phones)
    .width('100%')
    .aspectRatio(1)
    .shadow({ radius: 20, color: '#66000000', offsetX: 0, offsetY: 10 })
    .scale({ x: this.isPlaying ? 1.0 : 0.85, y: this.isPlaying ? 1.0 : 0.85 })
    // setPlaying: UIView.animate(0.5 s, usingSpringWithDamping 0.7).
    .animation({ curve: curves.springMotion(0.5, 0.7) })
  }
}
