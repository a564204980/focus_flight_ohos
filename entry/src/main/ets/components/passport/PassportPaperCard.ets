import { FlightStatsSummary, HistoricalRouteSegment } from '../../database/FlightRecordRepository';

@Component
export struct PassportPaperCard {
  @Prop @Watch('onBlacklightChange') isBlacklight: boolean = false;
  @Prop stats: FlightStatsSummary | null = null;
  @Prop timeTabLabel: string = '总记录';
  @Prop @Watch('onRouteChange') routes: HistoricalRouteSegment[] = [];
  @StorageProp('initialIssueAirportName') initialIssueAirportName: string = '成都机场 (CTU)';

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private canvasWidth: number = 320;
  private canvasHeight: number = 190;

  private onBlacklightChange(): void {
    this.redrawCanvas();
  }

  private onRouteChange(): void {
    this.redrawCanvas();
  }

  // 坐标投影算法 (与 520x260 世界地图 SVG 像素级对齐)
  private project(lon: number, lat: number, width: number, height: number): number[] {
    const padX = 10 * (width / 520);
    const padYTop = 16 * (height / 260);
    const padYBottom = 12 * (height / 260);
    const minLon = -175;
    const maxLon = 185;
    const minLat = -56;
    const maxLat = 78;
    const clampedLon = Math.max(minLon, Math.min(maxLon, lon));
    const clampedLat = Math.max(minLat, Math.min(maxLat, lat));
    const x = padX + ((clampedLon - minLon) / (maxLon - minLon)) * (width - padX * 2);
    const y = padYTop + ((maxLat - clampedLat) / (maxLat - minLat)) * (height - padYTop - padYBottom);
    return [x, y];
  }

  // 动态重绘 Canvas 航线与航点 (日光复古暖金 vs 紫外极光电光绿)
  private redrawCanvas(): void {
    if (!this.context) return;
    const ctx = this.context;
    ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight);

    const isBlack = this.isBlacklight;

    // 1. 方案 B: 航线去重与执飞频次聚合
    const mergedRoutesMap = new Map<string, number[]>();
    const rawAirports: number[][] = [];

    if (this.routes && this.routes.length > 0) {
      for (let i = 0; i < this.routes.length; i++) {
        const seg = this.routes[i];
        const pt1 = this.project(seg.originLon, seg.originLat, this.canvasWidth, this.canvasHeight);
        const pt2 = this.project(seg.destLon, seg.destLat, this.canvasWidth, this.canvasHeight);
        const x1 = pt1[0];
        const y1 = pt1[1];
        const x2 = pt2[0];
        const y2 = pt2[1];

        rawAirports.push([x1, y1]);
        rawAirports.push([x2, y2]);

        const key = seg.originCode < seg.destCode
          ? seg.originCode + '_' + seg.destCode
          : seg.destCode + '_' + seg.originCode;

        const count = seg.flightCount > 0 ? seg.flightCount : 1;

        if (mergedRoutesMap.has(key)) {
          const existing = mergedRoutesMap.get(key);
          if (existing) {
            existing[4] = existing[4] + count;
          }
        } else {
          mergedRoutesMap.set(key, [x1, y1, x2, y2, count, seg.lastFlightTime]);
        }
      }
    } else {
      const ptCtu = this.project(104.06, 30.67, this.canvasWidth, this.canvasHeight);
      const ptSha = this.project(121.47, 31.23, this.canvasWidth, this.canvasHeight);
      rawAirports.push(ptCtu);
      rawAirports.push(ptSha);
      mergedRoutesMap.set('CTU_SHA', [ptCtu[0], ptCtu[1], ptSha[0], ptSha[1], 1, 0]);
    }

