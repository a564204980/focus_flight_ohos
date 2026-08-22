/**
 * RdbDatabaseHelper.ets
 * Focus Flight 本地关系型数据库管理器 (HarmonyOS RDB)
 */

import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'RdbDatabaseHelper';
const DB_NAME = 'focus_flight.db';

export class RdbDatabaseHelper {
  private static instance: RdbDatabaseHelper | null = null;
  private rdbStore: relationalStore.RdbStore | null = null;

  private constructor() {}

  public static getInstance(): RdbDatabaseHelper {
    if (!RdbDatabaseHelper.instance) {
      RdbDatabaseHelper.instance = new RdbDatabaseHelper();
    }
    return RdbDatabaseHelper.instance;
  }

  /**
   * 获取或初始化 RdbStore 单例
   */
  public async getRdbStore(context?: common.Context): Promise<relationalStore.RdbStore> {
    if (this.rdbStore) {
      return this.rdbStore;
    }

    let ctx: common.Context | undefined = context || AppStorage.get<common.UIAbilityContext>('abilityContext');
    if (!ctx) {
      try {
        ctx = getContext() as common.UIAbilityContext;
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'getContext() fallback not available: %{public}s', JSON.stringify(e));
      }
    }
    if (!ctx) {
      throw new Error('No valid UIAbilityContext available for RdbStore initialization.');
    }

    const storeConfig: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };

    hilog.info(DOMAIN, TAG, 'Initializing RDB database: %{public}s', DB_NAME);
    this.rdbStore = await relationalStore.getRdbStore(ctx, storeConfig);

    // 初始化建表
    await this.initTables(this.rdbStore);
    return this.rdbStore;
  }

  /**
   * 首次启动创建核心数据表
   */
  private async initTables(store: relationalStore.RdbStore): Promise<void> {
    try {
      // 1. 航班历史记录表
      const sqlFlightRecords = `
        CREATE TABLE IF NOT EXISTS flight_records (
          id TEXT PRIMARY KEY,
          flight_no TEXT NOT NULL,
          origin_code TEXT NOT NULL,
          dest_code TEXT NOT NULL,
          task_title TEXT,
          duration_min INTEGER NOT NULL,
          actual_duration_min INTEGER NOT NULL,
          distance_km REAL NOT NULL,
          status TEXT NOT NULL,
          seat_id TEXT,
          start_time INTEGER NOT NULL,
          end_time INTEGER NOT NULL,
          events_json TEXT
        );
      `;
      await store.executeSql(sqlFlightRecords);

      // 自动补齐可能缺失的字段 (兼容旧版本数据库)
      const alterColumns = [
        "ALTER TABLE flight_records ADD COLUMN actual_duration_min INTEGER DEFAULT 0",
        "ALTER TABLE flight_records ADD COLUMN task_title TEXT",
        "ALTER TABLE flight_records ADD COLUMN events_json TEXT",
        "ALTER TABLE flight_records ADD COLUMN seat_id TEXT",
        "ALTER TABLE flight_records ADD COLUMN distance_km REAL DEFAULT 0"
      ];
      for (let i = 0; i < alterColumns.length; i++) {
        try {
          await store.executeSql(alterColumns[i]);
        } catch (e) { }
      }

      // 2. 机长档案与总数据表
      const sqlUserProfile = `
        CREATE TABLE IF NOT EXISTS user_profile (
          id INTEGER PRIMARY KEY,
          callsign TEXT DEFAULT '机长',
          total_flights INTEGER DEFAULT 0,
          total_minutes INTEGER DEFAULT 0,
          total_mileage_km REAL DEFAULT 0,
          current_streak_days INTEGER DEFAULT 0,
          last_flight_date TEXT
        );
      `;
      await store.executeSql(sqlUserProfile);

      // 3. 城市地标印章表
      const sqlUnlockedStamps = `
        CREATE TABLE IF NOT EXISTS unlocked_stamps (
          airport_code TEXT PRIMARY KEY,
          city_name TEXT NOT NULL,
          stamp_title TEXT,
          first_unlock_time INTEGER NOT NULL,
          visit_count INTEGER DEFAULT 1
        );
      `;
      await store.executeSql(sqlUnlockedStamps);

      hilog.info(DOMAIN, TAG, 'RDB tables initialized successfully.');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize RDB tables: %{public}s', JSON.stringify(err));
    }
  }
}
