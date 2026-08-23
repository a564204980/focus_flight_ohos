import { notificationManager } from '@kit.NotificationKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';

const DOMAIN = 0x0000;
const TAG = 'LiveViewManager';

export interface LiveViewSessionInfo {
  flightNo: string;
  originCode: string;
  destCode: string;
  destCity: string;
  taskTitle: string;
  totalDurationMin: number;
}

/**
 * 🛫 鸿蒙实况窗（Live View）统一管理服务
 * 负责管理状态栏胶囊态（Capsule）、锁屏与下拉通知中心卡片态（Card）全生命周期
 */
export class LiveViewManager {
  private static readonly NOTIFICATION_ID: number = 8848;
  private static isLiveViewActive: boolean = false;
  public static isAppForeground: boolean = true;
  private static lastPushTime: number = 0;
  private static lastPushMins: number = -1;
  private static currentSession: LiveViewSessionInfo | null = null;
  private static isSystemLiveViewFailed: boolean = false;
  private static cachedWantAgent?: WantAgent;

  // 最新飞行状态快照
  private static lastRemainingSeconds: number = 0;
  private static lastDistanceRemainingKm: number = 0;
  private static lastProgressRatio: number = 0;

  /**
   * 切换应用前后台状态
   * 前台：不弹任何横幅干扰视觉
   * 后台：无缝激活锁屏与通知中心实况卡片
   */
  public static setAppForeground(foreground: boolean): void {
    LiveViewManager.isAppForeground = foreground;
    hilog.info(DOMAIN, TAG, 'setAppForeground: %{public}s', foreground ? 'true' : 'false');
    if (!foreground && LiveViewManager.isLiveViewActive && LiveViewManager.currentSession) {
      // 切后台时立即向系统同步一次卡片状态
      LiveViewManager.pushNotificationToSystem();
    }
  }

