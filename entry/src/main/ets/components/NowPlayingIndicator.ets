// Port of StationsViewController.nowPlayingIndicator: a 30x20 container holding the
// NVActivityIndicatorView audioEqualizer (playing) or ballPulse (buffering), both in
// Config.tintColor (white); a tap opens the Now Playing popup (nowPlayingBarButtonPressed
// -> didTapNowPlaying).
@Component
export struct NowPlayingIndicator {
  @Prop isPlaying: boolean = false;
  @Prop isBuffering: boolean = false;
  onTap?: () => void;
  @State private eqOn: boolean = false;

  build() {
    Stack() {
      if (this.isBuffering) {
        // ballPulse
        LoadingProgress()
          .width(30)
          .height(20)
          .color('#FFFFFF')
      } else if (this.isPlaying) {
        // audioEqualizer: NVActivityIndicatorView animates each bar's height on its own
        // period; reproduced as looping implicit animations started on appear.
        Row({ space: 3 }) {
          Column().width(4).height(this.eqOn ? 20 : 6).backgroundColor('#FFFFFF')
            .animation({ duration: 430, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
          Column().width(4).height(this.eqOn ? 6 : 18).backgroundColor('#FFFFFF')
            .animation({ duration: 250, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
          Column().width(4).height(this.eqOn ? 16 : 4).backgroundColor('#FFFFFF')
            .animation({ duration: 340, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
          Column().width(4).height(this.eqOn ? 8 : 20).backgroundColor('#FFFFFF')
            .animation({ duration: 310, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
        }
        .height(20)
        .alignItems(VerticalAlign.Bottom)
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
    }
    .width(30)
    .height(20)
    .id('stations_now_playing')
    .accessibilityText('Now playing indicator')
    .onClick((): void => {
      if (this.onTap !== undefined) {
        this.onTap();
      }
    })
  }
}
