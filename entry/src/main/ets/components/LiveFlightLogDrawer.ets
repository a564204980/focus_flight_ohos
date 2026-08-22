import { CloseButton } from './CloseButton'
import { FlightSessionData, FlightEvent } from '../services/FlightSessionStore';

export interface TimelineItemData {
  id: string;
  iconType: string;
  title: string;
  subtitle: string;
  statusText: string;
  statusColor: string;
  lineStyle: string;
}

@Component
export struct LiveFlightLogDrawer {
  onClose?: () => void;
  @State sheetHeight: string = '0%';
  
  @StorageLink('activeFlightSession') flightSession: FlightSessionData | null = null;
  @StorageProp('lastFlightEventUpdate') @Watch('buildTimelineData') updateTick: number = 0;
  @State timelineData: TimelineItemData[] = [];
  private timerId: number = -1;

  aboutToAppear() {
    this.buildTimelineData();
    setTimeout(() => {
      this.sheetHeight = '85%';
    }, 50);

    // 持续计算倒计时，每 10 秒刷新一次UI
    this.timerId = setInterval(() => {
      this.buildTimelineData();
    }, 10000);
  }

  aboutToDisappear() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  formatTime(ms: number): string {
    const d = new Date(ms);
    return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
  }

  buildTimelineData() {
    if (!this.flightSession) {
      // Fallback for preview / testing
      this.timelineData = [
        { id: '1', iconType: 'arrow_up', title: '预计降落', subtitle: '距离到达目的地还有 21 分钟', statusText: '预计 14:45', statusColor: '#10B981', lineStyle: 'end' },
        { id: '3', iconType: 'plane', title: '深度心流巡航', subtitle: '飞行高度 35,000 英尺', statusText: '完美', statusColor: '#10B981', lineStyle: 'transition' },
        { id: '8', iconType: 'clock', title: '撤出登机口', subtitle: '设备锁定，航线开始', statusText: '14:00', statusColor: '#10B981', lineStyle: 'start' }
      ];
      return;
    }

    const now = Date.now();
    const endTime = this.flightSession.startTimeMs + this.flightSession.durationMin * 60000;
    const remainingMs = endTime - now;
    const remainingMins = Math.max(0, Math.ceil(remainingMs / 60000));
    
    let newList: TimelineItemData[] = [];
    
    // 1. 终点目标：预计降落
    newList.push({
      id: 'end',
      iconType: 'arrow_up',
      title: '预计降落',
      subtitle: remainingMins > 0 ? `距离到达目的地还有 ${remainingMins} 分钟` : '即将降落',
      statusText: `预计 ${this.formatTime(endTime)}`,
      statusColor: '#10B981',
      lineStyle: 'end'
    });

    // 2. 如果剩余时间小于等于 5 分钟，且还没降落，插入“准备下降” (只有在真正接近尾声时出现)
    if (remainingMins <= 5 && remainingMins > 0) {
      newList.push({
        id: 'descent',
        iconType: 'dot',
        title: '准备下降',
        subtitle: '收起小桌板，即将抵达目标',
        statusText: '',
        statusColor: '',
        lineStyle: 'future' // 这时它上面的降落是 end，下面的是当前巡航
      });
    }

    // 3. 历史真实事件流 (如果有)
    // 注意事件流是从新到旧，最新的在上面 (紧接着降落/准备下降)，最老的(起飞)在最下面
    const events = this.flightSession.events || [];
    
    if (events.length === 0) {
      // 没有任何事件时，插入一个正在巡航作为默认当前状态
      newList.push({
        id: 'default_cruise',
        iconType: 'plane',
        title: '航线巡航',
        subtitle: '平稳飞行中',
        statusText: '专注中',
        statusColor: '#10B981',
        lineStyle: 'transition'
      });
      // 插入起点
      newList.push({
        id: 'start',
        iconType: 'clock',
        title: '撤出登机口',
        subtitle: '设备锁定，航线开始',
        statusText: this.formatTime(this.flightSession.startTimeMs),
        statusColor: '#10B981',
        lineStyle: 'start'
      });
    } else {
      // 遍历事件，最上面的事件（最新的事件）为 transition，其余为 flown
      // (假设 events 按时间降序排列，index 0 为最新)
      events.forEach((evt, idx) => {
        const isLatest = idx === 0;
        const isOldest = idx === events.length - 1;
        
        let icon = 'dot';
        let status = '';
        let color = '#9CA3AF';
        let mappedTitle = '航线巡航';
        
        if (evt.type === 'cruise') {
          mappedTitle = '航线巡航';
          icon = isLatest ? 'plane' : 'dot';
          status = isLatest ? '专注中' : this.formatTime(evt.timestampMs);
          color = isLatest ? '#10B981' : '#9CA3AF';
        } else if (evt.type === 'recovery') {
          mappedTitle = '航线修正';
          icon = isLatest ? 'plane' : 'dot';
          status = isLatest ? '专注中' : this.formatTime(evt.timestampMs);
          color = isLatest ? '#10B981' : '#9CA3AF';
        } else if (evt.type === 'deviation') {
          mappedTitle = '偏离航线';
          color = '#EF4444';
          status = this.formatTime(evt.timestampMs);
        } else if (evt.type === 'turbulence') {
          mappedTitle = '气流颠簸';
          color = '#9CA3AF';
          status = this.formatTime(evt.timestampMs);
        } else if (evt.type === 'gate_departure') {
          mappedTitle = '撤出登机口';
          icon = 'clock';
          color = '#10B981';
          status = this.formatTime(evt.timestampMs);
        }
        
        newList.push({
          id: evt.id,
          iconType: icon,
          title: mappedTitle,
          subtitle: evt.note || '',
          statusText: status,
          statusColor: color,
          lineStyle: isLatest ? 'transition' : (isOldest ? 'start' : 'flown')
        });
      });
    }

    this.timelineData = newList;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 遮罩层
      Rect()
        .width('100%')
        .height('100%')
        .fill('rgba(0,0,0,0.4)')
        .onClick(() => {
          this.sheetHeight = '0%';
          setTimeout(() => {
            if (this.onClose) this.onClose();
          }, 300);
        })

      // 抽屉主体 (纯白圆角)
      Column() {
        // 顶部小横条指示器
        Row() {
          Row()
            .width(40)
            .height(5)
            .backgroundColor('#E5E7EB')
            .borderRadius(2.5)
        }
        .width('100%')
        .height(24)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 4, bottom: 8 })

