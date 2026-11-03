// Port of SwiftRadio/Cells/NothingFoundCell.xib: one label (tag 100), not selectable.
// 88pt cell, label inset 32/11, headline style, textColor sRGB 0.849 gray.
@Component
export struct NothingFoundCell {
  @Prop text: ResourceStr = '';

  build() {
    Column() {
      Text(this.text)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#D9D9D9')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(88)
    .padding({ left: 32, right: 32, top: 11, bottom: 11 })
    .justifyContent(FlexAlign.Center)
  }
}
