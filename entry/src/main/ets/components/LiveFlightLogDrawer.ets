import { CloseButton } from './CloseButton'
import { FlightSessionData, FlightEvent } from '../services/FlightSessionStore';
import { Airport } from '../models/AirportModel';

export interface TimelineItemData {
  id: string;
  iconType: string;
  title: string;
  subtitle: string;
  statusText: string;
  statusColor: string;
  lineStyle: string;
}

interface CardRainDrop {
  x: number;
  y: number;
  len: number;
  speed: number;
  opacity: number;
}

interface CardSnowFlake {
  x: number;
  y: number;
  r: number;
  speedY: number;
  speedX: number;
  opacity: number;
  swayOffset: number;
}

export interface FlightStatusBadgeInfo {
  icon: string;
  text: string;
  color: string;
}

@Component
export struct LiveFlightLogDrawer {
  onClose?: () => void;
  @State sheetHeight: string = '0%';
  
  @Prop @Watch('onBadgeInputsChanged') isTurbulent: boolean = false;
  @Prop @Watch('onBadgeInputsChanged') currentWeatherType: 'clear' | 'thunderstorm' | 'snow' = 'clear';
  @State planeOffsetX: number = 0;
  @State planeOffsetY: number = 0;
  @State planeRotation: number = 0;
  @State @Watch('onBadgeInputsChanged') isTestingTurbulence: boolean = false;
  private physicsTimer: number = -1;
  private simTime: number = 0;
  private currentTurbulenceIntensity: number = 0;

  // 🌧️ 飞机预览卡片微型动态气象层
  private weatherCardContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private cardRainDrops: CardRainDrop[] = [];
  private cardSnowFlakes: CardSnowFlake[] = [];
  private cardCanvasWidth: number = 320;
  private cardCanvasHeight: number = 190;
  
  @StorageLink('activeFlightSession') @Watch('onBadgeInputsChanged') flightSession: FlightSessionData | null = null;
  @StorageLink('selectedDestinationAirport') destinationAirport: Airport | undefined = undefined;
  @StorageProp('lastFlightEventUpdate') @Watch('onBadgeInputsChanged') updateTick: number = 0;
  @State timelineData: TimelineItemData[] = [];
  private timerId: number = -1;

  private getRouteFlightNo(): string {
    return 'FF 8820';
  }

  private getFormattedFlightDate(): string {
    const now = new Date();
    const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    const months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    const dayStr = days[now.getDay()];
    const monthStr = months[now.getMonth()];
    const dateNum = now.getDate();
    return `${this.getRouteFlightNo()} · ${dayStr}, ${dateNum} ${monthStr}`;
  }

  private getRouteCityName(): string {
    const destCity = this.destinationAirport?.city || '北京';
    return `成都 到 ${destCity}`;
  }

  private getCardSubtitle(): string {
    if (this.currentWeatherType === 'thunderstorm') {
      return "B737-800 · 穿越对流雷暴云团";
    } else if (this.currentWeatherType === 'snow') {
      return "B737-800 · 穿越高空冷锋风雪带";
    }
    return "B737-800 · 巡航飞行中";
  }

  private getCardGradientColors(): [ResourceColor, number][] {
    if (this.currentWeatherType === 'thunderstorm') {
      return [
        ['#1E293B', 0.0],  // 沉稳风暴深蓝灰 (绝无怪异紫色)
        ['#334155', 0.45], // 高空阴云灰
        ['#475569', 0.68], // 细腻平滑过渡层
        ['#94A3B8', 0.84], // 浅云雾微散
        ['#E2E8F0', 0.94], // 柔和极浅灰
        ['#FFFFFF', 1.0]   // 100% 丝滑无缝融入白底
      ];
    } else if (this.currentWeatherType === 'snow') {
      return [
        ['#334155', 0.0],  // 极地冷锋灰
        ['#475569', 0.45], // 冰云蓝灰
        ['#64748B', 0.68],
        ['#CBD5E1', 0.86],
        ['#F1F5F9', 0.95],
        ['#FFFFFF', 1.0]
      ];
    }
    return [
      ['#5A99E5', 0.0],  // 晴空明媚蔚蓝
      ['#74A9ED', 0.45],
      ['#A0C6F5', 0.70],
      ['#D6E6FC', 0.88],
      ['#F3F8FE', 0.96],
      ['#FFFFFF', 1.0]
    ];
  }

