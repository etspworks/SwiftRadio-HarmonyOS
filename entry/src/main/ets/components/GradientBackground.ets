// Port of SwiftRadio/Views/GradientBackgroundView.swift, installed full-bleed by
// BaseController.setupViews: black base + CAGradientLayer from bottom-left (0,1) to
// top-right (1,0) of Config.gradientColor (white) at alpha 0.3 / 0.15 / 0.05 / clear.
@Component
export struct GradientBackground {
  build() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('#000000')
      .linearGradient({
        direction: GradientDirection.RightTop,
        colors: [['#4DFFFFFF', 0.0], ['#26FFFFFF', 0.3], ['#0DFFFFFF', 0.6], ['#00FFFFFF', 1.0]]
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
