import { Contributor } from '../model/GitHub';
import { resolveText } from '../model/Config';

// comp_contributor_cell: port of ContributorCell (ContributorsViewController.swift:12).
// Avatar (placeholder person.crop.circle under the network image), "#rank login", "N commits".
// Style: 72pt round avatar 8pt from the top, bold 14 username, 12pt secondaryLabel commits,
// on secondarySystemBackground (elevated dark #2C2C2E), corner radius 8, item height 140.
@Component
export struct ContributorCell {
  @Prop rank: number = 0;
  @Prop contributor: Contributor = new Contributor();

  // String(format: Content.Common.commitsFormat, contributor.contributions)
  private commitsText(): string {
    return resolveText(getContext(this), 'common_commitsFormat')
      .replace('%d', this.contributor.contributions.toString());
  }

  build() {
    Column() {
      Stack() {
        // avatarImageView.image = UIImage(systemName: "person.crop.circle") until load(url:) lands
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(72)
          .fontColor(['#99EBEBF5'])
        Image(this.contributor.avatarURL)
          .width(72)
          .height(72)
          .objectFit(ImageFit.Cover)
          .borderRadius(36)
          .clip(true)
      }
      .width(72)
      .height(72)
      .margin({ top: 8 })

      // rankUsernameLabel
      Text(`#${this.rank} ${this.contributor.login}`)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .width('100%')
        .padding({ left: 4, right: 4 })
        .margin({ top: 8 })
      // commitsLabel
      Text(this.commitsText())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .fontSize(12)
        .fontColor('#99EBEBF5')
        .width('100%')
        .padding({ left: 4, right: 4 })
        .margin({ top: 4 })
    }
    .width('100%')
    .height(140)
    .backgroundColor('#2C2C2E')
    .borderRadius(8)
    .clip(true)
  }
}
