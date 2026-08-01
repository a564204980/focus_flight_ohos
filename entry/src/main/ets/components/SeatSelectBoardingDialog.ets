import { vibrator } from '@kit.SensorServiceKit';

interface PresetTaskItem {
  icon: string;
  title: string;
  sub: string;
}

/**
 * SeatSelectBoardingDialog.ets
 * 飞行员战术舱位登机仪表卡 (Cockpit Tactical Boarding Pass HUD Card)
 * 深度对标图 1-4 核心视觉基因：暗夜科技线框 + LED 状态指示 + 战术点火按键
 */
@CustomDialog
export struct SeatSelectBoardingDialog {
  controller?: CustomDialogController;
  seatId: string = '1F';
  flightNo: string = 'CA933';
  originCode: string = 'TFU';
  destCode: string = 'CDG';
  onConfirmSeat?: (seatId: string, taskTitle: string, durationMin: number) => void;

  @State selectedTask: string = '💻 深度编程';
  @State customTaskInput: string = '';
  @State isCustomInputActive: boolean = false;

  private presetTasks: Array<PresetTaskItem> = [
    { icon: '📖', title: '阅读研读', sub: '文档/研读书籍' },
    { icon: '💻', title: '深度编程', sub: '代码/逻辑重构' },
    { icon: '✍️', title: '写作创作', sub: '撰写/文档报告' },
    { icon: '🎨', title: '设计构思', sub: 'UI/视觉图构' },
    { icon: '🧘', title: '静心冥想', sub: '呼吸/放松归元' }
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
    Column({ space: 14 }) {
      // 0. 顶部拖拽 Indicator 胶囊
      Row()
        .width(38)
        .height(4)
        .backgroundColor('rgba(255, 255, 255, 0.25)')
        .borderRadius(2)
        .margin({ top: 4, bottom: 0 })

      // 1. 战术航线 Header (参考图 4 飞行卡)
      Row() {
        Column({ space: 3 }) {
          Row({ space: 8 }) {
            // 大航线
            Text(this.originCode)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F8FAFC')
            Text('✈️')
              .fontSize(14)
            Text(this.destCode)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F8FAFC')

            // 航班号 Tag
            Row() {
              Text(this.flightNo)
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0EA5E9')
            }
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor('rgba(14, 165, 233, 0.12)')
            .border({ width: 1, color: 'rgba(14, 165, 233, 0.3)', radius: 6 })
            .borderRadius(6)
          }

          Text(`远程宽体客机 · ${this.seatId.endsWith('A') || this.seatId.endsWith('F') ? '靠窗沉浸视角' : '过道快捷视角'}`)
            .fontSize(11)
            .fontColor('#94A3B8')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 右侧 SEAT 战术 Badge (图 3 风格)
        Row({ space: 6 }) {
          Column({ space: 1 }) {
            Text('SEAT')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor('#94A3B8')
              .letterSpacing(1)
            Text(this.seatId)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0EA5E9')
          }
          .alignItems(HorizontalAlign.End)

          // 28vp 极简关闭按钮 ✕
          Row() {
            Text('✕')
              .fontSize(13)
              .fontColor('#94A3B8')
          }
          .width(26)
          .height(26)
          .margin({ left: 8 })
          .justifyContent(FlexAlign.Center)
          .backgroundColor('rgba(255, 255, 255, 0.08)')
          .borderRadius(13)
          .onClick(() => {
            if (this.controller) {
              this.controller.close();
            }
          })
        }
      }
      .width('100%')

      Divider().color('#1E293B')

      // 2. 预飞专注清单 3×2 网格 (参考图 1 & 图 3 仪表数据卡)
      Column({ space: 10 }) {
        Row() {
          Text('PRE-FLIGHT CHECKLIST / 预飞专注清单')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#94A3B8')
            .letterSpacing(0.5)

          Blank()

          Row({ space: 4 }) {
            Text('●')
              .fontSize(9)
              .fontColor(this.isCustomInputActive || this.selectedTask ? '#0EA5E9' : '#64748B')
            Text(this.isCustomInputActive ? 'CUSTOM' : 'READY')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isCustomInputActive || this.selectedTask ? '#0EA5E9' : '#64748B')
          }
        }
        .width('100%')

        // 3×2 网格列表
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.presetTasks, (item: PresetTaskItem) => {
            Column({ space: 2 }) {
              Row() {
                Text(`${item.icon} ${item.title}`)
                  .fontSize(12)
                  .fontWeight(this.selectedTask === item.title && !this.isCustomInputActive ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.selectedTask === item.title && !this.isCustomInputActive ? '#0EA5E9' : '#F8FAFC')

                Blank()

                Text('●')
                  .fontSize(8)
                  .fontColor(this.selectedTask === item.title && !this.isCustomInputActive ? '#10B981' : 'rgba(255, 255, 255, 0.2)')
              }
              .width('100%')

              Text(item.sub)
                .fontSize(9)
                .fontColor(this.selectedTask === item.title && !this.isCustomInputActive ? 'rgba(14, 165, 233, 0.8)' : '#64748B')
            }
            .width('31.5%')
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .margin({ bottom: 8 })
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(this.selectedTask === item.title && !this.isCustomInputActive ? 'rgba(14, 165, 233, 0.12)' : '#0D1322')
            .border({
              width: 1,
              color: this.selectedTask === item.title && !this.isCustomInputActive ? '#0EA5E9' : '#1E293B',
              radius: 10
            })
            .borderRadius(10)
            .onClick(() => {
              this.triggerHaptic();
              this.selectedTask = item.title;
              this.isCustomInputActive = false;
              this.customTaskInput = '';
            })
          })

          // 第 6 个卡片：自定义选项
          Column({ space: 2 }) {
            Row() {
              Text('✨ 自定义')
                .fontSize(12)
                .fontWeight(this.isCustomInputActive ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.isCustomInputActive ? '#0EA5E9' : '#94A3B8')

              Blank()

              Text('●')
                .fontSize(8)
                .fontColor(this.isCustomInputActive ? '#10B981' : 'rgba(255, 255, 255, 0.2)')
            }
            .width('100%')

            Text('自由输入目标')
              .fontSize(9)
              .fontColor(this.isCustomInputActive ? 'rgba(14, 165, 233, 0.8)' : '#64748B')
          }
          .width('31.5%')
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          .margin({ bottom: 8 })
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(this.isCustomInputActive ? 'rgba(14, 165, 233, 0.12)' : '#0D1322')
          .border({
            width: 1,
            color: this.isCustomInputActive ? '#0EA5E9' : '#1E293B',
            radius: 10
          })
          .borderRadius(10)
          .onClick(() => {
            this.triggerHaptic();
            this.isCustomInputActive = true;
          })
        }
        .width('100%')

        // 自定义目标输入框 (点击自定义时展开)
        if (this.isCustomInputActive) {
          Row({ space: 8 }) {
            Text('✍️')
              .fontSize(13)
            TextInput({ placeholder: '输入专属专注目标...', text: this.customTaskInput })
              .placeholderColor('#64748B')
              .fontColor('#F8FAFC')
              .fontSize(12)
              .backgroundColor('transparent')
              .height(38)
              .layoutWeight(1)
              .onChange((value: string) => {
                this.customTaskInput = value;
              })
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
          .backgroundColor('#0D1322')
          .border({ width: 1, color: '#0EA5E9', radius: 10 })
          .borderRadius(10)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      // 3. 战术起飞点火主按钮 (对标图 1 & 图 4 底部控制按键)
      Row() {
        Row({ space: 8 }) {
          Text('🛫')
            .fontSize(16)
          Text('确认登机 · 启动专注巡航')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0EA5E9')
        }

        Blank()

        Row({ space: 4 }) {
          Text('●')
            .fontSize(9)
            .fontColor('#10B981')
          Text('READY')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#10B981')
            .letterSpacing(1)
        }
      }
      .width('100%')
      .height(50)
      .padding({ left: 18, right: 18 })
      .backgroundColor('#0D1322')
      .border({ width: 1.5, color: '#0EA5E9', radius: 16 })
      .borderRadius(16)
      .shadow({ radius: 16, color: 'rgba(14, 165, 233, 0.25)', offsetY: 4 })
      .onClick(() => {
        this.triggerHaptic();
        const finalTask = (this.isCustomInputActive && this.customTaskInput.trim())
          ? this.customTaskInput.trim()
          : this.selectedTask;
        if (this.onConfirmSeat) {
          this.onConfirmSeat(this.seatId, finalTask, 25);
        }
        if (this.controller) {
          this.controller.close();
        }
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 32 })
    .backgroundColor('#0A0F1D')
    .border({ width: { top: 1.5 }, color: '#1E293B' })
    .borderRadius({ topLeft: 24, topRight: 24, bottomLeft: 0, bottomRight: 0 })
    .backdropBlur(30)
    .shadow({ radius: 36, color: 'rgba(0, 0, 0, 0.95)', offsetY: -10 })
  }
}
