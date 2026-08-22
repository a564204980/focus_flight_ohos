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

export interface FlightStatusBadgeInfo {
  text: string;
  color: string;
}

@Component
export struct LiveFlightLogDrawer {
  onClose?: () => void;
  @State sheetHeight: string = '0%';
  
  @Prop @Watch('onBadgeInputsChanged') isTurbulent: boolean = false;
  @State planeOffsetX: number = 0;
  @State planeOffsetY: number = 0;
  @State planeRotation: number = 0;
  @State @Watch('onBadgeInputsChanged') isTestingTurbulence: boolean = false;
  private physicsTimer: number = -1;
  private simTime: number = 0;
  private currentTurbulenceIntensity: number = 0;
  
  @StorageLink('activeFlightSession') @Watch('onBadgeInputsChanged') flightSession: FlightSessionData | null = null;
  @StorageProp('lastFlightEventUpdate') @Watch('onBadgeInputsChanged') updateTick: number = 0;
  @State timelineData: TimelineItemData[] = [];
  private timerId: number = -1;

  @State badgeText: string = '✓ 状态良好';
  @State badgeColor: string = '#10B981';
  @State badgeScale: number = 1.0;
  @State badgeOpacity: number = 1.0;

  onBadgeInputsChanged() {
    this.updateBadgeState(true);
    this.buildTimelineData();
  }

