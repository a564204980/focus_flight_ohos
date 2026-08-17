import { vibrator } from '@kit.SensorServiceKit';

interface PresetTaskItem {
  id: string;
  icon: string;
  title: string;
  sub: string;
  color: string;
  bg: string;
  shadow: string;
}

/**
 * SeatSelectBoardingDialog.ets
 * 选座专属专注目标 & 类型挑选器 (Focus Type Selector Sheet)
 * 极致温馨可爱、解压沉浸的高品质专注目标选择面板
 */
@CustomDialog
export struct SeatSelectBoardingDialog {
  controller?: CustomDialogController;
  seatId: string = '1F';
  flightNo: string = 'CA933';
  originCode: string = 'CTU';
  destCode: string = 'CDG';
  durationMin: number = 15;
  onConfirmSeat?: (seatId: string, taskTitle: string, durationMin: number) => void;

  @State selectedTask: string = '深度编程';
  @State selectedTaskId: string = 'work';
  @State customTaskInput: string = '';
  @State isCustomInputActive: boolean = false;

  private presetTasks: Array<PresetTaskItem> = [
    { id: 'study', icon: '📚', title: '深度学习', sub: '研读 / 备考', color: '#F06553', bg: '#FFF5F3', shadow: 'rgba(240, 101, 83, 0.22)' },
    { id: 'work', icon: '💻', title: '深度编程', sub: '代码 / 架构', color: '#0EA5E9', bg: '#F0F9FF', shadow: 'rgba(14, 165, 233, 0.22)' },
    { id: 'write', icon: '✍️', title: '创作文档', sub: '撰写 / 灵感', color: '#8B5CF6', bg: '#F3E8FF', shadow: 'rgba(139, 92, 246, 0.22)' },
    { id: 'design', icon: '🎨', title: '视觉设计', sub: 'UI / 构思', color: '#EC4899', bg: '#FDF2F8', shadow: 'rgba(236, 72, 153, 0.22)' },
    { id: 'relax', icon: '🧘', title: '正念冥想', sub: '呼吸 / 放松', color: '#10B981', bg: '#ECFDF5', shadow: 'rgba(16, 185, 129, 0.22)' }
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

  // 获取当前选中的专注类型名称
  private getActiveTaskTitle(): string {
    if (this.isCustomInputActive) {
      return this.customTaskInput.trim() ? this.customTaskInput.trim() : '自定义专注';
    }
    return this.selectedTask;
  }

  // 获取当前选中的主题色
  private getActiveThemeColor(): string {
    if (this.isCustomInputActive) {
      return '#F59E0B';
    }
    const found = this.presetTasks.find(item => item.id === this.selectedTaskId);
    return found ? found.color : '#F06553';
  }

  build() {
    Column({ space: 16 }) {
      // 0. 顶部拖拽 Indicator 胶囊
      Row()
        .width(38)
        .height(4.5)
        .backgroundColor('#CBD5E1')
        .borderRadius(2.25)
        .margin({ top: 4, bottom: 2 })

      // 1. 顶部 Header：轻量化座位与航班 Pill 气泡
      Row() {
        Column({ space: 5 }) {
          Text('🎯 选择您的专注目标')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1E293B')

          // 座位与航程 Pill 标签组
          Row({ space: 6 }) {
            // 座位号 Tag
            Row({ space: 4 }) {
              Text('📍')
                .fontSize(10)
              Text(`座位 ${this.seatId}`)
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F06553')
              Text(this.seatId.endsWith('A') || this.seatId.endsWith('F') ? '· 靠窗观景' : '· 过道快捷')
                .fontSize(10)
                .fontColor('#64748B')
            }
            .padding({ left: 8, right: 9, top: 3, bottom: 3 })
            .backgroundColor('#FFF1F0')
            .border({ width: 1, color: '#FFD8D3', radius: 10 })
            .borderRadius(10)

            // 航班 Tag
            Row({ space: 4 }) {
              Text('✈️')
                .fontSize(10)
              Text(`${this.originCode} ➔ ${this.destCode}`)
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor('#64748B')
            }
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#F1F5F9')
            .borderRadius(10)
          }
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 圆形浅灰背景 ✕ 关闭按钮 ( focus-flight-ui-style 规范)
        Row() {
          Text('✕')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#64748B')
        }
        .width(30)
        .height(30)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F1F5F9')
        .borderRadius(15)
        .onClick(() => {
          if (this.controller) {
            this.controller.close();
          }
        })
      }
      .width('100%')

      Divider().color('#E2E8F0')

      // 2. 专注类型 2×3 高颜值软弹网格选择器
      Column({ space: 12 }) {
        Row() {
          Text('专注场景类型')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#64748B')

          Blank()

          Text(this.isCustomInputActive ? '✨ 自定义目标' : `已选择: ${this.selectedTask}`)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getActiveThemeColor())
        }
        .width('100%')

        // 2×3 精致场景大卡片 Flex Grid
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.presetTasks, (item: PresetTaskItem) => {
            Column({ space: 4 }) {
              Row() {
                Text(item.icon)
                  .fontSize(16)

                Blank()

                if (this.selectedTaskId === item.id && !this.isCustomInputActive) {
                  Row() {
                    Text('✓')
                      .fontSize(10)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#FFFFFF')
                  }
                  .width(16)
                  .height(16)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(item.color)
                  .borderRadius(8)
                }
              }
              .width('100%')

              Text(item.title)
                .fontSize(13)
                .fontWeight(this.selectedTaskId === item.id && !this.isCustomInputActive ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.selectedTaskId === item.id && !this.isCustomInputActive ? item.color : '#1E293B')

              Text(item.sub)
                .fontSize(10)
                .fontColor(this.selectedTaskId === item.id && !this.isCustomInputActive ? item.color : '#94A3B8')
            }
            .width('31.5%')
            .padding({ left: 12, right: 12, top: 12, bottom: 12 })
            .margin({ bottom: 10 })
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(this.selectedTaskId === item.id && !this.isCustomInputActive ? item.bg : '#FFFFFF')
            .border({
              width: this.selectedTaskId === item.id && !this.isCustomInputActive ? 2 : 1,
              color: this.selectedTaskId === item.id && !this.isCustomInputActive ? item.color : '#E2E8F0',
              radius: 16
            })
            .borderRadius(16)
            .shadow({
              radius: this.selectedTaskId === item.id && !this.isCustomInputActive ? 10 : 4,
              color: this.selectedTaskId === item.id && !this.isCustomInputActive ? item.shadow : 'rgba(0, 0, 0, 0.04)',
              offsetY: this.selectedTaskId === item.id && !this.isCustomInputActive ? 4 : 2
            })
            .scale({
              x: this.selectedTaskId === item.id && !this.isCustomInputActive ? 1.03 : 1.0,
              y: this.selectedTaskId === item.id && !this.isCustomInputActive ? 1.03 : 1.0
            })
            .animation({ duration: 220, curve: Curve.EaseOut })
            .onClick(() => {
              this.triggerHaptic();
              this.selectedTaskId = item.id;
              this.selectedTask = item.title;
              this.isCustomInputActive = false;
              this.customTaskInput = '';
            })
          })

          // 第 6 个卡片：自定义目标卡片 (琥珀金主题)
          Column({ space: 4 }) {
            Row() {
              Text('✨')
                .fontSize(16)

              Blank()

              if (this.isCustomInputActive) {
                Row() {
                  Text('✓')
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                }
                .width(16)
                .height(16)
                .justifyContent(FlexAlign.Center)
                .backgroundColor('#F59E0B')
                .borderRadius(8)
              }
            }
            .width('100%')

            Text('自定义')
              .fontSize(13)
              .fontWeight(this.isCustomInputActive ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.isCustomInputActive ? '#F59E0B' : '#1E293B')

            Text('自由输入目标')
              .fontSize(10)
              .fontColor(this.isCustomInputActive ? '#F59E0B' : '#94A3B8')
          }
          .width('31.5%')
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })
          .margin({ bottom: 10 })
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(this.isCustomInputActive ? '#FEF3C7' : '#FFFFFF')
          .border({
            width: this.isCustomInputActive ? 2 : 1,
            color: this.isCustomInputActive ? '#F59E0B' : '#E2E8F0',
            radius: 16
          })
          .borderRadius(16)
          .shadow({
            radius: this.isCustomInputActive ? 10 : 4,
            color: this.isCustomInputActive ? 'rgba(245, 158, 11, 0.22)' : 'rgba(0, 0, 0, 0.04)',
            offsetY: this.isCustomInputActive ? 4 : 2
          })
          .scale({
            x: this.isCustomInputActive ? 1.03 : 1.0,
            y: this.isCustomInputActive ? 1.03 : 1.0
          })
          .animation({ duration: 220, curve: Curve.EaseOut })
          .onClick(() => {
            this.triggerHaptic();
            this.isCustomInputActive = true;
          })
        }
        .width('100%')

