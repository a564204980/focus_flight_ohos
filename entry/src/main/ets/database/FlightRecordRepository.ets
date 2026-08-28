/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * FlightRecordRepository.ets
 * Focus Flight 航班历史记录、机长档案与核心数据仓储服务 (精简高内聚版)
 */

import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RdbDatabaseHelper } from './RdbDatabaseHelper';
import { FlightSessionData } from '../services/FlightSessionStore';
import { findAirportByCode, getAirportStampTitle } from '../models/AirportModel';
import {
  FlightRecordDateFilter,
  FlightRecordItem,
  FlightStatsSummary,
  PagedFlightRecordsResult,
  DistractionReportSummary,
  HistoricalRouteSegment,
  TrendChartItem,
  TopTagItem,
  UnlockedStampItem
} from './FlightRecordTypes';
import { FlightStatsAnalytics } from './FlightStatsAnalytics';
import { FlightRecordMockSeeder } from './FlightRecordMockSeeder';

// 统一 Re-export 所有类型，确保外部调用方 100% 零破坏兼容
export * from './FlightRecordTypes';
export { FlightStatsAnalytics } from './FlightStatsAnalytics';
export { FlightRecordMockSeeder } from './FlightRecordMockSeeder';

const DOMAIN = 0x0000;
const TAG = 'FlightRecordRepository';