  updateBadgeState(animate: boolean = true) {
    const newBadge = this.computeFlightStatusBadge();
    if (this.badgeText === newBadge.text && this.badgeColor === newBadge.color) {
      return;
    }
    if (!animate) {
      this.badgeText = newBadge.text;
      this.badgeColor = newBadge.color;
      return;
    }

    // 优雅微动效：旧文案微缩渐隐 -> 注入新状态 -> 弹性弹入展开
    this.getUIContext()?.animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
      this.badgeOpacity = 0.2;
      this.badgeScale = 0.92;
    });

    setTimeout(() => {
      this.badgeText = newBadge.text;
      this.badgeColor = newBadge.color;
      this.getUIContext()?.animateTo({ duration: 260, curve: Curve.FastOutSlowIn }, () => {
        this.badgeOpacity = 1.0;
        this.badgeScale = 1.0;
      });
    }, 150);
  }

  private startPhysicsLoop() {
    if (this.physicsTimer !== -1) {
      return;
    }
    this.physicsTimer = setInterval(() => {
      this.simTime += 0.02;
      const targetIntensity = (this.isTurbulent || this.isTestingTurbulence) ? 1.0 : 0.0;
      // 极柔和的气动阻尼过渡 (Attack: ~0.5s 平滑进入, Release: ~0.8s 优雅回弹)
      const lerpSpeed = (targetIntensity > this.currentTurbulenceIntensity) ? 0.05 : 0.035;
      this.currentTurbulenceIntensity += (targetIntensity - this.currentTurbulenceIntensity) * lerpSpeed;
      
      const intensity = this.currentTurbulenceIntensity;
      
      // 1. 常规万米巡航：极微弱呼吸浮空感
      const cruiseHeave = Math.sin(this.simTime * 1.5) * 0.9;
      const cruiseDrift = Math.cos(this.simTime * 0.9) * 0.4;
      
      // 2. 真实微气流多重谐波 (整体幅度大幅缩减收敛，呈现极细腻微震颤)
      // 垂直沉浮 (短波气穴微浮沉)
      const heaveWave = (
        Math.sin(this.simTime * 4.2) * 1.5 + 
        Math.sin(this.simTime * 8.6) * 0.6 + 
        (Math.random() - 0.5) * 0.35
      ) * intensity;
      
      // 横向漂移 (微侧风)
      const swayWave = (
        Math.cos(this.simTime * 3.4) * 1.1 + 
        Math.sin(this.simTime * 7.1) * 0.4
      ) * intensity;
      
      // 俯仰微晃 (迎角自适应)
      const pitchWave = (
        Math.sin(this.simTime * 4.2 - 0.5) * 0.7 + 
        Math.cos(this.simTime * 9.3) * 0.25
      ) * intensity;

      this.planeOffsetY = cruiseHeave + heaveWave;
      this.planeOffsetX = cruiseDrift + swayWave;
      this.planeRotation = pitchWave;
    }, 20);
  }

  private stopPhysicsLoop() {
    if (this.physicsTimer !== -1) {
      clearInterval(this.physicsTimer);
      this.physicsTimer = -1;
    }
  }

  aboutToAppear() {
    this.updateBadgeState(false);
    this.buildTimelineData();
    this.startPhysicsLoop();
    setTimeout(() => {
      this.sheetHeight = '85%';
    }, 50);

    // 持续计算倒计时，每 1 秒实时高频刷新与平滑动效过渡
    this.timerId = setInterval(() => {
      this.updateBadgeState(true);
      this.buildTimelineData();
    }, 1000);
  }

  aboutToDisappear() {
    this.stopPhysicsLoop();
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  formatTime(ms: number): string {
    const d = new Date(ms);
    return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
  }

  computeFlightStatusBadge(): FlightStatusBadgeInfo {
    let badge: FlightStatusBadgeInfo = { text: '✓ 状态良好', color: '#10B981' };
    if (!this.flightSession) {
      if (this.isTurbulent || this.isTestingTurbulence) {
        badge = { text: '⚠️ 遭遇微气流', color: '#F59E0B' };
      }
      return badge;
    }

    const now = Date.now();
    const endTime = this.flightSession.startTimeMs + this.flightSession.durationMin * 60000;
    const remainingMs = endTime - now;
    const remainingMins = Math.ceil(remainingMs / 60000);
    const latestEvent = this.flightSession.events && this.flightSession.events.length > 0 ? this.flightSession.events[0] : null;

    if (remainingMs <= 0) {
      badge = { text: '✨ 顺利降落', color: '#059669' };
    } else if (this.isTurbulent || this.isTestingTurbulence) {
      badge = { text: '⚠️ 遭遇微气流', color: '#F59E0B' };
    } else if (latestEvent && latestEvent.type === 'deviation') {
      badge = { text: '⚠️ 偏离航线', color: '#EF4444' };
    } else if (latestEvent && latestEvent.type === 'recovery' && (now - latestEvent.timestampMs < 45000)) {
      badge = { text: '⚡ 航向修正', color: '#06B6D4' };
    } else if (remainingMins <= 5) {
      badge = { text: '🛫 准备进近', color: '#8B5CF6' };
    } else {
      badge = { text: '✓ 状态良好', color: '#10B981' };
    }
    return badge;
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
    // 3. 历史真实事件流 (保证起点必存且历史事件永不丢失)
    const rawEvents: FlightEvent[] = this.flightSession.events ? [...this.flightSession.events] : [];
    
    // 确保列表底部必定有 "撤出登机口" 起点
    const hasDeparture = rawEvents.some(e => e.type === 'gate_departure');
    if (!hasDeparture) {
      rawEvents.push({
        id: 'start_departure',
        type: 'gate_departure',
        timestampMs: this.flightSession.startTimeMs,
        note: '设备锁定，航线开始'
      });
    }

    // 如果刚起飞只有 gate_departure，在上方插入当前的 "航线巡航"
    if (rawEvents.length === 1 && rawEvents[0].type === 'gate_departure') {
      rawEvents.unshift({
        id: 'initial_cruise',
        type: 'cruise',
        timestampMs: Date.now(),
        note: '平稳飞行中'
      });
    }

    // 遍历事件列表（从新到旧）
    const totalCount = rawEvents.length;
    rawEvents.forEach((evt, idx) => {
      const isLatest = idx === 0;
      const isOldest = idx === totalCount - 1;
      
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
        icon = isLatest ? 'plane' : 'dot';
        color = '#EF4444';
        status = this.formatTime(evt.timestampMs);
      } else if (evt.type === 'turbulence') {
        mappedTitle = '气流颠簸';
        icon = isLatest ? 'plane' : 'dot';
        color = '#9CA3AF';
        status = this.formatTime(evt.timestampMs);
      } else if (evt.type === 'gate_departure') {
        mappedTitle = '撤出登机口';
        icon = 'start';
        color = '#10B981';
        status = this.formatTime(evt.timestampMs);
      }
      
      newList.push({
        id: evt.id,
        iconType: isOldest ? 'start' : icon,
        title: mappedTitle,
        subtitle: evt.note || '',
        statusText: status,
        statusColor: color,
        lineStyle: isLatest ? 'transition' : (isOldest ? 'start' : 'flown')
      });
    });

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
                  
                // 飞机形象展示 (支持气流颠簸时忽上忽下、忽左忽右、轻微俯仰)
                Image($r('app.media.b737_800_flat_3'))
                  .width('80%')
                  .objectFit(ImageFit.Contain)
                  .alignSelf(ItemAlign.Center)
                  .margin({ top: 16, bottom: 8 })
                  .translate({ x: this.planeOffsetX, y: this.planeOffsetY })
                  .rotate({ angle: this.planeRotation })
                  
                Row({ space: 8 }) {
                  Row() {
                    Text(this.badgeText)
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#FFFFFF')
                      .opacity(this.badgeOpacity)
                  }
                  .backgroundColor(this.badgeColor)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .borderRadius(4)
                  .scale({ x: this.badgeScale, y: this.badgeScale })
                  .animation({ duration: 260, curve: Curve.FastOutSlowIn })
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
    }
    .width('100%')
    .height('100%')
  }
}

