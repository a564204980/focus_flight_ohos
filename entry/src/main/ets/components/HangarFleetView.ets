import { vibrator } from '@kit.SensorServiceKit';
import { webview } from '@kit.ArkWeb';

export interface AircraftItem {
  id: string;
  brand: string;
  name: string;
  code: string;
  classTag: string; // 'J' | 'W' | 'Y'
  className: string;
  rangeKm: string;
  capacity: string;
  focusBonus: string;
  ancLevel: string;
  unlocked: boolean;
  unlockRequirement: string;
  has3DModel?: boolean;
}

/**
 * HangarFleetView.ets
 * Focus Flight 高奢战术机库 (Hangar Fleet View)
 * 深度对标图 3 (飞机交易与机库 UI) 的核心架构与视觉基因 + 3D 全息战机环视 (b737_800.glb)
 */
@Component
export struct HangarFleetView {
  private webController: webview.WebviewController = new webview.WebviewController();
  @State selectedBrandIndex: number = 0;
  @State currentAircraftId: string = 'b737_800';
  @State is3DViewerVisible: boolean = false;

  private brands: Array<string> = ['波音 BOEING', '空客 AIRBUS', '中国商飞 COMAC', '湾流 GULFSTREAM'];

  private aircraftList: Array<AircraftItem> = [
    {
      id: 'b737_800',
      brand: '波音 BOEING',
      name: 'B737-800 战术客机',
      code: 'B738',
      classTag: 'J',
      className: '极客 3D 主力机',
      rangeKm: '5,765 KM',
      capacity: '189 座席',
      focusBonus: '+25% 积分',
      ancLevel: 'ANC A+ 级',
      unlocked: true,
      unlockRequirement: '已拥有',
      has3DModel: true
    },
    {
      id: 'b787_9',
      brand: '波音 BOEING',
      name: 'B787-9 Dreamliner',
      code: 'B7879',
      classTag: 'J',
      className: '极客头等舱',
      rangeKm: '14,140 KM',
      capacity: '290 座席',
      focusBonus: '+25% 积分',
      ancLevel: 'ANC A+ 级',
      unlocked: true,
      unlockRequirement: '已拥有'
    },
    {
      id: 'a350_1000',
      brand: '空客 AIRBUS',
      name: 'A350-1000 XWB',
      code: 'A3510',
      classTag: 'J',
      className: '旗舰头等舱',
      rangeKm: '16,100 KM',
      capacity: '369 座席',
      focusBonus: '+30% 积分',
      ancLevel: '静音舱 A++',
      unlocked: true,
      unlockRequirement: '已拥有'
    },
    {
      id: 'c919',
      brand: '中国商飞 COMAC',
      name: 'C919 巡航主力机',
      code: 'C919',
      classTag: 'W',
      className: '战术商务舱',
      rangeKm: '5,555 KM',
      capacity: '168 座席',
      focusBonus: '+20% 积分',
      ancLevel: 'ANC A 级',
      unlocked: true,
      unlockRequirement: '已拥有'
    },
    {
      id: 'b737_max',
      brand: '波音 BOEING',
      name: 'B737 MAX 8',
      code: 'B38M',
      classTag: 'Y',
      className: '快捷经济舱',
      rangeKm: '6,570 KM',
      capacity: '189 座席',
      focusBonus: '+15% 积分',
      ancLevel: 'ANC B+ 级',
      unlocked: true,
      unlockRequirement: '已拥有'
    },
    {
      id: 'g650er',
      brand: '湾流 GULFSTREAM',
      name: 'Gulfstream G650ER',
      code: 'G650',
      classTag: 'J',
      className: '私人隐秘舱',
      rangeKm: '13,890 KM',
      capacity: '19 座席',
      focusBonus: '+35% 积分',
      ancLevel: '绝对静音 S 级',
      unlocked: false,
      unlockRequirement: '专注满 100 小时解锁'
    }
  ];