  /**
   * 获取点击实况窗直接回到 Focus Flight 舱内的 WantAgent
   */
  private static async getClickWantAgent(): Promise<WantAgent | undefined> {
    if (LiveViewManager.cachedWantAgent) {
      return LiveViewManager.cachedWantAgent;
    }
    try {
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: 'com.example.focus_flight_ohos',
            abilityName: 'EntryAbility'
          }
        ],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      LiveViewManager.cachedWantAgent = await wantAgent.getWantAgent(wantAgentInfo);
      return LiveViewManager.cachedWantAgent;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'getClickWantAgent error: %{public}s', JSON.stringify(e));
      return undefined;
    }
  }

  /**
   * 检查并请求系统通知与实况窗权限
   */
  public static async requestNotificationPermission(context?: common.UIAbilityContext): Promise<boolean> {
    try {
      const enabled = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        const ctx = context || AppStorage.get<common.UIAbilityContext>('abilityContext');
        if (ctx) {
          await notificationManager.requestEnableNotification(ctx);
          const afterCheck = await notificationManager.isNotificationEnabled();
          return afterCheck;
        }
      }
      return enabled;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'requestNotificationPermission error: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  /**
   * 初始化 Notification Slots
   */
  private static async initSlots(): Promise<void> {
    try {
      await notificationManager.addSlot(notificationManager.SlotType.LIVE_VIEW);
    } catch (e) { }
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SERVICE_INFORMATION);
    } catch (e) { }
  }

  /**
   * ✈️ 航班起飞：创建实况会话
   */
  public static async startLiveView(session: LiveViewSessionInfo, context?: common.UIAbilityContext): Promise<void> {
    try {
      LiveViewManager.currentSession = session;
      LiveViewManager.isLiveViewActive = true;
      LiveViewManager.isSystemLiveViewFailed = false;
      LiveViewManager.lastPushTime = Date.now();
      LiveViewManager.lastPushMins = session.totalDurationMin;
      LiveViewManager.lastRemainingSeconds = session.totalDurationMin * 60;
      LiveViewManager.lastDistanceRemainingKm = 0;
      LiveViewManager.lastProgressRatio = 0;

      await LiveViewManager.initSlots();
      await LiveViewManager.requestNotificationPermission(context);

      // 🌟 核心体验优化：若用户当前就在应用内（前台），绝对不弹任何横幅遮挡跑道！
      if (!LiveViewManager.isAppForeground) {
        await LiveViewManager.pushNotificationToSystem();
      }
      hilog.info(DOMAIN, TAG, 'LiveView session started');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'startLiveView error: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * ⏱️ 巡航中进度推流更新
   */
  public static async updateLiveView(remainingSeconds: number, distanceRemainingKm: number, progressRatio: number): Promise<void> {
    if (!LiveViewManager.isLiveViewActive || !LiveViewManager.currentSession) {
      return;
    }

    LiveViewManager.lastRemainingSeconds = remainingSeconds;
    LiveViewManager.lastDistanceRemainingKm = distanceRemainingKm;
    LiveViewManager.lastProgressRatio = progressRatio;

    // 🌟 用户在前台应用内时，零弹窗零通知干扰，专注于机舱与地图
    if (LiveViewManager.isAppForeground) {
      return;
    }

    const mins = Math.floor(remainingSeconds / 60);
    const now = Date.now();
    // 5秒节流
    if (mins === LiveViewManager.lastPushMins && (now - LiveViewManager.lastPushTime < 5000)) {
      return;
    }

    LiveViewManager.lastPushMins = mins;
    LiveViewManager.lastPushTime = now;

    await LiveViewManager.pushNotificationToSystem();
  }

  /**
   * 实际向系统底层推流卡片数据
   */
  private static async pushNotificationToSystem(): Promise<void> {
    if (!LiveViewManager.currentSession) {
      return;
    }

    const session = LiveViewManager.currentSession;
    const mins = Math.floor(LiveViewManager.lastRemainingSeconds / 60);
    const secs = LiveViewManager.lastRemainingSeconds % 60;
    const capsuleText = `${mins}:${secs < 10 ? '0' + secs : secs}`;
    const percent = Math.min(100, Math.max(0, Math.round(LiveViewManager.lastProgressRatio * 100)));
    const titleStr = `✈️ ${session.originCode} ➔ ${session.destCode} · ${session.taskTitle}`;
    const detailStr = `已飞行 ${percent}% · 剩余 ${capsuleText} · 距 ${session.destCity} ${LiveViewManager.lastDistanceRemainingKm}KM`;

    try {
      const agent = await LiveViewManager.getClickWantAgent();
      if (LiveViewManager.isSystemLiveViewFailed) {
        LiveViewManager.fallbackPublishBasic(titleStr, detailStr);
        return;
      }

      const liveViewContent: notificationManager.NotificationSystemLiveViewContent = {
        title: titleStr,
        text: detailStr,
        typeCode: 3,
        capsule: {
          title: capsuleText,
          backgroundColor: '#4F46E5'
        },
        progress: {
          maxValue: session.totalDurationMin * 60,
          currentValue: Math.round(LiveViewManager.lastProgressRatio * session.totalDurationMin * 60),
          isPercentage: false
        },
        time: {
          initialTime: Date.now(),
          isCountDown: true,
          isPaused: false
        }
      };

      const request: notificationManager.NotificationRequest = {
        id: LiveViewManager.NOTIFICATION_ID,
        notificationSlotType: notificationManager.SlotType.LIVE_VIEW,
        isOngoing: true,
        isAlertOnce: true,
        wantAgent: agent,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
          systemLiveView: liveViewContent
        }
      };

      await notificationManager.publish(request);
    } catch (e) {
      LiveViewManager.isSystemLiveViewFailed = true;
      LiveViewManager.fallbackPublishBasic(titleStr, detailStr);
    }
  }

  /**
   * ⏸️ 航线暂停状态
   */
  public static async pauseLiveView(): Promise<void> {
    if (!LiveViewManager.isLiveViewActive || !LiveViewManager.currentSession) {
      return;
    }
    const session = LiveViewManager.currentSession;
    const titleStr = `⏸️ 航线已暂停 · ${session.taskTitle}`;
    const detailStr = '飞机进入高空等待航线，随时可恢复巡航';

    if (!LiveViewManager.isAppForeground) {
      LiveViewManager.fallbackPublishBasic(titleStr, detailStr);
    }
  }

  /**
   * 🛬 降落完成 / 结束实况窗
   */
  public static async stopLiveView(isCompleted: boolean = true, totalFocusMinutes: number = 0): Promise<void> {
    if (!LiveViewManager.isLiveViewActive) {
      return;
    }
    LiveViewManager.isLiveViewActive = false;

    try {
      const session = LiveViewManager.currentSession;
      const titleStr = isCompleted
        ? `🎉 顺利降落抵达 ${session ? session.destCity : ''}！`
        : `⚠️ 航班已提前备降`;
      const detailStr = isCompleted
        ? `本次专注完成 ${totalFocusMinutes} 分钟，已记入飞行护照 🎫`
        : `航线已安全中止`;

      // 仅在后台时推送一次降落通知
      if (!LiveViewManager.isAppForeground) {
        const agent = await LiveViewManager.getClickWantAgent();
        const basicContent: notificationManager.NotificationBasicContent = {
          title: titleStr,
          text: detailStr
        };

        const request: notificationManager.NotificationRequest = {
          id: LiveViewManager.NOTIFICATION_ID,
          notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
          isOngoing: false,
          isAlertOnce: false,
          wantAgent: agent,
          content: {
            notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
            normal: basicContent
          }
        };

        await notificationManager.publish(request);

        setTimeout(async () => {
          try {
            await notificationManager.cancel(LiveViewManager.NOTIFICATION_ID);
          } catch (e) { }
        }, 8000);
      } else {
        // 在前台直接取消通知
        try {
          await notificationManager.cancel(LiveViewManager.NOTIFICATION_ID);
        } catch (e) { }
      }
    } catch (e) {
      try {
        await notificationManager.cancel(LiveViewManager.NOTIFICATION_ID);
      } catch (err) { }
    } finally {
      LiveViewManager.currentSession = null;
      LiveViewManager.isSystemLiveViewFailed = false;
      LiveViewManager.lastPushMins = -1;
    }
  }

  /**
   * 降级通知保底发布
   */
  private static async fallbackPublishBasic(title: string, text: string): Promise<void> {
    try {
      const agent = await LiveViewManager.getClickWantAgent();
      const basicContent: notificationManager.NotificationBasicContent = {
        title: title,
        text: text
      };
      const request: notificationManager.NotificationRequest = {
        id: LiveViewManager.NOTIFICATION_ID,
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        isOngoing: true,
        isAlertOnce: true,
        wantAgent: agent,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: basicContent
        }
      };
      await notificationManager.publish(request);
      hilog.info(DOMAIN, TAG, 'Fallback basic notification published successfully');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'fallbackPublishBasic error: %{public}s', JSON.stringify(e));
    }
  }
}
