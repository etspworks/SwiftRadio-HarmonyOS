// Port of SwiftRadio/Views/LogoShareView.swift + LogoShareView.xib: the share card that
// ShareActivity.generateImage renders to an image. Never shown on screen: the options sheet
// snapshots it (componentSnapshot.createFromBuilder) and hands the PixelMap to ShareService.
// xib tree: root 600x600 > Main Stack (vertical, spacing 20, inset 8)
//   [albumArtImageView (h 435), Track Info stack (fillEqually, spacing 20:
//    trackTitleLabel, trackArtistLabel, logoImageView), radioShoutoutLabel (right, h 21)]
// xib styling: labels system 17 in lightTextColor (white @ 0.6); root background gray
// white=0.333 (gamma 2.2) = #555555.
const SHARE_FONT_SIZE: number = 17;
const SHARE_TEXT_COLOR: string = '#99FFFFFF';
const SHARE_BACKGROUND: string = '#555555';

@Component
export struct LogoShareView {
  @Prop albumArt: ResourceStr = $r('app.media.stationImage');
  @Prop radioShoutout: string = '';
  @Prop trackTitle: string = '';
  @Prop trackArtist: string = '';

  build() {
    Column({ space: 20 }) {
      Image(this.albumArt)
        .width('100%')
        .height(435)
        .objectFit(ImageFit.Contain)
      Row({ space: 20 }) {
        Column() {
          Text(this.trackTitle)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
            .fontSize(SHARE_FONT_SIZE)
            .fontColor(SHARE_TEXT_COLOR)
          Text(this.trackArtist)
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
            .fontSize(SHARE_FONT_SIZE)
            .fontColor(SHARE_TEXT_COLOR)
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        // shareSetup: logoImageView.image = UIImage(named: "logo")
        Image($r('app.media.logo'))
          .width(88)
          .height('100%')
          .objectFit(ImageFit.Contain)
      }
      .width('100%')
      .height(88)
      Text(this.radioShoutout)
        .width('100%')
        .height(21)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.End)
        .fontSize(SHARE_FONT_SIZE)
        .fontColor(SHARE_TEXT_COLOR)
    }
    .width(600)
    .height(600)
    .padding(8)
    .backgroundColor(SHARE_BACKGROUND)
  }
}