  private triggerHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 25
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      // ignore
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // 主机库页面
      Column({ space: 12 }) {
        // 1. 机库战术 Telemetry Header (对标图 3 资产统计)
        Row() {
          Column({ space: 3 }) {
            Row({ space: 8 }) {
              Text('FOCUS FLEET HANGAR')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0EA5E9')
                .letterSpacing(1.5)

              Row() {
                Text('机群规模 5/6')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#10B981')
              }
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor('rgba(16, 185, 129, 0.12)')
              .border({ width: 1, color: 'rgba(16, 185, 129, 0.3)', radius: 4 })
              .borderRadius(4)
            }

            Text('专注战队机库 · 旗舰机群管理')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F8FAFC')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // 顶部 3D 环视直达按钮
          Row({ space: 4 }) {
            Text('🔍')
              .fontSize(12)
            Text('3D 战机环视')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0EA5E9')
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('rgba(14, 165, 233, 0.15)')
          .border({ width: 1, color: '#0EA5E9', radius: 8 })
          .borderRadius(8)
          .onClick(() => {
            this.triggerHaptic();
            this.is3DViewerVisible = true;
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 4 })

        // 2. 品牌系列厂商 Tabs (对标图 3 顶部厂商分栏)
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.brands, (brandName: string, idx: number) => {
              Row() {
                Text(brandName)
                  .fontSize(12)
                  .fontWeight(this.selectedBrandIndex === idx ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.selectedBrandIndex === idx ? '#0EA5E9' : '#94A3B8')
              }
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(this.selectedBrandIndex === idx ? 'rgba(14, 165, 233, 0.12)' : '#0D1322')
              .border({
                width: 1,
                color: this.selectedBrandIndex === idx ? '#0EA5E9' : '#1E293B',
                radius: 18
              })
              .borderRadius(18)
              .onClick(() => {
                this.triggerHaptic();
                this.selectedBrandIndex = idx;
              })
            })
          }
          .padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        // 3. 战机卡片网格列表 (对标图 3 交易卡片)
        Scroll() {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            ForEach(this.aircraftList, (item: AircraftItem) => {
              Column({ space: 8 }) {
                // 卡片 Header：芯片 Badge + 代号 Tag
                Row() {
                  // 舱位芯片 Badge
                  Row({ space: 4 }) {
                    Text(item.classTag)
                      .fontSize(10)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(item.classTag === 'J' ? '#F59E0B' : (item.classTag === 'W' ? '#0EA5E9' : '#10B981'))
                    Text(item.className)
                      .fontSize(10)
                      .fontColor('#F8FAFC')
                  }
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor('rgba(15, 23, 42, 0.8)')
                  .border({
                    width: 1,
                    color: item.classTag === 'J' ? 'rgba(245, 158, 11, 0.4)' : 'rgba(14, 165, 233, 0.4)',
                    radius: 4
                  })
                  .borderRadius(4)

                  Blank()

                  // 机型代号
                  Text(item.code)
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#64748B')
                }
                .width('100%')

                // 机型名称
                Text(item.name)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(item.unlocked ? '#F8FAFC' : '#64748B')

                // 飞机 2D / 3D 渲染控制区
                Stack({ alignContent: Alignment.Center }) {
                  Row() {
                    Text(item.has3DModel ? '🛩️ 3D 模型 b737_800.glb' : '✈️ JET SILHOUETTE')
                      .fontSize(11)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(item.has3DModel ? '#10B981' : (item.unlocked ? '#0EA5E9' : '#475569'))
                      .letterSpacing(1)
                  }
                  .width('100%')
                  .height(36)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('rgba(0, 0, 0, 0.25)')
                  .borderRadius(6)
                  .onClick(() => {
                    if (item.has3DModel) {
                      this.triggerHaptic();
                      this.is3DViewerVisible = true;
                    }
                  })
                }

                // 4 格战术参数矩阵 (对标图 3 航程/载客/油耗/维护)
                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                  Column({ space: 1 }) {
                    Text('最大航程')
                      .fontSize(8)
                      .fontColor('#64748B')
                    Text(item.rangeKm)
                      .fontSize(10)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#F8FAFC')
                  }
                  .width('48%')

                  Column({ space: 1 }) {
                    Text('巡航座席')
                      .fontSize(8)
                      .fontColor('#64748B')
                    Text(item.capacity)
                      .fontSize(10)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#F8FAFC')
                  }
                  .width('48%')

                  Column({ space: 1 }) {
                    Text('专注效率')
                      .fontSize(8)
                      .fontColor('#64748B')
                    Text(item.focusBonus)
                      .fontSize(10)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#10B981')
                  }
                  .width('48%')
                  .margin({ top: 4 })

                  Column({ space: 1 }) {
                    Text('降噪等级')
                      .fontSize(8)
                      .fontColor('#64748B')
                    Text(item.ancLevel)
                      .fontSize(10)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#0EA5E9')
                  }
                  .width('48%')
                  .margin({ top: 4 })
                }
                .width('100%')

                Divider().color('#1E293B')

                // 3D 专属点击查看按键
                if (item.has3DModel) {
                  Row({ space: 6 }) {
                    Text('🔍 3D 360° 全息环视')
                      .fontSize(11)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#0EA5E9')
                  }
                  .width('100%')
                  .height(34)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('rgba(14, 165, 233, 0.16)')
                  .border({ width: 1, color: '#0EA5E9', radius: 8 })
                  .borderRadius(8)
                  .onClick(() => {
                    this.triggerHaptic();
                    this.is3DViewerVisible = true;
                  })
                } else if (this.currentAircraftId === item.id) {
                  Row({ space: 4 }) {
                    Text('●')
                      .fontSize(8)
                      .fontColor('#10B981')
                    Text('当前巡航座驾')
                      .fontSize(11)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#10B981')
                  }
                  .width('100%')
                  .height(34)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('rgba(16, 185, 129, 0.12)')
                  .border({ width: 1, color: '#10B981', radius: 8 })
                  .borderRadius(8)
                } else if (item.unlocked) {
                  Row() {
                    Text('🛫 设为巡航座驾')
                      .fontSize(11)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#0EA5E9')
                  }
                  .width('100%')
                  .height(34)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('rgba(14, 165, 233, 0.12)')
                  .border({ width: 1, color: '#0EA5E9', radius: 8 })
                  .borderRadius(8)
                  .onClick(() => {
                    this.triggerHaptic();
                    this.currentAircraftId = item.id;
                  })
                } else {
                  Row() {
                    Text(`🔒 ${item.unlockRequirement}`)
                      .fontSize(10)
                      .fontColor('#64748B')
                  }
                  .width('100%')
                  .height(34)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('rgba(255, 255, 255, 0.03)')
                  .border({ width: 1, color: '#1E293B', radius: 8 })
                  .borderRadius(8)
                }
              }
              .width('48.5%')
              .padding(12)
              .margin({ bottom: 12 })
              .backgroundColor('#0D1322')
              .border({
                width: 1,
                color: item.has3DModel ? '#0EA5E9' : (this.currentAircraftId === item.id ? '#10B981' : (item.unlocked ? '#1E293B' : 'rgba(255, 255, 255, 0.05)')),
                radius: 12
              })
              .borderRadius(12)
            })
          }
          .padding({ left: 16, right: 16, bottom: 90 })
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(10, 15, 26, 0.92)')
      .backdropBlur(20)

      // 全屏 3D 全息战机 360° 环视弹窗 (b737_800.glb)
      if (this.is3DViewerVisible) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Web({
            src: $rawfile('hangar_3d.html'),
            controller: this.webController
          })
            .width('100%')
            .height('100%')
            .backgroundColor('#050914')
            .domStorageAccess(true)
            .fileAccess(true)
            .imageAccess(true)
            .onlineImageAccess(true)
            .javaScriptAccess(true)

          // 右上角 ✕ 关闭按钮
          Row() {
            Text('✕ 关闭 3D 预览')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F8FAFC')
          }
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .margin({ top: 48, right: 16 })
          .backgroundColor('rgba(15, 23, 42, 0.85)')
          .border({ width: 1, color: '#0EA5E9', radius: 20 })
          .borderRadius(20)
          .backdropBlur(12)
          .onClick(() => {
            this.triggerHaptic();
            this.is3DViewerVisible = false;
          })
        }
        .width('100%')
        .height('100%')
        .zIndex(999)
        .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
      }
    }
    .width('100%')
    .height('100%')
  }
}