    // 2. 绘制大圆弧航线 (日光纸质琥珀暖金 vs 紫外极光电光绿)
    mergedRoutesMap.forEach((entry: number[]) => {
      const x1 = entry[0];
      const y1 = entry[1];
      const x2 = entry[2];
      const y2 = entry[3];
      const count = entry[4];

      const midX = (x1 + x2) / 2;
      const arcOffset = Math.min(30, Math.max(7, Math.abs(x1 - x2) * 0.13));
      const midY = (y1 + y2) / 2 - arcOffset;

      const isFrequent = count >= 3;

      if (isBlack) {
        // 紫外荧光验真模式 (图 2 原版深紫/靛蓝航线)
        if (isFrequent) {
          ctx.beginPath();
          ctx.moveTo(x1, y1);
          ctx.quadraticCurveTo(midX, midY, x2, y2);
          ctx.strokeStyle = 'rgba(192, 132, 252, 0.35)';
          ctx.lineWidth = 3.2;
          ctx.lineCap = 'round';
          ctx.stroke();

          ctx.beginPath();
          ctx.moveTo(x1, y1);
          ctx.quadraticCurveTo(midX, midY, x2, y2);
          ctx.strokeStyle = '#4C1D95';
          ctx.lineWidth = 1.5;
          ctx.stroke();
        } else {
          ctx.beginPath();
          ctx.moveTo(x1, y1);
          ctx.quadraticCurveTo(midX, midY, x2, y2);
          ctx.strokeStyle = 'rgba(76, 29, 149, 0.85)';
          ctx.lineWidth = 1.0;
          ctx.lineCap = 'round';
          ctx.stroke();
        }
      } else {
        // 日光纸质模式：经典琥珀暖金弧线
        if (isFrequent) {
          ctx.beginPath();
          ctx.moveTo(x1, y1);
          ctx.quadraticCurveTo(midX, midY, x2, y2);
          ctx.strokeStyle = 'rgba(217, 119, 6, 0.25)';
          ctx.lineWidth = 3.0;
          ctx.lineCap = 'round';
          ctx.stroke();

          ctx.beginPath();
          ctx.moveTo(x1, y1);
          ctx.quadraticCurveTo(midX, midY, x2, y2);
          ctx.strokeStyle = '#B45309';
          ctx.lineWidth = 1.4;
          ctx.stroke();
        } else {
          ctx.beginPath();
          ctx.moveTo(x1, y1);
          ctx.quadraticCurveTo(midX, midY, x2, y2);
          ctx.strokeStyle = 'rgba(180, 83, 9, 0.7)';
          ctx.lineWidth = 0.9;
          ctx.lineCap = 'round';
          ctx.stroke();
        }
      }
    });

    // 3. 方案 C: 航点精细化与邻近航点聚合
    const clusteredNodes: number[][] = [];
    const clusterDistSq = 8.5 * 8.5;

    for (let i = 0; i < rawAirports.length; i++) {
      const pt = rawAirports[i];
      const px = pt[0];
      const py = pt[1];
      let merged = false;

      for (let j = 0; j < clusteredNodes.length; j++) {
        const cNode = clusteredNodes[j];
        const cx = cNode[0];
        const cy = cNode[1];
        const dx = px - cx;
        const dy = py - cy;
        if (dx * dx + dy * dy <= clusterDistSq) {
          cNode[2] = cNode[2] + 1;
          merged = true;
          break;
        }
      }

      if (!merged) {
        clusteredNodes.push([px, py, 1]);
      }
    }

