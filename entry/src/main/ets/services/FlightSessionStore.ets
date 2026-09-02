/**
 * FlightSessionStore.ets
 * 飞行专注会话状态持久化存储服务
 * 用于跨应用生命周期 (后台切换、应用重启) 保持专注飞行会话状态
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const STORE_NAME = 'focus_flight_session_store';
const KEY_SESSION = 'active_flight_session';

export interface FlightEvent {
  id: string;
  type: 'gate_departure' | 'takeoff' | 'cruise' | 'deviation' | 'recovery' | 'turbulence' | 'descent_prep' | 'landing';
  timestampMs: number;
  durationMs?: number;
  note?: string;
}

export interface FlightSessionData {
  isFlightActive: boolean;
  flightNo: string;
  seatId: string;
  taskTitle: string;
  durationMin: number;
  originCode: string;
  destCode: string;
  startTimeMs: number;
  checkInTimeMs?: number;     // 🎫 用户办理值机/选定目的地的时间
  isWindowViewMode?: boolean; // 🪟 记录用户是否处于舷窗视角模式
  isRoamingMode?: boolean;    // ☁️ 记录是否为正向计时的漫游探索模式
  events?: FlightEvent[];     // 飞行日志事件流
}

export class FlightSessionStore {
  private static prefInstance: preferences.Preferences | null = null;

  private static async getPref(context?: common.Context): Promise<preferences.Preferences | null> {
    if (FlightSessionStore.prefInstance) {
      return FlightSessionStore.prefInstance;
    }
    try {
      const ctx: common.Context | undefined = context || AppStorage.get<common.UIAbilityContext>('abilityContext');
      if (ctx) {
        FlightSessionStore.prefInstance = await preferences.getPreferences(ctx, STORE_NAME);
        return FlightSessionStore.prefInstance;
      }
    } catch (err) {
      hilog.error(DOMAIN, 'FlightSessionStore', 'Failed to getPreferences: %{public}s', JSON.stringify(err));
    }
    return null;
  }

  /**
   * 更新当前飞行会话的舷窗视图模式状态
   */
  static async updateWindowViewMode(isWindowViewMode: boolean, context?: common.Context): Promise<void> {
    try {
      const session = await FlightSessionStore.getSession(context);
      if (session && session.isFlightActive) {
        session.isWindowViewMode = isWindowViewMode;
        await FlightSessionStore.saveSession(session, context);
      }
    } catch (err) {
      hilog.error(DOMAIN, 'FlightSessionStore', 'Failed to updateWindowViewMode: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 保存当前活跃的飞行专注会话
   */
  static async saveSession(session: FlightSessionData, context?: common.Context): Promise<void> {
    try {
      // 1. 同步更新 Memory AppStorage
      AppStorage.setOrCreate<FlightSessionData>('activeFlightSession', session);

      // 2. 持久化存储到磁盘 Preferences
      const pref = await FlightSessionStore.getPref(context);
      if (pref) {
        const jsonStr: string = JSON.stringify(session);
        await pref.put(KEY_SESSION, jsonStr);
        await pref.flush();
        hilog.info(DOMAIN, 'FlightSessionStore', 'Flight session persisted successfully');
      }
    } catch (err) {
      hilog.error(DOMAIN, 'FlightSessionStore', 'Failed to save session: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 获取持久化的飞行专注会话
   */
  static async getSession(context?: common.Context): Promise<FlightSessionData | null> {
    try {
      // 1. 先读 AppStorage 内存缓存
      const inMem = AppStorage.get<FlightSessionData>('activeFlightSession');
      if (inMem && inMem.isFlightActive) {
        return inMem;
      }

      // 2. 读 Preferences 磁盘文件
      const pref = await FlightSessionStore.getPref(context);
      if (pref) {
        const val: preferences.ValueType = await pref.get(KEY_SESSION, '');
        const jsonStr: string = typeof val === 'string' ? val : '';
        if (jsonStr && jsonStr.length > 0) {
          const session = JSON.parse(jsonStr) as FlightSessionData;
          if (session && session.isFlightActive) {
            AppStorage.setOrCreate<FlightSessionData>('activeFlightSession', session);
            return session;
          }
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, 'FlightSessionStore', 'Failed to get session: %{public}s', JSON.stringify(err));
    }
    return null;
  }

  /**
   * 清除飞行专注会话 (降落完成/取消飞行/用户手动退出)
   */
  static async clearSession(context?: common.Context): Promise<void> {
    try {
      AppStorage.setOrCreate<FlightSessionData | null>('activeFlightSession', null);
      const pref = await FlightSessionStore.getPref(context);
      if (pref) {
        await pref.delete(KEY_SESSION);
        await pref.flush();
        hilog.info(DOMAIN, 'FlightSessionStore', 'Flight session cleared');
      }
    } catch (err) {
      hilog.error(DOMAIN, 'FlightSessionStore', 'Failed to clear session: %{public}s', JSON.stringify(err));
    }
  }
}
