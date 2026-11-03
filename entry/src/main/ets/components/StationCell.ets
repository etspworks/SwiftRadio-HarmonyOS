import { RadioStation } from '../model/RadioStation';
import { resolveStationImage, StationImageRef } from '../common/StationImage';

// $r() needs a literal name, so the bundled media names resolveStationImage() returns are
// mapped here (same list as common/StationImage.ts BUNDLED_MEDIA).
function bundledMedia(name: string): Resource {
  if (name === 'station_absolutecountry') {
    return $r('app.media.station_absolutecountry');
  } else if (name === 'az_rock_radio') {
    return $r('app.media.az_rock_radio');
  } else if (name === 'station_therockfm') {
    return $r('app.media.station_therockfm');
  } else if (name === 'station_radio1190') {
    return $r('app.media.station_radio1190');
  }
  return $r('app.media.stationImage');
}

// Source RadioStation.getImage: http URL -> network image, else the asset by name,
// fallback 'stationImage'. Shared with the mini-player artwork.
export function stationArtwork(station: RadioStation | undefined): ResourceStr {
  if (station === undefined) {
    return $r('app.media.stationImage');
  }
  // fields only: a @Prop copy of the station may not keep RadioStation's prototype
  const ref: StationImageRef = resolveStationImage(station.imageURL);
  if (ref.remoteUrl !== undefined) {
    return ref.remoteUrl;
  }
  return bundledMedia(ref.mediaName);
}

// Port of SwiftRadio/Cells/StationTableViewCell.swift: card (blur) > HStack(artwork
// container [shadow, pulse ring, image, buffering overlay+indicator], VStack(title,
// HStack(equalizer, subtitle))). setNowPlaying(isPlaying:isBuffering:isCurrentStation:)
// becomes the three props below.
@Component
export struct StationCell {
  @Prop station: RadioStation = new RadioStation();
  @Prop isPlaying: boolean = false;
  @Prop isBuffering: boolean = false;
  @Prop isCurrentStation: boolean = false;
  @State private pulseOn: boolean = false;
  @State private eqOn: boolean = false;

  build() {
    // cardView (shadow) / cardBlurView (ultra-thin dark material, r14, 0.5pt white@0.12 border)
    Column() {
      Row({ space: 14 }) {
        // artworkContainer 70x70
        Stack() {
          // pulseRingView: shown only for the current station when not buffering
          // startPulseAnimation: alpha 0 -> 0.4, scale 1 -> 1.06, 1.5s repeat+autoreverse
          // easeInOut while playing; stopped shows a static ring at alpha 0.25.
          if (this.isCurrentStation && !this.isBuffering && this.isPlaying) {
            Column()
              .width(78)
              .height(78)
              .borderRadius(12)
              .border({ width: 2.5, color: '#FFFFFF' })
              .shadow({ radius: 6, color: '#80FFFFFF', offsetX: 0, offsetY: 0 })
              .opacity(this.pulseOn ? 0.4 : 0)
              .scale({ x: this.pulseOn ? 1.06 : 1, y: this.pulseOn ? 1.06 : 1 })
              .animation({ duration: 1500, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
              .onAppear((): void => {
                // deferred: a state write inside the (dis)appear callback runs during render
                setTimeout((): void => {
                  this.pulseOn = true;
                }, 0);
              })
              .onDisAppear((): void => {
                // deferred: a state write inside the (dis)appear callback runs during render
                setTimeout((): void => {
                  this.pulseOn = false;
                }, 0);
              })
          } else if (this.isCurrentStation && !this.isBuffering) {
            Column()
              .width(78)
              .height(78)
              .borderRadius(12)
              .border({ width: 2.5, color: '#FFFFFF' })
              .shadow({ radius: 6, color: '#80FFFFFF', offsetX: 0, offsetY: 0 })
              .opacity(0.25)
          }
          Image(stationArtwork(this.station))
            .alt($r('app.media.stationImage'))
            .width(70)
            .height(70)
            .objectFit(ImageFit.Cover)
            .borderRadius(12)
            .clip(true)
            .shadow({ radius: 8, color: '#59000000', offsetX: 0, offsetY: 3 })
          // bufferingOverlay + bufferingIndicator (ballPulse)
          if (this.isCurrentStation && this.isBuffering) {
            Stack() {
              LoadingProgress()
                .width(30)
                .height(20)
                .color('#FFFFFF')
            }
            .width(70)
            .height(70)
            .borderRadius(12)
            .backgroundColor('#80000000')
          }
        }
        .width(70)
        .height(70)

        Column({ space: 4 }) {
          Text(this.station.name)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row({ space: 6 }) {
            // equalizerView 16x12 white at alpha 0.7: current station only
            if (this.isCurrentStation && !this.isBuffering && this.isPlaying) {
              // audioEqualizer: stopAnimating removes the bars; removing the node is what ends the
              // looping animations (changing their options on a kept node did not stop them)
              Row({ space: 2 }) {
                Column().width(3).height(this.eqOn ? 12 : 4).backgroundColor('#FFFFFF')
                  .animation({ duration: 430, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
                Column().width(3).height(this.eqOn ? 4 : 10).backgroundColor('#FFFFFF')
                  .animation({ duration: 250, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
                Column().width(3).height(this.eqOn ? 10 : 6).backgroundColor('#FFFFFF')
                  .animation({ duration: 340, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
              }
              .width(16)
              .height(12)
              .alignItems(VerticalAlign.Bottom)
              .opacity(0.7)
              .onAppear((): void => {
                // deferred: a state write inside the (dis)appear callback runs during render
                setTimeout((): void => {
                  this.eqOn = true;
                }, 0);
              })
              .onDisAppear((): void => {
                // deferred: a state write inside the (dis)appear callback runs during render
                setTimeout((): void => {
                  this.eqOn = false;
                }, 0);
              })
            }
            Text(this.station.desc)
              .fontSize(15)
              .fontColor('#8CFFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .alignItems(VerticalAlign.Center)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      // UIBlurEffect(.systemUltraThinMaterialDark)
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, { colorMode: ThemeColorMode.DARK })
      .borderRadius(14)
      .border({ width: 0.5, color: '#1FFFFFFF' })
      .shadow({ radius: 8, color: '#33000000', offsetX: 0, offsetY: 2 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 5, bottom: 5 })
  }
}