    // 4. 绘制航点 (图 2 紫外验真紫晶航点 vs 日光红心暖金光环)
    for (let k = 0; k < clusteredNodes.length; k++) {
      const node = clusteredNodes[k];
      const x = node[0];
      const y = node[1];
      const isHub = node[2] > 2;

      // 外光环
      ctx.beginPath();
      ctx.arc(x, y, isHub ? (isBlack ? 4.6 : 4.2) : (isBlack ? 2.8 : 2.6), 0, Math.PI * 2);
      ctx.fillStyle = isBlack
        ? (isHub ? 'rgba(192, 132, 252, 0.5)' : 'rgba(216, 180, 254, 0.4)')
        : (isHub ? 'rgba(251, 191, 36, 0.45)' : 'rgba(253, 230, 138, 0.45)');
      ctx.fill();

      // 内实心圆点 (图 2 深紫圆心 + 纯白描边)
      ctx.beginPath();
      ctx.arc(x, y, isHub ? (isBlack ? 2.2 : 2.1) : (isBlack ? 1.5 : 1.4), 0, Math.PI * 2);
      ctx.fillStyle = isBlack ? '#4C1D95' : '#DC2626';
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 0.7;
      ctx.fill();
      ctx.stroke();
    }
  }

  // 格式化专注时长 (纯中文)
  private formatDuration(minutes: number): string {
    const days = Math.floor(minutes / (24 * 60));
    const hours = Math.floor((minutes % (24 * 60)) / 60);
    if (days > 0) {
      return days + '天' + (hours > 0 ? ' ' + hours + '小时' : '');
    }
    if (hours > 0) {
      const remainMin = minutes % 60;
      return hours + '小时' + (remainMin > 0 ? ' ' + remainMin + '分' : '');
    }
    return Math.max(1, minutes) + '分钟';
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 卡片主体容器 (320 × 490, 20vp 大圆角)
      Column() {
        // ==================== 1. 上半部分: 全幅世界地图 (高 190vp) ====================
        Stack({ alignContent: Alignment.TopStart }) {
          // 1.1 复古纸质雕刻底图 / 极光雕刻底图
          Image(this.isBlacklight
            ? $r('app.media.bg_passport_map_blacklight')
            : $r('app.media.bg_passport_map_daylight'))
            .width('100%')
            .height(190)
            .objectFit(ImageFit.Fill)

          // 1.2 动态航迹 Canvas 层
          Canvas(this.context)
            .width('100%')
            .height(190)
            .onReady(() => {
              this.redrawCanvas();
            })
            .onAreaChange((oldArea: Area, newArea: Area) => {
              this.canvasWidth = Number(newArea.width);
              this.canvasHeight = Number(newArea.height);
              this.redrawCanvas();
            })
        }
        .width('100%')
        .height(190)
        .clip(true)

        // ==================== 2. 下半部分: 100% 还原图 1 经典排版 ====================
        Column({ space: 8 }) {
          // 2.1 国旗展示栏 (左侧矩形国旗) + 右侧时间筛选胶囊标签
          Row() {
            Row({ space: 5 }) {
              Text('🇨🇳').fontSize(13)
              Text('🇯🇵').fontSize(13)
              Text('🇸🇬').fontSize(13)
              Text('🇦🇪').fontSize(13)
              Text('🇬🇧').fontSize(13)
              Text('🇫🇷').fontSize(13)
              Text('🇩🇪').fontSize(13)
              Text('🇺🇸').fontSize(13)
              Text('🇦🇺').fontSize(13)
              Text('🇨🇦').fontSize(13)
            }

            Blank()

            // 右侧时间筛选胶囊 (如 "总记录")
            Text(this.timeTabLabel || '总记录')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isBlacklight ? '#E0E7FF' : '#78350F')
              .padding({ left: 10, right: 10, top: 3.5, bottom: 3.5 })
              .backgroundColor(this.isBlacklight ? 'rgba(99, 102, 241, 0.25)' : '#F5EBE1')
              .borderRadius(10)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10 })

          // 2.2 护照主副标题与复古防伪微章印章
          Row() {
            Column({ space: 2 }) {
              Text('我的专注航行护照')
                .fontSize(16)
                .fontWeight(FontWeight.Bolder)
                .fontColor(this.isBlacklight ? '#1E1B4B' : '#1E3A8A')
                .letterSpacing(0.4)

              Row({ space: 4 }) {
                Text('🪪')
                  .fontSize(10)
                Text('官方护照 · 专注航行 Pro')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.isBlacklight ? '#4338CA' : '#64748B')
                  .letterSpacing(0.4)
              }
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })

          // 2.3 核心大数字与签发元数据
          Row() {
            // 左侧: 44vp 超大执飞数字
            Column({ space: 2 }) {
              Text(this.stats ? this.stats.totalFlights.toString() : '148')
                .fontSize(44)
                .fontWeight(FontWeight.Bolder)
                .fontColor(this.isBlacklight ? '#1E1B4B' : '#111827')
                .lineHeight(46)

              Text('次执飞 · 专注航班')
                .fontSize(13.5)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isBlacklight ? '#312E81' : '#374151')
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            // 右侧: 四行紧凑签发元数据 (左灰右黑/金，严格左对齐)
            Column({ space: 3.5 }) {
              this.buildMetaRow('认证机构', '专注航行 Pro', false)
              this.buildMetaRow('签发地点', this.initialIssueAirportName || '成都机场 (CTU)', false)
              this.buildMetaRow('签发日期', '2026年8月24日', false)
              this.buildMetaRow('机长资质', '2026 终身资深机长', true)
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })

          // 2.4 横向分割细线
          Divider()
            .color(this.isBlacklight ? 'rgba(67, 56, 202, 0.2)' : '#E5E7EB')
            .strokeWidth(0.8)
            .margin({ left: 16, right: 16, top: 2, bottom: 2 })

          // 2.5 底部 4 栏紧凑数据网格 (总里程、专注时长、探索城市、专注模式)
          Row() {
            this.buildStatColumn('总里程', (this.stats ? this.stats.totalDistanceKm.toLocaleString() : '338,426') + ' km')
            this.buildStatColumn('专注时长', this.stats ? this.formatDuration(this.stats.totalMinutes) : '4天')
            this.buildStatColumn('探索城市', (this.stats ? this.stats.uniqueDestinationsCount.toString() : '30') + ' 座')
            this.buildStatColumn('专注模式', '深度长航')
          }
          .width('100%')
          .padding({ left: 16, right: 16 })

          // 2.6 底部 MRZ 航空机读码区 (等宽代码撑满宽度，与上方分割线严格两端对齐)
          Column({ space: 2.5 }) {
            Text('ALLTIME<<FOCUS<FLIGHT<PRO<<FLOW2026M260824<<<<<<<<<<<<<<<')
              .fontFamily('monospace')
              .fontSize(7.5)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isBlacklight ? '#312E81' : '#374151')
              .letterSpacing(0.8)
              .maxLines(1)
              .textAlign(TextAlign.Center)
              .width('100%')

            Text('ISSUED24AUG<<' + this.getAirportCode() + '<<<<<<<<148F5819M<<<<<<<<<<<<<<<<FOCUS<PRO')
              .fontFamily('monospace')
              .fontSize(7.5)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isBlacklight ? '#4338CA' : '#4B5563')
              .letterSpacing(0.8)
              .maxLines(1)
              .textAlign(TextAlign.Center)
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ left: 16, right: 16, top: 4, bottom: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width(320)
      .height(490)
      .borderRadius(20)
      .linearGradient({
        angle: 180,
        colors: this.isBlacklight
          ? [['#C2D5F8', 0.0], ['#A4BAEB', 0.45], ['#9BA8E7', 1.0]]
          : [['#EEF7F4', 0.0], ['#F7FBFA', 0.35], ['#FFFFFF', 0.60], ['#FFFFFF', 1.0]]
      })
      .border({
        width: 1,
        color: this.isBlacklight ? 'rgba(139, 92, 246, 0.35)' : 'rgba(0, 0, 0, 0.06)'
      })
      .clip(true)
      .shadow({
        radius: 24,
        color: this.isBlacklight ? 'rgba(99, 102, 241, 0.35)' : 'rgba(10, 28, 66, 0.14)',
        offsetY: 8
      })
    }
    .width(320)
    .height(490)
  }

  // 辅助构建: 签发元数据行
  @Builder
  private buildMetaRow(label: string, val: string, isGold: boolean) {
    Row({ space: 6 }) {
      Text(label)
        .fontSize(9.5)
        .fontColor(this.isBlacklight ? '#475569' : '#6B7280')

      Text(val)
        .fontSize(9.5)
        .fontWeight(FontWeight.Bold)
        .fontColor(isGold
          ? (this.isBlacklight ? '#6D28D9' : '#D97706')
          : (this.isBlacklight ? '#1E1B4B' : '#1F2937'))
    }
  }

  // 辅助构建: 底部 4 栏数据列
  @Builder
  private buildStatColumn(title: string, val: string) {
    Column({ space: 2.5 }) {
      Text(title)
        .fontSize(9)
        .fontColor(this.isBlacklight ? '#475569' : '#6B7280')

      Text(val)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isBlacklight ? '#1E1B4B' : '#111827')
        .maxLines(1)
    }
    .layoutWeight(title === '总里程' ? 1.25 : 1.0)
    .alignItems(HorizontalAlign.Start)
  }

  // 提取三字码
  private getAirportCode(): string {
    const name = this.initialIssueAirportName || 'CTU';
    const match = name.match(/\(([A-Z]{3})\)/);
    if (match && match[1]) {
      return match[1];
    }
    return 'CTU';
  }
}
