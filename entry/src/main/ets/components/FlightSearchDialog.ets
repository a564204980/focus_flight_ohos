import { FlightInfo, FlightService } from '../services/FlightService';
import { CLASSIC_ROUTES_DATABASE, ClassicRoute } from '../models/RouteModel';
import { POPULAR_AIRPORTS, Airport } from '../models/AirportModel';

/**
 * FlightSearchDialog.ets
 * 真实航班、全球经典航线与自定义专属航班大一统 Bottom Sheet 抽屉
 * 完美融合 方案 A (实时航班搜索) + 方案 B (内置经典航线) + 方案 C (自定义专属航班)
 */

@CustomDialog
export struct FlightSearchDialog {
  controller?: CustomDialogController;
  onSelectFlight?: (flight: FlightInfo) => void;

  @State searchText: string = '';
  @State activeTab: string = '实时航班'; // '实时航班' | '经典航线' | '自定义'

  // 方案 A & B 数据
  @State flightsList: FlightInfo[] = [];
  @State routesList: ClassicRoute[] = CLASSIC_ROUTES_DATABASE;
  @State isLoading: boolean = false;

  // 方案 C 自定义专属航班状态
  @State customFlightNo: string = 'FOCUS888';
  @State customAirline: string = '专注极客航空 Focus Airlines';
  @State customOriginIdx: number = 7; // 默认 成都 CTU
  @State customDestIdx: number = 27;  // 默认 巴黎 CDG
  @State customAircraft: string = '空客 A350-900 (专注旗舰号)';

  private aircraftOptions: string[] = [
    '空客 A350-900 (专注旗舰号)',
    '波音 787-9 梦想客机',
    '协和超音速战机 (Concorde)',
    '空客 A380-800 双层客机',
    '星际专注探索号'
  ];

  aboutToAppear(): void {
    this.flightsList = FlightService.getPopularFlights();
  }

  private async handleSearch(value: string): Promise<void> {
    this.searchText = value;
    this.isLoading = true;
    try {
      this.flightsList = await FlightService.searchFlight(value);
      if (value.trim().length > 0) {
        const query = value.trim().toLowerCase();
        this.routesList = CLASSIC_ROUTES_DATABASE.filter(r =>
          r.routeName.toLowerCase().includes(query) ||
          r.originAirport.city.toLowerCase().includes(query) ||
          r.destAirport.city.toLowerCase().includes(query) ||
          r.recommendedFlightNo.toLowerCase().includes(query)
        );
      } else {
        this.routesList = CLASSIC_ROUTES_DATABASE;
      }
    } catch (err) {
      // 容错处理
    } finally {
      this.isLoading = false;
    }
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
        Text('航班与航线终端 (Flight Terminal)')
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

      // 2. 方案 A / B / C 大一统分类 Tab
      Row({ space: 8 }) {
        Text('✈️ 实时航班(A)')
          .fontSize(12)
          .fontWeight(this.activeTab === '实时航班' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.activeTab === '实时航班' ? '#38BDF8' : '#94A3B8')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.activeTab === '实时航班' ? 'rgba(56, 189, 248, 0.15)' : 'rgba(255, 255, 255, 0.04)')
          .border({
            width: 1,
            color: this.activeTab === '实时航班' ? 'rgba(56, 189, 248, 0.4)' : 'rgba(255, 255, 255, 0.08)',
            radius: 12
          })
          .borderRadius(12)
          .onClick(() => {
            this.activeTab = '实时航班';
          })

        Text('🌟 经典航线(B)')
          .fontSize(12)
          .fontWeight(this.activeTab === '经典航线' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.activeTab === '经典航线' ? '#38BDF8' : '#94A3B8')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.activeTab === '经典航线' ? 'rgba(56, 189, 248, 0.15)' : 'rgba(255, 255, 255, 0.04)')
          .border({
            width: 1,
            color: this.activeTab === '经典航线' ? 'rgba(56, 189, 248, 0.4)' : 'rgba(255, 255, 255, 0.08)',
            radius: 12
          })
          .borderRadius(12)
          .onClick(() => {
            this.activeTab = '经典航线';
          })

