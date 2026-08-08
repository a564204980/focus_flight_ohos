import { Airport, POPULAR_AIRPORTS } from '../models/AirportModel';

/**
 * DestinationSelectDialog.ets
 * 飞行目的地选择弹窗 (支持国内热门枢纽与国际航线挑选)
 */
@CustomDialog
export struct DestinationSelectDialog {
  controller?: CustomDialogController;
  @Prop selectedCode: string = '';
  onDestinationSelected?: (airport: Airport) => void;

  private readonly domesticAirports: Airport[] = POPULAR_AIRPORTS.filter(a => 
    ['PEK', 'PVG', 'SHA', 'CAN', 'SZX', 'HGH', 'XIY', 'CKG', 'WUH', 'NKG', 'CSX', 'TAO', 'XMN', 'HKG', 'KMG', 'TFU'].includes(a.code)
  );

  private readonly internationalAirports: Airport[] = POPULAR_AIRPORTS.filter(a => 
    ['HND', 'NRT', 'ICN', 'SIN', 'LHR', 'CDG', 'JFK', 'LAX', 'TPE', 'MFM'].includes(a.code)
  );

  build() {
    Column() {
      // 0. 顶部 Indicator 胶囊
      Row()
        .width(40)
        .height(4)
        .backgroundColor('#E2E8F0')
        .borderRadius(2)
        .margin({ top: 12, bottom: 16 })

      // 1. 标题与关闭按钮
      Row() {
        Column({ space: 2 }) {
          Text('选择飞行目的地')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1E293B')
          Text('探索全球航线 · 开启您的专注之旅')
            .fontSize(12)
            .fontColor('#64748B')
        }
        .alignItems(HorizontalAlign.Start)

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
      .margin({ bottom: 16 })

      // 2. 热门城市选择列表
      Scroll() {
        Column({ space: 18 }) {
          // 国内枢纽
          Column({ space: 10 }) {
            Text('🇨🇳 国内热门')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#475569')
              .width('100%')

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.domesticAirports, (item: Airport) => {
                Row({ space: 4 }) {
                  Text(item.city)
                    .fontSize(13)
                    .fontWeight(this.selectedCode === item.code ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(this.selectedCode === item.code ? '#FFFFFF' : '#334155')

                  Text(`(${item.code})`)
                    .fontSize(10)
                    .fontColor(this.selectedCode === item.code ? 'rgba(255,255,255,0.85)' : '#94A3B8')
                }
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(this.selectedCode === item.code ? '#FA6B56' : '#F8FAFC')
                .border({ width: 1, color: this.selectedCode === item.code ? '#FA6B56' : '#E2E8F0', radius: 18 })
                .borderRadius(18)
                .shadow({ radius: this.selectedCode === item.code ? 6 : 0, color: 'rgba(250, 107, 86, 0.3)', offsetY: 2 })
                .onClick(() => {
                  if (this.onDestinationSelected) {
                    this.onDestinationSelected(item);
                  }
                  if (this.controller) {
                    this.controller.close();
                  }
                })
              })
            }
          }

          // 国际航线
          Column({ space: 10 }) {
            Text('🌏 国际漫游')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#475569')
              .width('100%')

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.internationalAirports, (item: Airport) => {
                Row({ space: 4 }) {
                  Text(item.city)
                    .fontSize(13)
                    .fontWeight(this.selectedCode === item.code ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(this.selectedCode === item.code ? '#FFFFFF' : '#334155')

                  Text(`(${item.code})`)
                    .fontSize(10)
                    .fontColor(this.selectedCode === item.code ? 'rgba(255,255,255,0.85)' : '#94A3B8')
                }
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(this.selectedCode === item.code ? '#FA6B56' : '#F8FAFC')
                .border({ width: 1, color: this.selectedCode === item.code ? '#FA6B56' : '#E2E8F0', radius: 18 })
                .borderRadius(18)
                .shadow({ radius: this.selectedCode === item.code ? 6 : 0, color: 'rgba(250, 107, 86, 0.3)', offsetY: 2 })
                .onClick(() => {
                  if (this.onDestinationSelected) {
                    this.onDestinationSelected(item);
                  }
                  if (this.controller) {
                    this.controller.close();
                  }
                })
              })
            }
          }
        }
        .width('100%')
      }
      .height(310)
      .scrollBar(BarState.Off)
    }
    .padding({ left: 20, right: 20, top: 0, bottom: 20 })
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 24, topRight: 24 })
  }
}