  @State badgeIcon: string = '✓';
  @State badgeText: string = '状态良好';
  @State badgeColor: string = '#10B981';
  @State badgeScale: number = 1.0;
  @State badgeOpacity: number = 1.0;

  onBadgeInputsChanged() {
    this.updateBadgeState(true);
    this.buildTimelineData();
    this.initCardWeatherParticles();
  }

  updateBadgeState(animate: boolean = true) {
    const newBadge = this.computeFlightStatusBadge();
    if (this.badgeText === newBadge.text && this.badgeIcon === newBadge.icon && this.badgeColor === newBadge.color) {
      return;
    }
    if (!animate) {
      this.badgeIcon = newBadge.icon;
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
      this.badgeIcon = newBadge.icon;
      this.badgeText = newBadge.text;
      this.badgeColor = newBadge.color;
      this.getUIContext()?.animateTo({ duration: 260, curve: Curve.FastOutSlowIn }, () => {
        this.badgeOpacity = 1.0;
        this.badgeScale = 1.0;
      });
    }, 150);
  }

  private initCardWeatherParticles(): void {
    const w = this.cardCanvasWidth > 0 ? this.cardCanvasWidth : 320;
    const h = this.cardCanvasHeight > 0 ? this.cardCanvasHeight : 190;

    if (this.currentWeatherType === 'thunderstorm') {
      this.cardRainDrops = [];
      for (let i = 0; i < 40; i++) {
        this.cardRainDrops.push({
          x: Math.random() * (w + 60) - 30,
          y: Math.random() * h,
          len: Math.random() * 8 + 12,
          speed: Math.random() * 5 + 10,
          opacity: Math.random() * 0.35 + 0.25
        });
      }
    } else if (this.currentWeatherType === 'snow') {
      this.cardSnowFlakes = [];
      for (let i = 0; i < 24; i++) {
        this.cardSnowFlakes.push({
          x: Math.random() * w,
          y: Math.random() * h,
          r: Math.random() * 2.0 + 1.0,
          speedY: Math.random() * 0.8 + 0.6,
          speedX: (Math.random() - 0.5) * 0.4,
          opacity: Math.random() * 0.5 + 0.3,
          swayOffset: Math.random() * Math.PI * 2
        });
      }
    }
  }

  private renderCardWeatherFrame(): void {
    if (!this.weatherCardContext || this.currentWeatherType === 'clear') {
      return;
    }
    const w = this.cardCanvasWidth > 0 ? this.cardCanvasWidth : 320;
    const h = this.cardCanvasHeight > 0 ? this.cardCanvasHeight : 190;

    try {
      this.weatherCardContext.clearRect(0, 0, w, h);

      if (this.currentWeatherType === 'thunderstorm') {
        const windAngle = 0.18; // 轻微斜向迎风

        for (let drop of this.cardRainDrops) {
          drop.y += drop.speed;
          drop.x += drop.speed * windAngle;

          if (drop.y > h + 10) {
            drop.y = -15;
            drop.x = Math.random() * (w + 60) - 30;
          }

          const startX = drop.x;
          const startY = drop.y - drop.len;
          const endX = drop.x + drop.len * windAngle;
          const endY = drop.y;

          // 渐变雨丝 (头部浅、尾部亮)
          const grad = this.weatherCardContext.createLinearGradient(startX, startY, endX, endY);
          grad.addColorStop(0.0, 'rgba(255, 255, 255, 0.0)');
          grad.addColorStop(0.5, `rgba(224, 235, 255, ${drop.opacity * 0.5})`);
          grad.addColorStop(1.0, `rgba(255, 255, 255, ${drop.opacity})`);

          this.weatherCardContext.beginPath();
          this.weatherCardContext.moveTo(startX, startY);
          this.weatherCardContext.lineTo(endX, endY);
          this.weatherCardContext.strokeStyle = grad;
          this.weatherCardContext.lineWidth = 1.1;
          this.weatherCardContext.stroke();
        }
      } else if (this.currentWeatherType === 'snow') {
        for (let s of this.cardSnowFlakes) {
          s.y += s.speedY;
          s.x += s.speedX + Math.sin(this.simTime * 2.0 + s.swayOffset) * 0.4;

          if (s.y > h + 10) {
            s.y = -10;
            s.x = Math.random() * w;
          }

          const grad = this.weatherCardContext.createRadialGradient(s.x, s.y, 0, s.x, s.y, s.r);
          grad.addColorStop(0.0, `rgba(255, 255, 255, ${s.opacity})`);
          grad.addColorStop(0.7, `rgba(240, 248, 255, ${s.opacity * 0.5})`);
          grad.addColorStop(1.0, 'rgba(255, 255, 255, 0.0)');

          this.weatherCardContext.beginPath();
          this.weatherCardContext.arc(s.x, s.y, s.r, 0, Math.PI * 2);
          this.weatherCardContext.fillStyle = grad;
          this.weatherCardContext.fill();
        }
      }
    } catch (_e) {}
  }

  private startPhysicsLoop() {
    if (this.physicsTimer !== -1) {
      return;
    }
    this.physicsTimer = setInterval(() => {
      this.simTime += 0.02;
      const isWeatherRough = this.currentWeatherType === 'thunderstorm' || this.currentWeatherType === 'snow';
      const targetIntensity = (this.isTurbulent || this.isTestingTurbulence || isWeatherRough) ? 1.0 : 0.0;
      // 气动阻尼平滑过渡
      const lerpSpeed = (targetIntensity > this.currentTurbulenceIntensity) ? 0.06 : 0.035;
      this.currentTurbulenceIntensity += (targetIntensity - this.currentTurbulenceIntensity) * lerpSpeed;
      
      const intensity = this.currentTurbulenceIntensity;
      
      // 1. 常规万米平流层巡航飞行（极柔和舒缓的呼吸感）：
      // - 垂直呼吸沉浮：±1.8vp（约 4.5s 缓慢呼吸周期）
      const cruiseHeave = Math.sin(this.simTime * 1.4) * 1.8;
      // - 水平微滑移：±0.8vp 极平稳的迎风气流滑行
      const cruiseDrift = Math.cos(this.simTime * 0.9) * 0.8;
      // - 真实巡航微仰角：机头保持自然上扬 +1.0°，伴随 ±0.25° 的细腻呼吸微调
      const cruisePitch = 1.0 + Math.sin(this.simTime * 1.2) * 0.25;
      
      // 2. 真实气流与天气颠簸（高频紧致震颤，而非大幅度晃动）：
      // - 垂直高频轻颤：约 ±2.2vp 紧凑抖动
      const heaveWave = (
        Math.sin(this.simTime * 14.0) * 1.4 + 
        Math.sin(this.simTime * 24.0) * 0.8 + 
        (Math.random() - 0.5) * 0.6
      ) * intensity;
      
      // - 横向微颠簸
      const swayWave = (
        Math.cos(this.simTime * 10.0) * 1.0 + 
        (Math.random() - 0.5) * 0.5
      ) * intensity;
      
      // - 颠簸俯仰微震：约 ±0.8° 的高频紧致震动
      const pitchWave = (
        Math.sin(this.simTime * 16.0) * 0.8 + 
        Math.cos(this.simTime * 28.0) * 0.4
      ) * intensity;

      this.planeOffsetY = cruiseHeave + heaveWave;
      this.planeOffsetX = cruiseDrift + swayWave;
      this.planeRotation = cruisePitch + pitchWave;

      // 🌧️ 逐帧刷新卡片内微型雨雪气象粒子
      this.renderCardWeatherFrame();
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
    this.initCardWeatherParticles();
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
    let badge: FlightStatusBadgeInfo = { icon: '✓', text: '状态良好', color: '#10B981' };

    // ⛈️ 优先判定高空恶劣天气状态
    if (this.currentWeatherType === 'thunderstorm') {
      return { icon: '⛈️', text: '穿越雷雨区', color: '#334155' };
    } else if (this.currentWeatherType === 'snow') {
      return { icon: '❄️', text: '迎风降雪巡航', color: '#0284C7' };
    }

    if (!this.flightSession) {
      if (this.isTurbulent || this.isTestingTurbulence) {
        badge = { icon: '⚠️', text: '遭遇微气流', color: '#F59E0B' };
      }
      return badge;
    }

    const now = Date.now();
    const endTime = this.flightSession.startTimeMs + this.flightSession.durationMin * 60000;
    const remainingMs = endTime - now;
    const remainingMins = Math.ceil(remainingMs / 60000);
    const latestEvent = this.flightSession.events && this.flightSession.events.length > 0 ? this.flightSession.events[0] : null;

    if (remainingMs <= 0) {
      badge = { icon: '✨', text: '顺利降落', color: '#059669' };
    } else if (this.isTurbulent || this.isTestingTurbulence) {
      badge = { icon: '⚠️', text: '遭遇微气流', color: '#F59E0B' };
    } else if (latestEvent && latestEvent.type === 'deviation') {
      badge = { icon: '⚠️', text: '偏离航线', color: '#EF4444' };
    } else if (latestEvent && latestEvent.type === 'recovery' && (now - latestEvent.timestampMs < 45000)) {
      badge = { icon: '⚡', text: '航向修正', color: '#06B6D4' };
    } else if (remainingMins <= 5) {
      badge = { icon: '🛫', text: '准备进近', color: '#8B5CF6' };
    } else {
      badge = { icon: '✓', text: '状态良好', color: '#10B981' };
    }
    return badge;
  }

  buildTimelineData() {
    if (!this.flightSession) {
      // Fallback for preview / testing
      let previewList: TimelineItemData[] = [
        { id: '1', iconType: 'arrow_up', title: '预计降落', subtitle: '距离到达目的地还有 21 分钟', statusText: '预计 14:45', statusColor: '#10B981', lineStyle: 'end' },
        { id: '3', iconType: 'plane', title: '深度心流巡航', subtitle: '飞行高度 35,000 英尺', statusText: '专注中', statusColor: '#10B981', lineStyle: 'flown' },
        { id: '8', iconType: 'dot', title: '登机', subtitle: '设备锁定，航线开始', statusText: '14:00', statusColor: '#9CA3AF', lineStyle: 'flown' },
        { id: '9', iconType: 'start', title: '办理值机', subtitle: '选择目的地航线，完成登机牌确认', statusText: '13:58', statusColor: '#10B981', lineStyle: 'start' }
      ];
      this.timelineData = previewList;
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

    // 2. 最后 3 分钟内：插入“准备下降”
    if (remainingMins <= 3 && remainingMins > 0) {
      newList.push({
        id: 'descent',
        iconType: 'dot',
        title: '准备下降',
        subtitle: '收起小桌板，即将抵达目标',
        statusText: '',
        statusColor: '',
        lineStyle: 'future'
      });
    }

    // 3. 历史真实事件流 (保证起点必存且历史事件永不丢失)
    const rawEvents: FlightEvent[] = this.flightSession.events ? [...this.flightSession.events] : [];
    
    // 确保列表包含 "登机" 事件 (原 gate_departure)
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
    rawEvents.forEach((evt, idx) => {
      const isLatest = idx === 0;
      
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
        mappedTitle = '登机';
        icon = isLatest ? 'plane' : 'dot';
        color = '#9CA3AF';
        status = this.formatTime(evt.timestampMs);
      }
      
      newList.push({
        id: evt.id,
        iconType: icon,
        title: mappedTitle,
        subtitle: evt.note || '',
        statusText: status,
        statusColor: color,
        lineStyle: isLatest ? 'transition' : 'flown'
      });
    });

    // 4. 最底部航程真正起点：办理值机 (Check-in)
    const checkInTimeMs = this.flightSession.checkInTimeMs || 
      AppStorage.get<number>('lastCheckInTimeMs') || 
      (this.flightSession.startTimeMs - 60000);

    newList.push({
      id: 'check_in_origin',
      iconType: 'start',
      title: '办理值机',
      subtitle: '选择目的地航线，完成登机牌确认',
      statusText: this.formatTime(checkInTimeMs),
      statusColor: '#10B981',
      lineStyle: 'start'
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
            .backgroundColor('#E2E8F0')
            .borderRadius(2.5)
        }
        .width('100%')
        .height(18)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 8, bottom: 4 })

        // 头部标题区域
        Row() {
          Column({ space: 2 }) {
            Text("专注航行 Pro · 当前航段")
              .fontSize(11)
              .fontColor('#64748B')
              .fontWeight(FontWeight.Medium)
            Text("航行日志")
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
          }
          .alignItems(HorizontalAlign.Start)
          
          Blank()
          
          // 关闭按钮 (通用组件)
          CloseButton({
            circleColor: '#F1F5F9',
            iconColor: '#0F172A',
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
        .margin({ bottom: 12 })

        // 核心时间轴白底卡片
        Scroll() {
          Column() {
            // 卡片容器
            Column() {
              // 卡片头部天气氛围背景容器 (严格保持原本紧凑高度，绝不拉伸撑高)
              Stack({ alignContent: Alignment.TopStart }) {
                // 1. 中层天气动态雨雪 Canvas 粒子层 (绝对定位覆盖，绝不撑大父级容器)
                if (this.currentWeatherType !== 'clear') {
                  Canvas(this.weatherCardContext)
                    .width('100%')
                    .height('100%')
                    .position({ x: 0, y: 0 })
                    .backgroundColor(Color.Transparent)
                    .hitTestBehavior(HitTestMode.None)
                    .onAreaChange((_oldArea, newArea) => {
                      const w = Number(newArea.width);
                      const h = Number(newArea.height);
                      if (w > 0 && h > 0) {
                        this.cardCanvasWidth = w;
                        this.cardCanvasHeight = h;
                        this.initCardWeatherParticles();
                      }
                    })
                }

                // 2. 上层内容：标题、动态飞机、状态标签
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
                  
                  Text(this.getCardSubtitle())
                    .fontSize(13)
                    .fontColor('rgba(255,255,255,0.85)')
                    .margin({ top: 4, left: 16 })
                    
                  // 飞机形象展示
                  Image($r('app.media.b737_800_flat_3'))
                    .width('82%')
                    .aspectRatio(2.07)
                    .alignSelf(ItemAlign.Center)
                    .objectFit(ImageFit.Contain)
                    .margin({ top: 12, bottom: 16 })
                    .translate({ x: this.planeOffsetX, y: this.planeOffsetY })
                    .rotate({ angle: this.planeRotation })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .height(180)
              .linearGradient({
                direction: GradientDirection.Bottom,
                colors: this.getCardGradientColors()
              })
              .animation({ duration: 400, curve: Curve.EaseInOut })
              .borderRadius({ topLeft: 16, topRight: 16 })
              .clip(true)
              

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
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .padding({ left: 16, right: 16, top: 0, bottom: 48 })
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height(this.sheetHeight)
      .animation({ duration: 380, curve: Curve.FastOutSlowIn })
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 24, topRight: 24 })
      .shadow({ radius: 30, color: 'rgba(0,0,0,0.15)', offsetY: -10 })
      .onClick(() => {
        // 🛑 拦截抽屉内部点击，防止穿透到底层地图
      })
      .onTouch((event: TouchEvent) => {
        event.stopPropagation();
      })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Default)
    .onClick(() => {
      // 拦截根节点点击
    })
    .onTouch((event: TouchEvent) => {
      event.stopPropagation();
    })
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
