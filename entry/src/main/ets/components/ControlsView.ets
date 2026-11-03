import { AVCastPicker } from '@kit.AVSessionKit';
// Port of SwiftRadio/Views/ControlsView.swift: vertical stack [titleLabel, subtitleLabel,
// sliderContainer (slider + LIVE badge overlay, time labels), buttons (prev / play / next),
// menu (AirPlay route picker + more)].
// Config.tintColor = .white; secondary buttons tint @0.7; slider max track tint @0.3.
class ControlsStyle {
  static readonly TINT: string = '#FFFFFF';
  static readonly TINT_SECONDARY: string = '#B3FFFFFF';
  static readonly TRACK: string = '#4DFFFFFF';
  static readonly LIVE_TEXT: string = '#E6FFFFFF';
}

@Component
export struct ControlsView {
  @Prop song: string | undefined = undefined;
  @Prop artist: string | undefined = undefined;
  @Prop stationName: string = '';
  @Prop stationDesc: string = '';
  @Prop isLive: boolean = true;
  @Prop isPlaying: boolean = false;
  @Prop sliderValue: number = 0;
  @Prop currentTimeText: string = '00:00';
  @Prop totalTimeText: string = '00:00';
  hideNextPreviousButtons: boolean = false;
  playingAction: () => void = () => {
    console.warn('ControlsView: playingAction not set');
  };
  nextAction: () => void = () => {
    console.warn('ControlsView: nextAction not set');
  };
  previousAction: () => void = () => {
    console.warn('ControlsView: previousAction not set');
  };
  moreAction: () => void = () => {
    console.warn('ControlsView: moreAction not set');
  };
  // (value 0..1, mode) — mirrors timeAction(slider, event).
  timeAction: (value: number, mode: SliderChangeMode) => void = (value: number, mode: SliderChangeMode) => {
    console.warn(`ControlsView: timeAction not set (${value}, ${mode})`);
  };

  // updateNowPlaying: song ? "song — artist" / stationName : stationName / stationDesc
  private titleText(): string {
    if (this.song !== undefined) {
      return this.artist !== undefined ? `${this.song} — ${this.artist}` : this.song;
    }
    return this.stationName;
  }

  private subtitleText(): string {
    return this.song !== undefined ? this.stationName : this.stationDesc;
  }

  // ThinSlider.showThumb = !isLive.
  private thumbSize(): SizeOptions {
    if (this.isLive) {
      const hidden: SizeOptions = { width: 0, height: 0 };
      return hidden;
    }
    const shown: SizeOptions = { width: 12, height: 12 };
    return shown;
  }

  // AVRoutePickerView glyph: the system airplayaudio symbol; white@0.7 like tintColor.
  // System picker behaviour kept.
  @Builder
  airPlayGlyph() {
    SymbolGlyph($r('sys.symbol.airplayaudio'))
      .fontSize(26)
      .fontColor(['#FFFFFF'])
      .width(26)
      .height(26)
      .opacity(0.7)
  }

