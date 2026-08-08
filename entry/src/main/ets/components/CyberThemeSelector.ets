export class ThemeItem {
  name: string = '';
  image: Resource;
  locked: boolean = false;
  constructor(name: string, image: Resource, locked: boolean = false) {
    this.name = name;
    this.image = image;
    this.locked = locked;
  }
}

@CustomDialog
export struct ThemeSelectDialog {
  controller?: CustomDialogController;
  @Prop currentThemeIndex: number;
  onThemeSelected?: (index: number) => void;
  private readonly themes: ThemeItem[] = [
    new ThemeItem('默认', $r('app.media.bg_1')),
    new ThemeItem('晴空航迹', $r('app.media.skytrace')),
    new ThemeItem('云鲸航线', $r('app.media.skywhale')),
    new ThemeItem('戴竹蜻蜓蓝色胖子', $r('app.media.theme_doraemon')),
    new ThemeItem('空港幻想', $r('app.media.theme_skyreverie')),
    new ThemeItem('机修大队', $r('app.media.skymechacrev')),
    new ThemeItem('星港先锋', $r('app.media.starportvanguard'))
  ];

  @State tempSelectedIndex: number = this.currentThemeIndex;

  build() {
    Column() {
      // 0. 顶部拖拽 Indicator 胶囊
      Row()
        .width(40)
        .height(4)
        .backgroundColor('#E2E8F0')
        .borderRadius(2)
        .margin({ top: 12, bottom: 20 })

      // 1. 标题与关闭按钮
      Row() {
        Text('停机坪主题')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')

        Blank()

        Row() {
          Text('✕')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#64748B')
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('#F1F5F9')
        .borderRadius(16)
        .onClick(() => {
          if (this.controller) {
            this.controller.close();
          }
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })

      // 2. 横向滑动的卡片列表
      Scroll() {
        Row({ space: 16 }) {
          ForEach(this.themes, (theme: ThemeItem, index: number) => {
            Column() {
              Stack({ alignContent: Alignment.BottomEnd }) {
                Image(theme.image)
                  .width(110)
                  .height(150)
                  .borderRadius(14)
                  .objectFit(ImageFit.Cover)

                // 选中时的弹性对勾徽章
                Row() {
                  Text('✓')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
                .width(24)
                .height(24)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .backgroundColor('#F06553')
                .borderRadius(12)
                .margin(8)
                .border({ width: 2, color: '#FFFFFF' })
                .scale({
                  x: this.tempSelectedIndex === index ? 1.0 : 0.0,
                  y: this.tempSelectedIndex === index ? 1.0 : 0.0
                })
                .opacity(this.tempSelectedIndex === index ? 1.0 : 0.0)
                .animation({ duration: 250, curve: Curve.FastOutSlowIn })
              }
              .border(this.tempSelectedIndex === index ? 
                { width: 2.5, color: '#F06553', radius: 16 } : 
                { width: 1.5, color: '#EAE1D8', radius: 16 })
              .padding(2)
              .scale({
                x: this.tempSelectedIndex === index ? 1.06 : 0.96,
                y: this.tempSelectedIndex === index ? 1.06 : 0.96
              })
              .shadow(this.tempSelectedIndex === index ? 
                { radius: 16, color: 'rgba(240, 101, 83, 0.28)', offsetY: 6 } : 
                { radius: 6, color: 'rgba(0, 0, 0, 0.04)', offsetY: 2 })
              .animation({ duration: 280, curve: Curve.FastOutSlowIn })

              Text(theme.name)
                .fontSize(13)
                .fontWeight(this.tempSelectedIndex === index ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.tempSelectedIndex === index ? '#F06553' : '#334155')
                .margin({ top: 12 })
                .animation({ duration: 250, curve: Curve.FastOutSlowIn })
            }
            .onClick(() => {
              this.getUIContext()?.animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
                this.tempSelectedIndex = index;
              });
            })
          })
        }
        .padding({ left: 24, right: 24, top: 10, bottom: 10 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      // 3. 底部应用按钮
      Row() {
        Button('应用主题')
          .width('100%')
          .height(52)
          .backgroundColor('#F06553')
          .fontColor(Color.White)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .borderRadius(26)
          .onClick(() => {
            if (this.onThemeSelected) {
              this.onThemeSelected(this.tempSelectedIndex);
            }
            if (this.controller) {
              this.controller.close();
            }
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 32, bottom: 24 })
    }
    .width('100%')
    .backgroundColor('#fdf8f1')
    .borderRadius({ topLeft: 32, topRight: 32 })
  }
}

@Component
export struct CyberThemeSelector {
  @Link currentThemeIndex: number;
  private readonly themeNames: string[] = ['默认', '晴空航迹', '云鲸航线', '戴竹蜻蜓蓝色胖子', '空港幻想', '机修大队', '星港先锋'];

  dialogController: CustomDialogController = new CustomDialogController({
    builder: ThemeSelectDialog({ 
      currentThemeIndex: this.currentThemeIndex,
      onThemeSelected: (index: number) => {
        this.currentThemeIndex = index;
      }
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

  private getDisplayText(): string {
    if (this.currentThemeIndex === 0 || !this.themeNames[this.currentThemeIndex]) {
      return '更换主题';
    }
    return this.themeNames[this.currentThemeIndex];
  }

  build() {
    // 停机位地面标牌 ([ 机位 01 ] 动态主题名/更换主题)
    Row({ space: 6 }) {
      // 停机位地标编号 (航空安全警戒黄)
      Row() {
        Text('机位 01')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
      }
      .padding({ left: 5, right: 5, top: 2, bottom: 2 })
      .backgroundColor('#FBBF24')
      .borderRadius(3)

      // 地面标牌功能说明：默认主题显示“更换主题”，已选主题显示具体主题名称
      Text(this.getDisplayText())
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor('#475569')
    }
    .padding({ left: 6, right: 8, top: 4, bottom: 4 })
    .backgroundColor('rgba(255, 255, 255, 0.92)')
    .border({ width: 1, color: '#E2E8F0', radius: 6 })
    .borderRadius(6)
    .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.08)', offsetY: 2 })
    .onClick(() => {
      this.dialogController.open();
    })
  }
}