        Text('✏️ 自定义专属(C)')
          .fontSize(12)
          .fontWeight(this.activeTab === '自定义' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.activeTab === '自定义' ? '#4ADE80' : '#94A3B8')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.activeTab === '自定义' ? 'rgba(74, 222, 128, 0.15)' : 'rgba(255, 255, 255, 0.04)')
          .border({
            width: 1,
            color: this.activeTab === '自定义' ? 'rgba(74, 222, 128, 0.4)' : 'rgba(255, 255, 255, 0.08)',
            radius: 12
          })
          .borderRadius(12)
          .onClick(() => {
            this.activeTab = '自定义';
          })
      }
      .width('100%')

      // 3. 根据 Tab 展示不同功能区
      if (this.activeTab === '实时航班' || this.activeTab === '经典航线') {
        // A / B 搜索框
        Row({ space: 8 }) {
          Text('🔍')
            .fontSize(13)
          TextInput({ placeholder: this.activeTab === '实时航班' ? '搜索航班号 (如 CA933, MU5137)' : '搜索经典航线 (如 京沪, 成巴)', text: this.searchText })
            .placeholderColor('#64748B')
            .fontColor('#F8FAFC')
            .fontSize(13)
            .backgroundColor('transparent')
            .height(38)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.handleSearch(value);
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .backgroundColor('rgba(15, 23, 42, 0.75)')
        .border({ width: 1, color: 'rgba(56, 189, 248, 0.3)', radius: 12 })
        .borderRadius(12)

        if (this.activeTab === '实时航班') {
          // 方案 A 实时航班列表
          List({ space: 10 }) {
            ForEach(this.flightsList, (item: FlightInfo) => {
              ListItem() {
                Column({ space: 8 }) {
                  Row() {
                    Text(item.flightNo)
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#38BDF8')

                    Text(` · ${item.airlineName}`)
                      .fontSize(12)
                      .fontColor('#94A3B8')

                    Blank()

                    Row({ space: 4 }) {
                      Circle({ width: 6, height: 6 }).fill('#4ADE80')
                      Text(item.status)
                        .fontSize(11)
                        .fontColor('#4ADE80')
                    }
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor('rgba(74, 222, 128, 0.12)')
                    .borderRadius(10)
                  }
                  .width('100%')

                  Divider().color('rgba(255, 255, 255, 0.06)')

                  Row() {
                    Column({ space: 2 }) {
                      Text(item.originAirport.code)
                        .fontSize(15)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#F8FAFC')
                      Text(item.originAirport.city)
                        .fontSize(11)
                        .fontColor('#94A3B8')
                    }
                    .alignItems(HorizontalAlign.Start)

                    Text('────────➔')
                      .fontSize(10)
                      .fontColor('rgba(56, 189, 248, 0.4)')
                      .margin({ left: 10, right: 10 })

                    Column({ space: 2 }) {
                      Text(item.destAirport.code)
                        .fontSize(15)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#F8FAFC')
                      Text(item.destAirport.city)
                        .fontSize(11)
                        .fontColor('#94A3B8')
                    }
                    .alignItems(HorizontalAlign.Start)

                    Blank()

                    Column({ space: 2 }) {
                      Text(item.aircraftType)
                        .fontSize(11)
                        .fontColor('#64748B')
                      Text(item.flightDuration)
                        .fontSize(11)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#38BDF8')
                    }
                    .alignItems(HorizontalAlign.End)
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(14)
                .backgroundColor('rgba(30, 41, 59, 0.45)')
                .border({ width: 1, color: 'rgba(255, 255, 255, 0.08)', radius: 14 })
                .borderRadius(14)
                .onClick(() => {
                  if (this.onSelectFlight) {
                    this.onSelectFlight(item);
                  }
                  if (this.controller) {
                    this.controller.close();
                  }
                })
              }
            })
          }
          .width('100%')
          .height(280)
          .edgeEffect(EdgeEffect.Spring)
        } else {
          // 方案 B 经典航线列表
          List({ space: 10 }) {
            ForEach(this.routesList, (route: ClassicRoute) => {
              ListItem() {
                Column({ space: 8 }) {
                  Row() {
                    Text(route.routeName)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#F8FAFC')

                    Text(` · ${route.tag}`)
                      .fontSize(11)
                      .fontColor('#38BDF8')

                    Blank()

                    Text(route.recommendedFlightNo)
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#38BDF8')
                  }
                  .width('100%')

                  Divider().color('rgba(255, 255, 255, 0.06)')

                  Row() {
                    Column({ space: 2 }) {
                      Text(`${route.originAirport.city} (${route.originAirport.code})`)
                        .fontSize(13)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#F8FAFC')
                    }
                    .alignItems(HorizontalAlign.Start)

                    Text('─── ✈ ───➔')
                      .fontSize(10)
                      .fontColor('rgba(56, 189, 248, 0.5)')
                      .margin({ left: 8, right: 8 })

                    Column({ space: 2 }) {
                      Text(`${route.destAirport.city} (${route.destAirport.code})`)
                        .fontSize(13)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#F8FAFC')
                    }
                    .alignItems(HorizontalAlign.Start)

                    Blank()

                    Text(`${route.distanceKm} KM`)
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#94A3B8')
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(14)
                .backgroundColor('rgba(30, 41, 59, 0.45)')
                .border({ width: 1, color: 'rgba(56, 189, 248, 0.25)', radius: 14 })
                .borderRadius(14)
                .onClick(() => {
                  if (this.onSelectFlight) {
                    this.onSelectFlight({
                      flightNo: route.recommendedFlightNo,
                      airlineName: route.airlineName,
                      originAirport: route.originAirport,
                      destAirport: route.destAirport,
                      aircraftType: route.aircraftType,
                      status: '准备就绪',
                      flightDuration: `${Math.floor(route.distanceKm / 800) + 1} 小时`
                    });
                  }
                  if (this.controller) {
                    this.controller.close();
                  }
                })
              }
            })
          }
          .width('100%')
          .height(280)
          .edgeEffect(EdgeEffect.Spring)
        }
      } else {
        // 方案 C 自定义专属航班配置区
        Column({ space: 12 }) {
          // 自定义航班号
          Row({ space: 10 }) {
            Text('专属航班号:')
              .fontSize(13)
              .fontColor('#94A3B8')
              .width(85)

            TextInput({ text: this.customFlightNo })
              .fontColor('#38BDF8')
              .fontWeight(FontWeight.Bold)
              .fontSize(14)
              .backgroundColor('rgba(15, 23, 42, 0.7)')
              .border({ width: 1, color: 'rgba(56, 189, 248, 0.3)', radius: 8 })
              .height(36)
              .layoutWeight(1)
              .onChange((v: string) => {
                this.customFlightNo = v.toUpperCase();
              })
          }

          // 自定义专注航空口号
          Row({ space: 10 }) {
            Text('专注口号:')
              .fontSize(13)
              .fontColor('#94A3B8')
              .width(85)

            TextInput({ text: this.customAirline })
              .fontColor('#F8FAFC')
              .fontSize(13)
              .backgroundColor('rgba(15, 23, 42, 0.7)')
              .border({ width: 1, color: 'rgba(255, 255, 255, 0.1)', radius: 8 })
              .height(36)
              .layoutWeight(1)
              .onChange((v: string) => {
                this.customAirline = v;
              })
          }

          // 机型选择 Capsule
          Row({ space: 6 }) {
            Text('专属机型:')
              .fontSize(13)
              .fontColor('#94A3B8')
              .width(85)

            Text(this.customAircraft)
              .fontSize(12)
              .fontColor('#4ADE80')
              .fontWeight(FontWeight.Medium)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('rgba(74, 222, 128, 0.12)')
              .border({ width: 1, color: 'rgba(74, 222, 128, 0.3)', radius: 8 })
              .borderRadius(8)
          }
          .width('100%')

          // 生成专属航班按钮
          Button('生成专属专注航班并开启航线 ➔')
            .width('100%')
            .height(42)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('rgba(74, 222, 128, 0.22)')
            .fontColor('#4ADE80')
            .border({ width: 1, color: 'rgba(74, 222, 128, 0.5)', radius: 21 })
            .borderRadius(21)
            .shadow({ radius: 16, color: 'rgba(74, 222, 128, 0.3)', offsetY: 4 })
            .margin({ top: 10 })
            .onClick(() => {
              const origin = POPULAR_AIRPORTS[this.customOriginIdx % POPULAR_AIRPORTS.length];
              const dest = POPULAR_AIRPORTS[this.customDestIdx % POPULAR_AIRPORTS.length];
              if (this.onSelectFlight) {
                this.onSelectFlight({
                  flightNo: this.customFlightNo || 'FOCUS888',
                  airlineName: this.customAirline || '专注航空 Focus Air',
                  originAirport: origin,
                  destAirport: dest,
                  aircraftType: this.customAircraft,
                  status: '极速就绪',
                  flightDuration: '45 分钟'
                });
              }
              if (this.controller) {
                this.controller.close();
              }
            })
        }
        .width('100%')
        .padding(14)
        .backgroundColor('rgba(30, 41, 59, 0.45)')
        .border({ width: 1, color: 'rgba(74, 222, 128, 0.3)', radius: 14 })
        .borderRadius(14)
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 28 })
    .backgroundColor('rgba(10, 15, 26, 0.98)')
    .border({ width: { top: 1 }, color: 'rgba(56, 189, 248, 0.3)' })
    .borderRadius({ topLeft: 24, topRight: 24, bottomLeft: 0, bottomRight: 0 })
    .shadow({ radius: 36, color: 'rgba(0, 0, 0, 0.9)', offsetY: -8 })
  }
}