  build() {
    // mainStackView: vertical, spacing 8; custom 4 after title, 20 after subtitle.
    Column() {
      // titleLabel (MarqueeLabel): title2 bold, centred.
      Text(this.titleText())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(ControlsStyle.TINT)
        .textAlign(TextAlign.Center)
        .width('100%')
      // subtitleLabel: title3, alpha 0.7.
      Text(this.subtitleText())
        .fontSize(20)
        .fontColor(ControlsStyle.TINT)
        .opacity(0.7)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 4 })
      // sliderContainerView
      Stack() {
        Column({ space: 4 }) {
          // A 0x0 blockSize is ignored (default thumb drawn); SliderStyle.NONE draws no thumb.
          Slider({ value: this.sliderValue * 100, min: 0, max: 100,
            style: this.isLive ? SliderStyle.NONE : SliderStyle.OutSet })
            .id('now_playing_time_slider')
            .enabled(!this.isLive)
            .selectedColor(ControlsStyle.TINT)
            .trackColor(ControlsStyle.TRACK)
            .blockColor(ControlsStyle.TINT)
            .trackThickness(3)
            .blockSize(this.thumbSize())
            .width('100%')
            .margin(0)
            .onChange((value: number, mode: SliderChangeMode) => {
              this.timeAction(value / 100, mode);
            })
          if (!this.isLive) {
            // currentTimeLabel / totalTimeLabel: 10pt medium, alpha 0.8.
            Row() {
              Text(this.currentTimeText)
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(ControlsStyle.TINT)
                .opacity(0.8)
              Blank()
              Text(this.totalTimeText)
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(ControlsStyle.TINT)
                .opacity(0.8)
            }
            .width('100%')
          }
        }
        .width('100%')
        if (this.isLive) {
          // liveBadge: 11pt semibold white@0.9 in systemThinMaterialDark blur, radius 6, insets 4/12.
          Text($r('app.string.player_liveBadge'))
            .fontSize(11)
            .fontWeight(600)
            .fontColor(ControlsStyle.LIVE_TEXT)
            .padding({ top: 4, bottom: 4, left: 12, right: 12 })
            .borderRadius(6)
            .clip(true)
            .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.DARK })
            .hitTestBehavior(HitTestMode.Transparent)
        }
      }
      .width('100%')
      .margin({ top: 20 })
      // buttonsStackView: prev / play-pause / next, spacing 40, centred.
      Row({ space: 40 }) {
        if (!this.hideNextPreviousButtons) {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.backward_fill'))
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor([ControlsStyle.TINT_SECONDARY])
          }
          .id('now_playing_previous')
          .accessibilityText('Back')
          .width(44)
          .height(44)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.previousAction();
          })
        }
        // play.circle.fill / (selected) stop.circle.fill live, pause.circle.fill on-demand; 60pt.
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph(this.isPlaying ? (this.isLive ? $r('sys.symbol.stop_circle_fill')
            : $r('sys.symbol.pause_circle_fill')) : $r('sys.symbol.play_circle_fill'))
            .fontSize(64)
            .fontColor([ControlsStyle.TINT])
        }
        .id('now_playing_play_pause')
        // iOS labels an unlabelled SF-Symbol button with the symbol name (capture: 'stop.circle.fill').
        .accessibilityText(this.isPlaying ? (this.isLive ? 'stop.circle.fill' : 'pause.circle.fill') : 'play.circle.fill')
        .width(72)
        .height(72)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.playingAction();
        })
        if (!this.hideNextPreviousButtons) {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            // SF 'forward.fill' (double triangle) has no sys.symbol twin; mirror backward_fill.
            SymbolGlyph($r('sys.symbol.backward_fill'))
              .scale({ x: -1, y: 1 })
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor([ControlsStyle.TINT_SECONDARY])
          }
          .id('now_playing_next')
          .accessibilityText('Forward')
          .width(44)
          .height(44)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.nextAction();
          })
        }
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      // menuStackView: AVRoutePickerView -> AVCastPicker (self-contained, no app handler) + more,
      // spacing 40, 44x44 each.
      Row({ space: 40 }) {
        // AVRoutePickerView: tintColor white@0.7, activeTintColor white.
        AVCastPicker({
          normalColor: ControlsStyle.TINT_SECONDARY,
          activeColor: ControlsStyle.TINT,
          customPicker: (): void => this.airPlayGlyph()
        })
          .id('now_playing_airplay')
          .accessibilityText('AirPlay')
          .width(44)
          .height(44)
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.list_bullet'))
            .fontSize(22)
            .fontColor([ControlsStyle.TINT_SECONDARY])
        }
        .id('now_playing_more')
        .accessibilityText('list')
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.moreAction();
        })
      }
      .justifyContent(FlexAlign.Center)
      .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
  }
}