export class FlightRecordRepository {
  /**
   * 计算起降机场两点之间的大圆距离 (KM)
   */
  private static calculateDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371; // 地球平均半径 (km)
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Math.round(R * c);
  }

  /**
   * 记录一次完成或中断的专注航程
   */
  public static async saveCompletedFlight(session: FlightSessionData, isAborted: boolean): Promise<void> {
    try {
      const helper = RdbDatabaseHelper.getInstance();
      const store = await helper.getRdbStore();

      const origin = findAirportByCode(session.originCode);
      const dest = findAirportByCode(session.destCode);

      let distance: number = 800;
      if (origin && dest) {
        distance = FlightRecordRepository.calculateDistanceKm(origin.lat, origin.lon, dest.lat, dest.lon);
      }

      const recordId: string = `flight_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
      const flightNo: string = session.flightNo || 'FF-8801';
      const actualDuration: number = Math.round((Date.now() - session.startTimeMs) / 60000);
      const plannedDuration: number = session.durationMin || actualDuration;
      const statusStr: string = isAborted ? 'aborted' : 'completed';

      const bucket: relationalStore.ValuesBucket = {
        'id': recordId,
        'flight_no': flightNo,
        'origin_code': session.originCode,
        'dest_code': session.destCode,
        'task_title': session.taskTitle || '常规专注',
        'duration_min': plannedDuration,
        'actual_duration_min': Math.max(1, actualDuration),
        'distance_km': distance,
        'status': statusStr,
        'seat_id': session.seatId || '01A',
        'start_time': session.startTimeMs,
        'end_time': Date.now(),
        'events_json': JSON.stringify(session.events || [])
      };

      await store.insert('flight_records', bucket);

      // 解锁/更新目的地印章
      if (!isAborted && dest) {
        await FlightRecordRepository.unlockOrUpdateStamp(store, dest.code, dest.city);
      }

      // 更新机长总览信息
      await FlightRecordRepository.updateUserProfileAfterFlight(store, isAborted, actualDuration, distance);

      hilog.info(DOMAIN, TAG, 'Successfully saved flight record: %{public}s', recordId);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to save completed flight: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 解锁或更新城市纪念印章
   */
  public static async unlockOrUpdateStamp(store: relationalStore.RdbStore, airportCode: string, cityName: string): Promise<void> {
    try {
      const p = new relationalStore.RdbPredicates('passport_stamps');
      p.equalTo('airport_code', airportCode);
      const r = await store.query(p, ['id', 'visit_count']);

      if (r.rowCount > 0 && r.goToFirstRow()) {
        const id = r.getLong(0);
        const count = r.getLong(1);
        const b: relationalStore.ValuesBucket = {
          'visit_count': count + 1,
          'last_visit_time': Date.now()
        };
        const up = new relationalStore.RdbPredicates('passport_stamps');
        up.equalTo('id', id);
        await store.update(b, up);
      } else {
        const stampTitle = getAirportStampTitle(airportCode, cityName);
        const b: relationalStore.ValuesBucket = {
          'airport_code': airportCode,
          'city_name': cityName,
          'stamp_title': stampTitle,
          'unlocked': 1,
          'visit_count': 1,
          'first_unlock_time': Date.now(),
          'last_visit_time': Date.now()
        };
        await store.insert('passport_stamps', b);
      }
      r.close();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to unlock/update stamp: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 航程结束更新机长用户总档案
   */
  private static async updateUserProfileAfterFlight(
    store: relationalStore.RdbStore,
    isAborted: boolean,
    durationMin: number,
    distanceKm: number
  ): Promise<void> {
    try {
      const p = new relationalStore.RdbPredicates('user_profile');
      p.equalTo('id', 1);
      const r = await store.query(p, ['id', 'total_flights', 'total_minutes', 'total_mileage_km', 'current_streak_days', 'last_flight_date']);

      const todayStr = new Date().toISOString().split('T')[0];

      if (r.rowCount > 0 && r.goToFirstRow()) {
        const totalFlights = r.getLong(1) + (isAborted ? 0 : 1);
        const totalMinutes = r.getLong(2) + durationMin;
        const totalMileage = r.getDouble(3) + (isAborted ? 0 : distanceKm);
        let streak = r.getLong(4);
        const lastDate = r.getString(5);

        if (lastDate !== todayStr) {
          const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
          if (lastDate === yesterday) {
            streak += 1;
          } else {
            streak = 1;
          }
        }

        const b: relationalStore.ValuesBucket = {
          'total_flights': totalFlights,
          'total_minutes': totalMinutes,
          'total_mileage_km': totalMileage,
          'current_streak_days': streak,
          'last_flight_date': todayStr
        };
        await store.update(b, p);
      } else {
        const b: relationalStore.ValuesBucket = {
          'id': 1,
          'callsign': '机长',
          'total_flights': isAborted ? 0 : 1,
          'total_minutes': durationMin,
          'total_mileage_km': isAborted ? 0 : distanceKm,
          'current_streak_days': 1,
          'last_flight_date': todayStr
        };
        await store.insert('user_profile', b);
      }
      r.close();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to update user profile: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 获取数据库中存在航行记录的所有可用年份列表
   */
  public static async getAvailableYears(): Promise<number[]> {
    const years: number[] = [];
    try {
      const helper = RdbDatabaseHelper.getInstance();
      const store = await helper.getRdbStore();
      const sql = 'SELECT DISTINCT start_time FROM flight_records ORDER BY start_time DESC';
      const resultSet = await store.querySql(sql);

      while (resultSet.goToNextRow()) {
        const timeMs = resultSet.getLong(0);
        if (timeMs > 0) {
          const yr = new Date(timeMs).getFullYear();
          if (!years.includes(yr)) {
            years.push(yr);
          }
        }
      }
      resultSet.close();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to get available years: %{public}s', JSON.stringify(err));
    }

    if (years.length === 0) {
      years.push(new Date().getFullYear());
    }
    return years.sort((a, b) => b - a);
  }

  /**
   * 获取宏观统计总览数据
   */
  public static async getStatsSummary(yearFilter?: number): Promise<FlightStatsSummary> {
    try {
      const helper = RdbDatabaseHelper.getInstance();
      const store = await helper.getRdbStore();

      let whereClause = '';
      if (yearFilter && yearFilter > 0) {
        const startOfYear = new Date(yearFilter, 0, 1, 0, 0, 0, 0).getTime();
        const endOfYear = new Date(yearFilter + 1, 0, 1, 0, 0, 0, 0).getTime();
        whereClause = ` WHERE start_time >= ${startOfYear} AND start_time < ${endOfYear} `;
      }

      const sqlCompleted = `SELECT COUNT(*), SUM(actual_duration_min), SUM(distance_km) FROM flight_records ${whereClause ? whereClause + " AND status = 'completed'" : "WHERE status = 'completed'"}`;
      const resCompleted = await store.querySql(sqlCompleted);

      let totalFlights = 0;
      let totalMinutes = 0;
      let totalDistanceKm = 0;

      if (resCompleted.goToNextRow()) {
        totalFlights = resCompleted.getLong(0);
        totalMinutes = resCompleted.getLong(1);
        totalDistanceKm = Math.round(resCompleted.getDouble(2));
      }
      resCompleted.close();

      const sqlDests = `SELECT COUNT(DISTINCT dest_code) FROM flight_records ${whereClause ? whereClause + " AND status = 'completed'" : "WHERE status = 'completed'"}`;
      const resDests = await store.querySql(sqlDests);
      let uniqueDests = 0;
      if (resDests.goToNextRow()) {
        uniqueDests = resDests.getLong(0);
      }
      resDests.close();

      const sqlHaul = `SELECT duration_min FROM flight_records ${whereClause ? whereClause + " AND status = 'completed'" : "WHERE status = 'completed'"}`;
      const resHaul = await store.querySql(sqlHaul);
      let shortHaul = 0;
      let longHaul = 0;
      while (resHaul.goToNextRow()) {
        const dur = resHaul.getLong(0);
        if (dur <= 25) {
          shortHaul++;
        } else {
          longHaul++;
        }
      }
      resHaul.close();

      const sqlAborted = `SELECT COUNT(*), AVG(actual_duration_min) FROM flight_records ${whereClause ? whereClause + " AND status = 'aborted'" : "WHERE status = 'aborted'"}`;
      const resAborted = await store.querySql(sqlAborted);
      let abortedCount = 0;
      let avgDistractedMin = 6;
      if (resAborted.goToNextRow()) {
        abortedCount = resAborted.getLong(0);
        const avg = resAborted.getDouble(1);
        if (avg > 0) {
          avgDistractedMin = Math.round(avg);
        }
      }
      resAborted.close();

      return {
        totalFlights,
        totalMinutes,
        totalDistanceKm,
        uniqueDestinationsCount: uniqueDests,
        currentStreakDays: 1,
        shortHaulCount: shortHaul,
        longHaulCount: longHaul,
        abortedFlightsCount: abortedCount,
        avgDistractedMin: avgDistractedMin
      };
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to get stats summary: %{public}s', JSON.stringify(err));
      return {
        totalFlights: 0,
        totalMinutes: 0,
        totalDistanceKm: 0,
        uniqueDestinationsCount: 0,
        currentStreakDays: 0,
        shortHaulCount: 0,
        longHaulCount: 0,
        abortedFlightsCount: 0,
        avgDistractedMin: 6
      };
    }
  }

  /**
   * 应用时间筛选条件至 RdbPredicates
   */
  public static applyDateFilterToPredicates(predicates: relationalStore.RdbPredicates, filterParam?: number | FlightRecordDateFilter): void {
    let filter: FlightRecordDateFilter = { type: 'all' };
    if (typeof filterParam === 'number') {
      if (filterParam > 0) {
        filter = { type: 'year', year: filterParam };
      }
    } else if (filterParam) {
      filter = filterParam;
    }

    if (filter.type === 'year' && filter.year) {
      const startOfYear = new Date(filter.year, 0, 1, 0, 0, 0, 0).getTime();
      const endOfYear = new Date(filter.year + 1, 0, 1, 0, 0, 0, 0).getTime();
      predicates.greaterThanOrEqualTo('start_time', startOfYear);
      predicates.lessThan('start_time', endOfYear);
    } else if (filter.type === 'month' && filter.year && filter.month) {
      const startOfMonth = new Date(filter.year, filter.month - 1, 1, 0, 0, 0, 0).getTime();
      const endOfMonth = new Date(filter.year, filter.month, 1, 0, 0, 0, 0).getTime();
      predicates.greaterThanOrEqualTo('start_time', startOfMonth);
      predicates.lessThan('start_time', endOfMonth);
    } else if (filter.type === 'day' && filter.year && filter.month && filter.day) {
      const startOfDay = new Date(filter.year, filter.month - 1, filter.day, 0, 0, 0, 0).getTime();
      const endOfDay = new Date(filter.year, filter.month - 1, filter.day + 1, 0, 0, 0, 0).getTime();
      predicates.greaterThanOrEqualTo('start_time', startOfDay);
      predicates.lessThan('start_time', endOfDay);
    }
  }

  /**
   * 获取所有历史航线记录
   */
  public static async getAllFlightRecords(filterParam?: number | FlightRecordDateFilter): Promise<FlightRecordItem[]> {
    const list: FlightRecordItem[] = [];
    try {
      const helper = RdbDatabaseHelper.getInstance();
      const store = await helper.getRdbStore();

      const predicates = new relationalStore.RdbPredicates('flight_records');
      FlightRecordRepository.applyDateFilterToPredicates(predicates, filterParam);
      predicates.orderByDesc('end_time');

      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        list.push({
          id: resultSet.getString(resultSet.getColumnIndex('id')),
          flightNo: resultSet.getString(resultSet.getColumnIndex('flight_no')),
          originCode: resultSet.getString(resultSet.getColumnIndex('origin_code')),
          destCode: resultSet.getString(resultSet.getColumnIndex('dest_code')),
          taskTitle: resultSet.getString(resultSet.getColumnIndex('task_title')),
          durationMin: resultSet.getLong(resultSet.getColumnIndex('duration_min')),
          actualDurationMin: resultSet.getLong(resultSet.getColumnIndex('actual_duration_min')),
          distanceKm: resultSet.getDouble(resultSet.getColumnIndex('distance_km')),
          status: resultSet.getString(resultSet.getColumnIndex('status')) as 'completed' | 'aborted',
          seatId: resultSet.getString(resultSet.getColumnIndex('seat_id')),
          startTime: resultSet.getLong(resultSet.getColumnIndex('start_time')),
          endTime: resultSet.getLong(resultSet.getColumnIndex('end_time')),
          eventsJson: resultSet.getString(resultSet.getColumnIndex('events_json'))
        });
      }
      resultSet.close();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to get all flight records: %{public}s', JSON.stringify(err));
    }
    return list;
  }

  /**
   * 高性能分页查询历史航线记录 (LIMIT + OFFSET)
   */
  public static async getPagedFlightRecords(filterParam?: number | FlightRecordDateFilter, page: number = 1, pageSize: number = 20): Promise<PagedFlightRecordsResult> {
    const list: FlightRecordItem[] = [];
    let totalCount = 0;
    try {
      const helper = RdbDatabaseHelper.getInstance();
      const store = await helper.getRdbStore();

      const predicatesCount = new relationalStore.RdbPredicates('flight_records');
      FlightRecordRepository.applyDateFilterToPredicates(predicatesCount, filterParam);
      const countRes = await store.query(predicatesCount, ['id']);
      totalCount = countRes.rowCount > 0 ? countRes.rowCount : 0;
      countRes.close();

      const predicates = new relationalStore.RdbPredicates('flight_records');
      FlightRecordRepository.applyDateFilterToPredicates(predicates, filterParam);
      predicates.orderByDesc('end_time');
      predicates.limitAs(pageSize);
      predicates.offsetAs((page - 1) * pageSize);

      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        list.push({
          id: resultSet.getString(resultSet.getColumnIndex('id')),
          flightNo: resultSet.getString(resultSet.getColumnIndex('flight_no')),
          originCode: resultSet.getString(resultSet.getColumnIndex('origin_code')),
          destCode: resultSet.getString(resultSet.getColumnIndex('dest_code')),
          taskTitle: resultSet.getString(resultSet.getColumnIndex('task_title')),
          durationMin: resultSet.getLong(resultSet.getColumnIndex('duration_min')),
          actualDurationMin: resultSet.getLong(resultSet.getColumnIndex('actual_duration_min')),
          distanceKm: resultSet.getDouble(resultSet.getColumnIndex('distance_km')),
          status: resultSet.getString(resultSet.getColumnIndex('status')) as 'completed' | 'aborted',
          seatId: resultSet.getString(resultSet.getColumnIndex('seat_id')),
          startTime: resultSet.getLong(resultSet.getColumnIndex('start_time')),
          endTime: resultSet.getLong(resultSet.getColumnIndex('end_time')),
          eventsJson: resultSet.getString(resultSet.getColumnIndex('events_json'))
        });
      }
      resultSet.close();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to get paged flight records: %{public}s', JSON.stringify(err));
    }

    const hasMore = (page * pageSize) < totalCount;
    const res: PagedFlightRecordsResult = {
      records: list,
      totalCount: totalCount,
      hasMore: hasMore
    };
    return res;
  }

  /**
   * 查询指定月份中有飞行记录的日期数组 (1-31)
   */
  public static async getFlightDaysInMonth(year: number, month: number): Promise<number[]> {
    const days: number[] = [];
    try {
      const helper = RdbDatabaseHelper.getInstance();
      const store = await helper.getRdbStore();

      const startOfMonth = new Date(year, month - 1, 1, 0, 0, 0, 0).getTime();
      const endOfMonth = new Date(year, month, 1, 0, 0, 0, 0).getTime();

      const sql = `SELECT DISTINCT start_time FROM flight_records WHERE start_time >= ${startOfMonth} AND start_time < ${endOfMonth}`;
      const resultSet = await store.querySql(sql);

      while (resultSet.goToNextRow()) {
        const timeMs = resultSet.getLong(0);
        if (timeMs > 0) {
          const d = new Date(timeMs).getDate();
          if (!days.includes(d)) {
            days.push(d);
          }
        }
      }
      resultSet.close();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to get flight days in month: %{public}s', JSON.stringify(err));
    }
    return days;
  }

  /**
   * 查询指定时间范围内每天的专注分钟数与航班起飞次数 (用于 GitHub 热力图)
   */
  public static async getDailyFocusStatsMap(startTimestamp: number, endTimestamp: number): Promise<Record<string, number>> {
    const map: Record<string, number> = {};
    try {
      const helper = RdbDatabaseHelper.getInstance();
      const store = await helper.getRdbStore();

      const sql = `SELECT start_time, actual_duration_min FROM flight_records WHERE start_time >= ${startTimestamp} AND start_time < ${endTimestamp}`;
      const resultSet = await store.querySql(sql);

      while (resultSet.goToNextRow()) {
        const timeMs = resultSet.getLong(0);
        const actualMin = resultSet.getLong(1);
        if (timeMs > 0) {
          const d = new Date(timeMs);
          const y = d.getFullYear();
          const m = (d.getMonth() + 1).toString().padStart(2, '0');
          const day = d.getDate().toString().padStart(2, '0');
          const key = `${y}-${m}-${day}`;
          map[key] = (map[key] || 0) + actualMin;
        }
      }
      resultSet.close();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to get daily focus stats: %{public}s', JSON.stringify(err));
    }
    return map;
  }

  // ================= 静态代理方法 (委托给对应专业分析/种子模块) =================

  public static async getDistractionReportSummary(yearFilter?: number): Promise<DistractionReportSummary> {
    return FlightStatsAnalytics.getDistractionReportSummary(yearFilter);
  }

  public static async getTrendChartData(mode: 'week' | 'month', yearFilter?: number): Promise<Array<TrendChartItem>> {
    return FlightStatsAnalytics.getTrendChartData(mode, yearFilter);
  }

  public static async getTopTaskTags(yearFilter?: number): Promise<Array<TopTagItem>> {
    return FlightStatsAnalytics.getTopTaskTags(yearFilter);
  }

  public static async getHistoricalRouteSegments(yearFilter?: number): Promise<HistoricalRouteSegment[]> {
    return FlightStatsAnalytics.getHistoricalRouteSegments(yearFilter);
  }

  public static async seed2025MockDataIfEmpty(): Promise<void> {
    return FlightRecordMockSeeder.seed2025MockDataIfEmpty();
  }
}
