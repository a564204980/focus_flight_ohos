import { vibrator } from '@kit.SensorServiceKit';
import { FocusTagItem, PRESET_FOCUS_TAGS } from '../models/FocusTagModel';

/**
 * FocusTagSelectDialog.ets
 * 极致温馨纯粹、轻量简约的 6 宫格专注场景挑选器 (KISS 原则)
 */
@CustomDialog
export struct FocusTagSelectDialog {
  controller?: CustomDialogController;
  @Prop currentTagId: string = 'study';
  onTagSelected?: (tag: FocusTagItem) => void;

  @State selectedTaskId: string = 'study';
  @State customTaskInput: string = '';
  @State isCustomInputActive: boolean = false;

  private presetTasks: Array<FocusTagItem> = PRESET_FOCUS_TAGS.slice(0, 5);

  aboutToAppear(): void {
    if (this.currentTagId && this.currentTagId.startsWith('custom')) {
      this.isCustomInputActive = true;
      const cachedTitle = AppStorage.get<string>('currentFocusTagTitle') || '';
      this.customTaskInput = cachedTitle;
      this.selectedTaskId = 'custom';
    } else {
      this.selectedTaskId = this.currentTagId || 'study';
      this.isCustomInputActive = false;
    }
  }

  private triggerHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 20
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      // ignore
    }
  }

  private confirmSelect(tag: FocusTagItem): void {
    this.triggerHaptic();
    AppStorage.setOrCreate('currentFocusTagId', tag.id);
    AppStorage.setOrCreate('currentFocusTagTitle', tag.title);
    AppStorage.setOrCreate('currentFocusTagIcon', tag.icon);
    AppStorage.setOrCreate('currentFocusTagColor', tag.color);
    AppStorage.setOrCreate('currentFocusTagBg', tag.bg);

    if (this.onTagSelected) {
      this.onTagSelected(tag);
    }
    if (this.controller) {
      this.controller.close();
    }
  }

  build() {
    Column({ space: 14 }) {
      // 0. 顶部拖拽 Indicator 胶囊
      Row()
        .width(36)
        .height(4)
        .backgroundColor('#CBD5E1')
        .borderRadius(2)
        .margin({ top: 4, bottom: 2 })

      // 1. 顶部 Header
      Row() {
        Text('🎯 选择专注目标')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')

        Blank()

        // ✕ 关闭按钮
        Row() {
          Text('✕')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#64748B')
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F1F5F9')
        .borderRadius(14)
        .onClick(() => {
          if (this.controller) {
            this.controller.close();
          }
        })
      }
      .width('100%')

      Divider().color('#F1F5F9').strokeWidth(1)

      // 2. 经典 2×3 软弹网格选择器
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.presetTasks, (item: FocusTagItem) => {
          Column({ space: 4 }) {
            Row() {
              Text(item.icon)
                .fontSize(17)

              Blank()

              if (this.selectedTaskId === item.id && !this.isCustomInputActive) {
                Row() {
                  Text('✓')
                    .fontSize(9)
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
              .margin({ top: 2 })

            Text(item.sub)
              .fontSize(10)
              .fontColor(this.selectedTaskId === item.id && !this.isCustomInputActive ? item.color : '#94A3B8')
          }
          .width('31.5%')
          .padding(10)
          .margin({ bottom: 10 })
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(this.selectedTaskId === item.id && !this.isCustomInputActive ? item.bg : '#FFFFFF')
          .border({
            width: this.selectedTaskId === item.id && !this.isCustomInputActive ? 1.8 : 1,
            color: this.selectedTaskId === item.id && !this.isCustomInputActive ? item.color : '#E2E8F0',
            radius: 14
          })
          .borderRadius(14)
          .shadow({
            radius: this.selectedTaskId === item.id && !this.isCustomInputActive ? 8 : 2,
            color: this.selectedTaskId === item.id && !this.isCustomInputActive ? item.shadow : 'rgba(0, 0, 0, 0.02)',
            offsetY: 2
          })
          .scale({
            x: this.selectedTaskId === item.id && !this.isCustomInputActive ? 1.02 : 1.0,
            y: this.selectedTaskId === item.id && !this.isCustomInputActive ? 1.02 : 1.0
          })
          .onClick(() => {
            this.selectedTaskId = item.id;
            this.isCustomInputActive = false;
            this.confirmSelect(item);
          })
        }, (item: FocusTagItem) => item.id)

        // 第 6 个卡片：✨ 自定义目标 (琥珀金)
        Column({ space: 4 }) {
          Row() {
            Text('✨')
              .fontSize(17)

            Blank()

            if (this.isCustomInputActive) {
              Row() {
                Text('✓')
                  .fontSize(9)
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
            .fontColor(this.isCustomInputActive ? '#D97706' : '#1E293B')
            .margin({ top: 2 })

          Text('专属目标')
            .fontSize(10)
            .fontColor(this.isCustomInputActive ? '#D97706' : '#94A3B8')
        }
        .width('31.5%')
        .padding(10)
        .margin({ bottom: 10 })
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(this.isCustomInputActive ? '#FFFBEB' : '#FFFFFF')
        .border({
          width: this.isCustomInputActive ? 1.8 : 1,
          color: this.isCustomInputActive ? '#F59E0B' : '#E2E8F0',
          radius: 14
        })
        .borderRadius(14)
        .shadow({
          radius: this.isCustomInputActive ? 8 : 2,
          color: this.isCustomInputActive ? 'rgba(245, 158, 11, 0.22)' : 'rgba(0, 0, 0, 0.02)',
          offsetY: 2
        })
        .scale({
          x: this.isCustomInputActive ? 1.02 : 1.0,
          y: this.isCustomInputActive ? 1.02 : 1.0
        })
        .onClick(() => {
          this.triggerHaptic();
          this.isCustomInputActive = true;
          this.selectedTaskId = 'custom';
        })
      }
      .width('100%')

      // 3. 自定义输入行 (仅在选中自定义时展开)
      if (this.isCustomInputActive) {
        Row({ space: 8 }) {
          TextInput({ placeholder: '输入目标名称 (如: 考研背单词)', text: this.customTaskInput })
            .placeholderColor('#94A3B8')
            .fontSize(13)
            .height(40)
            .layoutWeight(1)
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#F59E0B', radius: 12 })
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .onChange((val: string) => {
              this.customTaskInput = val;
            })

          Button('确定')
            .height(40)
            .padding({ left: 16, right: 16 })
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#F59E0B')
            .borderRadius(12)
            .onClick(() => {
              const name = this.customTaskInput.trim() || '自定义专注';
              const customTag: FocusTagItem = {
                id: 'custom_' + Date.now(),
                icon: '✨',
                title: name,
                sub: '专属目标',
                color: '#F59E0B',
                bg: '#FFFBEB',
                shadow: 'rgba(245, 158, 11, 0.22)',
                isCustom: true
              };
              this.confirmSelect(customTag);
            })
        }
        .width('100%')
        .margin({ top: 2 })
      }
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 10, bottom: 24 })
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 24, topRight: 24 })
  }
}