@Component
struct TimelineRowItem {
  @Prop iconType: string;
  @Prop title: string;
  @Prop @Watch('onSubtitleChanged') subtitle: string;
  @Prop @Watch('onStatusChanged') statusText: string;
  @Prop statusColor: string;
  @Prop lineStyle: string;

  @State actualHeight: number = 0;
  @State subOpacity: number = 1.0;
  @State statusOpacity: number = 1.0;

  onSubtitleChanged() {
    this.getUIContext()?.animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
      this.subOpacity = 0.2;
    });
    setTimeout(() => {
      this.getUIContext()?.animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
        this.subOpacity = 1.0;
      });
    }, 150);
  }

  onStatusChanged() {
    this.getUIContext()?.animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
      this.statusOpacity = 0.2;
    });
    setTimeout(() => {
      this.getUIContext()?.animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
        this.statusOpacity = 1.0;
      });
    }, 150);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 左侧时间轴线条，通过 actualHeight 来精确控制高度，彻底杜绝 100% 带来的无限拉伸 bug
      Stack({ alignContent: Alignment.Center }) {
        if (this.lineStyle === 'dashed') {
          Column({ space: 6 }) {
            Rect().width(2).height(6).fill('#9CA3AF').radius(1)
            Rect().width(2).height(6).fill('#9CA3AF').radius(1)
            Rect().width(2).height(6).fill('#9CA3AF').radius(1)
          }.height(this.actualHeight > 0 ? this.actualHeight : (this.subtitle ? 56 : 40)).justifyContent(FlexAlign.Start).margin({ top: 4 })
        } else {
          Column() {
            if (this.lineStyle !== 'end' && this.lineStyle !== 'landed') {
              Column()
                .width(this.lineStyle === 'flown' || this.lineStyle === 'start' ? 3 : 2)
                .layoutWeight(1)
                .backgroundColor(this.lineStyle === 'flown' || this.lineStyle === 'start' ? '#4B5563' : '#E5E7EB')
                .borderRadius({ bottomLeft: 1.5, bottomRight: 1.5 })
            } else {
              Column().layoutWeight(1)
            }
            
            Column().width('100%').height((this.lineStyle === 'end' || this.lineStyle === 'landed') ? 20 : 32)
            
            if (this.lineStyle !== 'start') {
              Column()
                .width(this.lineStyle === 'flown' || this.lineStyle === 'transition' ? 3 : 2)
                .layoutWeight(1)
                .backgroundColor(this.lineStyle === 'flown' || this.lineStyle === 'transition' ? '#4B5563' : '#E5E7EB')
                .borderRadius((this.lineStyle === 'end' || this.lineStyle === 'landed') ? 0 : { topLeft: 1.5, topRight: 1.5 })
            } else {
              Column().layoutWeight(1)
            }
          }
          .width('100%')
          .height(this.actualHeight > 0 ? this.actualHeight : (this.subtitle ? 56 : 40))
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width(52)
      .height(this.actualHeight > 0 ? this.actualHeight : (this.subtitle ? 56 : 40))
      .position({ x: 0, y: 0 })

      // 左侧图标，固定高度 
      Stack({ alignContent: Alignment.Center }) {
        if (this.iconType === 'arrow_up') {
          Image($r('app.media.ic_arrow_up')).width(20).height(20)
        } else if (this.iconType === 'check') {
          Image($r('sys.media.ohos_ic_public_ok')).width(20).height(20).fillColor('#10B981')
        } else if (this.iconType === 'clock' || this.iconType === 'start') {
          // 🚀 航线起点专属标志：翡翠绿微光同心圆起点徽章
          Stack({ alignContent: Alignment.Center }) {
            Circle({ width: 16, height: 16 })
              .fill('#ECFDF5')
              .stroke('#10B981')
              .strokeWidth(2)
            Circle({ width: 6, height: 6 })
              .fill('#10B981')
          }
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
      .width(52)
      .height(this.subtitle ? 56 : 40)
      .position({ x: 0, y: 0 })

      // 右侧文字内容区，它自然换行，撑起整个 Stack 的高度
      Row() {
        Row() {
          Column() {
            Text(this.title)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.iconType === 'arrow_up' || this.iconType === 'circle_number' ? '#6B7280' : (this.iconType === 'check' ? '#10B981' : '#111827'))
            if (this.subtitle) {
              Text(this.subtitle)
                .fontSize(13)
                .fontColor('#6B7280')
                .margin({ top: 2 })
                .opacity(this.subOpacity)
                .animation({ duration: 200 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ right: 12 })
          .padding({ top: 12, bottom: 12 })

          if (this.statusText) {
            Text(this.statusText)
              .fontSize(13)
              .fontColor(this.statusColor)
              .fontWeight(FontWeight.Medium)
              .opacity(this.statusOpacity)
              .animation({ duration: 200 })
          }
        }
        .layoutWeight(1)
        .padding({ right: 16 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 52 }) // 留出左边距给绝对定位的线和图标
      .constraintSize({ minHeight: this.subtitle ? 56 : 40 })
      .onAreaChange((oldValue: Area, newValue: Area) => {
        // 当文字内容高度确定时，同步给 actualHeight
        let newH = newValue.height as number;
        let minH = this.subtitle ? 56 : 40;
        if (newH > minH && this.actualHeight !== newH) {
          this.actualHeight = newH;
        } else if (newH <= minH && this.actualHeight !== minH) {
          this.actualHeight = minH;
        }
      })
    }
    .width('100%')
    .backgroundColor(this.lineStyle === 'landed' ? 'rgba(16, 185, 129, 0.15)' : (this.lineStyle === 'end' ? '#F3F4F6' : 'transparent'))
    .borderRadius((this.lineStyle === 'end' || this.lineStyle === 'landed') ? 12 : 0)
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -20 })).combine(TransitionEffect.scale({ y: 0.5 })))
  }
}