        // 自定义目标输入框 (点击自定义时平滑展开)
        if (this.isCustomInputActive) {
          Row({ space: 8 }) {
            Text('✍️')
              .fontSize(15)
            TextInput({ placeholder: '请输入专属专注目标...', text: this.customTaskInput })
              .placeholderColor('#94A3B8')
              .fontColor('#1E293B')
              .fontSize(13)
              .backgroundColor('transparent')
              .height(42)
              .layoutWeight(1)
              .onChange((value: string) => {
                this.customTaskInput = value;
              })

            if (this.customTaskInput.length > 0) {
              Text('✕')
                .fontSize(12)
                .fontColor('#94A3B8')
                .onClick(() => {
                  this.customTaskInput = '';
                })
            }
          }
          .width('100%')
          .padding({ left: 14, right: 14 })
          .backgroundColor('#FFFFFF')
          .border({ width: 1.5, color: '#F59E0B', radius: 14 })
          .borderRadius(14)
          .shadow({ radius: 8, color: 'rgba(245, 158, 11, 0.15)', offsetY: 2 })
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -10 })).animation({ duration: 200, curve: Curve.EaseOut }))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      // 3. 专注起飞主 Action 按钮 (跟随所选专注类型动态更换文案)
      Row({ space: 8 }) {
        Text('🛫')
          .fontSize(18)
        Text(`开启【${this.getActiveTaskTitle()}】专注飞行`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height(52)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.getActiveThemeColor())
      .borderRadius(26)
      .shadow({ radius: 14, color: `${this.getActiveThemeColor()}50`, offsetY: 5 })
      .animation({ duration: 250, curve: Curve.FastOutSlowIn })
      .onClick(() => {
        this.triggerHaptic();
        const finalTask = this.getActiveTaskTitle();
        if (this.onConfirmSeat) {
          const actualDur = this.durationMin > 0 ? this.durationMin : 15;
          this.onConfirmSeat(this.seatId, finalTask, actualDur);
        }
        if (this.controller) {
          this.controller.close();
        }
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 20 })
    .backgroundColor('#FAF7F2')
    .borderRadius({ topLeft: 32, topRight: 32, bottomLeft: 0, bottomRight: 0 })
    .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.12)', offsetY: -6 })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}

