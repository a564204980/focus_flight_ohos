import { Airport, POPULAR_AIRPORTS } from '../models/AirportModel';

/**
 * AirportSelectDialog.ets
 * 现代高奢 Bottom Sheet 机场选择抽屉面板 (Airport Select Bottom Sheet)
 * 采用 100% 底部吸附抽屉结构 + 纯正暗黑遮罩，彻底杜绝元素错位重叠
 */

@CustomDialog
export struct AirportSelectDialog {
  controller?: CustomDialogController;
  title: string = '选择出发机场';
  currentCode: string = 'CTU';
  onSelectAirport?: (airport: Airport) => void;

  @State searchText: string = '';
  @State selectedCategory: string = '全部';

  private categories: string[] = ['全部', '国内枢纽', '国际/港澳台'];

  private getFilteredAirports(): Airport[] {
    return POPULAR_AIRPORTS.filter(airport => {
      // 1. 搜索文本过滤
      if (this.searchText.trim().length > 0) {
        const query = this.searchText.trim().toLowerCase();
        const matchCode = airport.code.toLowerCase().includes(query);
        const matchName = airport.name.toLowerCase().includes(query);
        const matchCity = airport.city.toLowerCase().includes(query);
        if (!matchCode && !matchName && !matchCity) {
          return false;
        }
      }

      // 2. 分类页签过滤
      if (this.selectedCategory === '国内枢纽') {
        return ['PEK', 'PKX', 'PVG', 'SHA', 'CAN', 'SZX', 'TFU', 'CTU', 'HGH', 'WUH', 'XIY', 'CKG', 'NKG', 'XMN', 'TSN', 'CGO', 'TAO', 'CSX', 'KMG'].includes(airport.code);
      } else if (this.selectedCategory === '国际/港澳台') {
        return ['HKG', 'MFM', 'TPE', 'HND', 'NRT', 'ICN', 'SIN', 'LHR', 'CDG', 'JFK', 'LAX'].includes(airport.code);
      }
      return true;
    });
  }

  build() {
    Column({ space: 14 }) {
      // 0. 顶部拖拽 Indicator 胶囊
      Row()
        .width(38)
        .height(4)
        .backgroundColor('rgba(255, 255, 255, 0.22)')
        .borderRadius(2)
        .margin({ top: 4, bottom: 2 })

      // 1. 标题与关闭按钮
      Row() {
        Text(this.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F8FAFC')

        Blank()

        Row() {
          Text('✕')
            .fontSize(14)
            .fontColor('#94A3B8')
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('rgba(255, 255, 255, 0.08)')
        .borderRadius(14)
        .onClick(() => {
          if (this.controller) {
            this.controller.close();
          }
        })
      }
      .width('100%')

      // 2. 搜索输入框
      Row({ space: 8 }) {
        Text('🔍')
          .fontSize(13)
        TextInput({ placeholder: '搜索城市、机场或三字码 (如 成都/CTU)', text: this.searchText })
          .placeholderColor('#64748B')
          .fontColor('#F8FAFC')
          .fontSize(13)
          .backgroundColor('transparent')
          .height(38)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.searchText = value;
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12 })
      .backgroundColor('rgba(15, 23, 42, 0.75)')
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', radius: 12 })
      .borderRadius(12)

      // 3. 快捷分类 Capsule Tab
      Row({ space: 8 }) {
        ForEach(this.categories, (cat: string) => {
          Text(cat)
            .fontSize(12)
            .fontWeight(this.selectedCategory === cat ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.selectedCategory === cat ? '#38BDF8' : '#94A3B8')
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .backgroundColor(this.selectedCategory === cat ? 'rgba(56, 189, 248, 0.15)' : 'rgba(255, 255, 255, 0.04)')
            .border({
              width: 1,
              color: this.selectedCategory === cat ? 'rgba(56, 189, 248, 0.4)' : 'rgba(255, 255, 255, 0.08)',
              radius: 14
            })
            .borderRadius(14)
            .onClick(() => {
              this.selectedCategory = cat;
            })
        })
      }
      .width('100%')

      // 4. 机场可滚动列表
      List({ space: 8 }) {
        ForEach(this.getFilteredAirports(), (item: Airport) => {
          ListItem() {
            Row() {
              Column({ space: 4 }) {
                Row({ space: 8 }) {
                  Text(item.code)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.currentCode === item.code ? '#38BDF8' : '#F8FAFC')
                  Text(item.city)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#F8FAFC')
                }
                Text(item.name)
                  .fontSize(11)
                  .fontColor('#64748B')
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              if (this.currentCode === item.code) {
                Text('✓ 已选')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#38BDF8')
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor(this.currentCode === item.code ? 'rgba(56, 189, 248, 0.12)' : 'rgba(30, 41, 59, 0.45)')
            .border({
              width: 1,
              color: this.currentCode === item.code ? 'rgba(56, 189, 248, 0.4)' : 'rgba(255, 255, 255, 0.06)',
              radius: 14
            })
            .borderRadius(14)
            .onClick(() => {
              if (this.onSelectAirport) {
                this.onSelectAirport(item);
              }
              if (this.controller) {
                this.controller.close();
              }
            })
          }
        })
      }
      .width('100%')
      .height(300)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 28 })
    .backgroundColor('rgba(10, 15, 26, 0.98)')
    .border({ width: { top: 1 }, color: 'rgba(56, 189, 248, 0.3)' })
    .borderRadius({ topLeft: 24, topRight: 24, bottomLeft: 0, bottomRight: 0 })
    .shadow({ radius: 36, color: 'rgba(0, 0, 0, 0.9)', offsetY: -8 })
  }
}