        // 头部标题区域 (还原 Flighty 头部风格)
        Row() {
          Column() {
            Text("FOCUS FLIGHT · 当前航段")
              .fontSize(11)
              .fontColor('#6B7280')
              .fontWeight(FontWeight.Medium)
            Text("航行日志")
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#111827')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          
          Blank()
          
          // 关闭按钮 (通用组件)
          CloseButton({
            circleColor: '#F3F4F6',
            iconColor: '#111827',
            onClickAction: () => {
              this.sheetHeight = '0%';
              setTimeout(() => {
                if (this.onClose) this.onClose();
              }, 300);
            }
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
        .margin({ bottom: 20 })
        
        Divider().color('#F3F4F6').strokeWidth(1).margin({ bottom: 20 })

        // 核心时间轴白底卡片
        Scroll() {
          Column() {
            // 卡片容器
            Column() {
              // 卡片头部深色背景 (模仿 Where's My Plane 蓝天背景)
              Column() {
                Row() {
                  Text("航班动态")
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                  Blank()
                  Text("PRO")
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#8B5CF6')
                    .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                    .borderRadius(4)
                }.width('100%').padding({ left: 16, right: 16, top: 16 })
                
                Text("B737-800")
                  .fontSize(13)
                  .fontColor('rgba(255,255,255,0.8)')
                  .margin({ top: 4, left: 16 })
                  
                // 占位飞机图
                Image($r('app.media.b737_800_flat_3'))
                  .width('80%')
                  .objectFit(ImageFit.Contain)
                  .alignSelf(ItemAlign.Center)
                  .margin({ top: 16, bottom: 8 })
                  
                Row({ space: 8 }) {
                  Row() {
                    Text("✓ 状态良好")
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#FFFFFF')
                  }
                  .backgroundColor('#10B981')
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .borderRadius(4)
                  
                  Button("测试事件")
                    .fontSize(12)
                    .height(24)
                    .backgroundColor('#E5E7EB')
                    .fontColor('#111827')
                    .onClick(() => {
                      animateTo({ duration: 400, curve: Curve.FastOutSlowIn }, () => {
                        if (this.flightSession) {
                          if (!this.flightSession.events) {
                            this.flightSession.events = [];
                          }
                          this.flightSession.events.unshift({
                            id: Date.now().toString(),
                            type: 'cruise',
                            timestampMs: Date.now(),
                            note: '新专注阶段'
                          });
                          this.buildTimelineData();
                        } else {
                          // Fallback for preview
                          let transitionIdx = this.timelineData.findIndex(item => item.lineStyle === 'transition');
                          if (transitionIdx !== -1) {
                            let oldItem = this.timelineData[transitionIdx];
                            this.timelineData[transitionIdx] = {
                              id: oldItem.id,
                              iconType: 'dot',
                              title: oldItem.title,
                              subtitle: oldItem.subtitle,
                              statusText: oldItem.statusText,
                              statusColor: oldItem.statusColor,
                              lineStyle: 'flown'
                            };
                          }
                          this.timelineData.splice(transitionIdx !== -1 ? transitionIdx : 1, 0, {
                            id: Date.now().toString(),
                            iconType: 'plane',
                            title: '新专注阶段',
                            subtitle: '动态推入动画测试',
                            statusText: '专注中',
                            statusColor: '#10B981',
                            lineStyle: 'transition'
                          });
                        }
                      })
                    })
                }
                .width('100%')
                .padding({ left: 16, bottom: 12 })
              }
              .width('100%')
              .linearGradient({
                direction: GradientDirection.Bottom,
                colors: [
                  ['#5A99E5', 0.0],
                  ['#74A9ED', 0.45],
                  ['#FFFFFF', 0.85],
                  ['#FFFFFF', 1.0]
                ]
              })
              .alignItems(HorizontalAlign.Start)
              
              Text("一切顺利！本次航程正在按计划稳步推进中。")
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#111827')
                .padding({ left: 16, right: 16, top: 12, bottom: 16 })
                .backgroundColor('#FFFFFF')
                .width('100%')

              // 底部白底时间轴列表 (自下而上: 过去 -> 未来)
              Column() {
                ForEach(this.timelineData, (item: TimelineItemData) => {
                  TimelineRowItem({
                    iconType: item.iconType,
                    title: item.title,
                    subtitle: item.subtitle,
                    statusText: item.statusText,
                    statusColor: item.statusColor,
                    lineStyle: item.lineStyle
                  })
                }, (item: TimelineItemData) => item.id + '_' + item.lineStyle)
              }
              .width('100%')
              .backgroundColor('#FFFFFF')
              .padding({ top: 16, bottom: 20, left: 16, right: 16 })
            }
            .width('100%')
            .clip(true)
            .borderRadius(16)
            .border({ width: 1, color: '#E5E7EB' })
          }
          .padding({ left: 16, right: 16, bottom: 40 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height(this.sheetHeight)
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 24, topRight: 24 })
      .shadow({ radius: 30, color: 'rgba(0,0,0,0.15)', offsetY: -10 })
      .animation({ duration: 400, curve: Curve.FastOutSlowIn })
    }
    .width('100%')
    .height('100%')
  }
}

@Component
struct TimelineRowItem {
  @Prop iconType: string;
  @Prop title: string;
  @Prop subtitle: string;
  @Prop statusText: string;
  @Prop statusColor: string;
  @Prop lineStyle: string;

  @State actualHeight: number = 0;

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.lineStyle === 'dashed') {
          Column({ space: 6 }) {
            Rect().width(2).height(6).fill('#9CA3AF').radius(1)
            Rect().width(2).height(6).fill('#9CA3AF').radius(1)
            Rect().width(2).height(6).fill('#9CA3AF').radius(1)
          }.height(this.actualHeight > 0 ? this.actualHeight : '100%').justifyContent(FlexAlign.Start).margin({ top: 4 })
        } else {
          Column() {
            if (this.lineStyle !== 'end') {
              Column()
                .width(this.lineStyle === 'flown' || this.lineStyle === 'start' ? 3 : 2)
                .layoutWeight(1)
                .backgroundColor(this.lineStyle === 'flown' || this.lineStyle === 'start' ? '#4B5563' : '#E5E7EB')
                .borderRadius({ bottomLeft: 1.5, bottomRight: 1.5 })
            } else {
              Column().layoutWeight(1)
            }
            
            Column().width('100%').height(this.lineStyle === 'end' ? 20 : 32)
            
            if (this.lineStyle !== 'start') {
              Column()
                .width(this.lineStyle === 'flown' || this.lineStyle === 'transition' ? 3 : 2)
                .layoutWeight(1)
                .backgroundColor(this.lineStyle === 'flown' || this.lineStyle === 'transition' ? '#4B5563' : '#E5E7EB')
                .borderRadius(this.lineStyle === 'end' ? 0 : { topLeft: 1.5, topRight: 1.5 })
            } else {
              Column().layoutWeight(1)
            }
          }
          .width('100%')
          .height(this.actualHeight > 0 ? this.actualHeight : (this.subtitle ? 56 : 40))
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width(44)
      .height(this.actualHeight > 0 ? this.actualHeight : (this.subtitle ? 56 : 40))

      Row() {
        Row().width(52).height(1)
        
        Row() {
          Column() {
            Text(this.title)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.iconType === 'arrow_up' || this.iconType === 'clock' || this.iconType === 'circle_number' ? '#6B7280' : '#111827')
            if (this.subtitle) {
              Text(this.subtitle)
                .fontSize(13)
                .fontColor('#6B7280')
                .margin({ top: 2 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ right: 12 })
          .padding({ top: 8, bottom: 8 })

          if (this.statusText) {
            Text(this.statusText)
              .fontSize(13)
              .fontColor(this.statusColor)
              .fontWeight(FontWeight.Medium)
          }
        }
        .layoutWeight(1)
        .padding({ right: 16 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .onAreaChange((oldValue: Area, newValue: Area) => {
        let newH = newValue.height as number;
        let minH = this.subtitle ? 56 : 40;
        if (newH > minH) {
          this.actualHeight = newH;
        } else {
          this.actualHeight = minH;
        }
      })

      Stack({ alignContent: Alignment.Center }) {
        if (this.iconType === 'arrow_up') {
          Image($r('app.media.ic_arrow_up')).width(20).height(20)
        } else if (this.iconType === 'clock') {
          Image($r('app.media.ic_clock')).width(18).height(18)
        } else if (this.iconType === 'plane') {
          Image($r('app.media.ic_plane_topview')).width(20).height(20).fillColor('#4B5563')
        } else if (this.iconType === 'dot') {
          Circle({ width: 7, height: 7 }).fill('#4B5563')
        } else if (this.iconType === 'circle_number') {
          Row() {
            Text("3").fontSize(11).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
          }.width(18).height(18).borderRadius(9).backgroundColor('#4B5563').justifyContent(FlexAlign.Center)
        }
      }
      .width(44)
    }
    .width('100%')
    .backgroundColor(this.lineStyle === 'end' ? '#F3F4F6' : 'transparent')
    .borderRadius(this.lineStyle === 'end' ? 12 : 0)
    .constraintSize({ minHeight: this.subtitle ? 56 : 40 })
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -20 })).combine(TransitionEffect.scale({ y: 0.5 })))
  }
}
