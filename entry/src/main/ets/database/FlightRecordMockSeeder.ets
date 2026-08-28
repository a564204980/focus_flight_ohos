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

import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RdbDatabaseHelper } from './RdbDatabaseHelper';
import { FlightRecordItem } from './FlightRecordTypes';

const DOMAIN = 0x0000;
const TAG = 'FlightRecordMockSeeder';

interface MockDef {
  tag: string;
  count: number;
  duration: number;
  dist: number;
  orig: string;
  dest: string;
}

/**
 * 历史模拟航程与机长数据种子生成器
 */
export class FlightRecordMockSeeder {
  /**
   * 自动植入 2025 与 2026 年的真实样本假数据 (若对应年份尚无数据)
   */
  public static async seed2025MockDataIfEmpty(): Promise<void> {
    try {
      const helper = RdbDatabaseHelper.getInstance();
      const store = await helper.getRdbStore();

      // 清除旧的 mock 记录，确保幂等注入包含丰富专注梯队的数据
      await store.executeSql(`DELETE FROM flight_records WHERE id LIKE 'mock_%'`);

      const mock2025Def: Array<MockDef> = [
        // 🇨🇳 国内骨干与区域航线网络
        { tag: '需求分析与原型规划', count: 12, duration: 45, dist: 1200, orig: 'PEK', dest: 'SHA' },
        { tag: '前后端接口联调', count: 9, duration: 30, dist: 1080, orig: 'CAN', dest: 'HGH' },
        { tag: '系统架构设计', count: 7, duration: 60, dist: 1950, orig: 'SZX', dest: 'PEK' },
        { tag: '性能优化与压测', count: 6, duration: 35, dist: 1310, orig: 'CTU', dest: 'SZX' },
        { tag: '技术难题攻关', count: 5, duration: 50, dist: 1550, orig: 'CTU', dest: 'PEK' },
        { tag: '数据库索引调优', count: 4, duration: 40, dist: 1210, orig: 'SHA', dest: 'CAN' },
        { tag: '微服务重构与治理', count: 4, duration: 45, dist: 1250, orig: 'CAN', dest: 'CTU' },
        { tag: '高并发缓存设计', count: 4, duration: 30, dist: 1160, orig: 'HGH', dest: 'XIY' },
        { tag: 'UI组件库封装', count: 4, duration: 25, dist: 580, orig: 'XIY', dest: 'CKG' },
        { tag: '安全审计与防护', count: 3, duration: 45, dist: 640, orig: 'CKG', dest: 'KMG' },
        { tag: '离线包优化落地', count: 3, duration: 30, dist: 1020, orig: 'KMG', dest: 'SYX' },
        { tag: '持续集成流水线构建', count: 3, duration: 50, dist: 2410, orig: 'PEK', dest: 'URC' },
        { tag: '自动化测试编写', count: 3, duration: 40, dist: 1520, orig: 'URC', dest: 'LXA' },
        { tag: '高原节点部署测试', count: 3, duration: 60, dist: 1280, orig: 'LXA', dest: 'CTU' },
        { tag: '数据大盘搭建', count: 3, duration: 35, dist: 1070, orig: 'PEK', dest: 'HRB' },
        { tag: '移动端适配调优', count: 3, duration: 25, dist: 820, orig: 'SHA', dest: 'XMN' },
        { tag: '消息队列改造', count: 2, duration: 30, dist: 490, orig: 'NKG', dest: 'TAO' },
        { tag: '开源代码学习', count: 2, duration: 25, dist: 520, orig: 'CTU', dest: 'LJG' },
        { tag: '中台服务对接', count: 2, duration: 30, dist: 510, orig: 'XIY', dest: 'LHW' },
        { tag: '边缘计算探索', count: 2, duration: 35, dist: 450, orig: 'CAN', dest: 'HAK' },
        
        // 🌏 国际与跨大洲探索航线 (全球流光航网)
        { tag: '全球化多语言方案', count: 5, duration: 60, dist: 2100, orig: 'PEK', dest: 'HND' },
        { tag: '跨境CDN与加速规划', count: 4, duration: 45, dist: 830, orig: 'SHA', dest: 'ICN' },
        { tag: '亚太集群运维治理', count: 4, duration: 50, dist: 3800, orig: 'PVG', dest: 'SIN' },
        { tag: '东南亚支付网关对接', count: 3, duration: 40, dist: 1700, orig: 'CAN', dest: 'BKK' },
        { tag: '欧洲隐私合规GDPR', count: 3, duration: 60, dist: 8140, orig: 'PEK', dest: 'LHR' },
        { tag: '跨国协作与技术分享', count: 3, duration: 60, dist: 9260, orig: 'PVG', dest: 'CDG' },
        { tag: '云原生开源生态研究', count: 2, duration: 50, dist: 7690, orig: 'CTU', dest: 'FRA' },
        { tag: '中东金融网关调研', count: 2, duration: 45, dist: 5850, orig: 'PEK', dest: 'DXB' },
        { tag: '澳洲跨洋节点测试', count: 2, duration: 60, dist: 7890, orig: 'PVG', dest: 'SYD' },
        { tag: '硅谷技术架构交流', count: 2, duration: 60, dist: 9510, orig: 'PEK', dest: 'SFO' },
        { tag: '华尔街量化系统分析', count: 2, duration: 60, dist: 11890, orig: 'PVG', dest: 'JFK' },
        { tag: '大洋洲专线延时优化', count: 2, duration: 50, dist: 9320, orig: 'CAN', dest: 'AKL' }
      ];

      const mock2026Def: Array<MockDef> = [
        { tag: '深度学习与AI研发', count: 18, duration: 60, dist: 2100, orig: 'PEK', dest: 'HND' },
        { tag: '交互体验与设计打磨', count: 12, duration: 30, dist: 1550, orig: 'CTU', dest: 'PEK' },
        { tag: '系统架构演进', count: 8, duration: 45, dist: 1210, orig: 'SHA', dest: 'CAN' },
        { tag: '核心模块重构', count: 5, duration: 40, dist: 1600, orig: 'HGH', dest: 'CTU' },
        { tag: '代码审查与评审', count: 2, duration: 25, dist: 1088, orig: 'PEK', dest: 'SHA' }
      ];

      const allMockFlights: Array<FlightRecordItem> = [];
      let idx = 1;

      for (let i = 0; i < mock2025Def.length; i++) {
        const d = mock2025Def[i];
        for (let k = 0; k < d.count; k++) {
          const month = (k % 12);
          const day = (k % 28) + 1;
          const sTime = new Date(2025, month, day, 10 + (k % 8), 0, 0).getTime();
          
          let actual = d.duration;
          let status: 'completed' | 'aborted' = 'completed';
          const mod = (i * 3 + k) % 10;
          if (mod < 5) {
            actual = d.duration;
          } else if (mod === 5 || mod === 6) {
            actual = Math.max(1, Math.round(d.duration * 0.88));
          } else if (mod === 7) {
            actual = Math.max(1, Math.round(d.duration * 0.65));
          } else if (mod === 8) {
            actual = Math.max(1, Math.round(d.duration * 0.40));
          } else {
            actual = Math.max(1, Math.round(d.duration * 0.20));
            status = 'aborted';
          }

          allMockFlights.push({
            id: `mock_2025_${idx++}`,
            flightNo: `FF-88${idx.toString().padStart(2, '0')}`,
            originCode: d.orig,
            destCode: d.dest,
            taskTitle: d.tag,
            durationMin: d.duration,
            actualDurationMin: actual,
            distanceKm: d.dist,
            status: status,
            seatId: '01A',
            startTime: sTime,
            endTime: sTime + actual * 60000,
            eventsJson: '[]'
          });
        }
      }

      for (let i = 0; i < mock2026Def.length; i++) {
        const d = mock2026Def[i];
        for (let k = 0; k < d.count; k++) {
          const month = (k % 8);
          const day = (k % 28) + 1;
          const sTime = new Date(2026, month, day, 9 + (k % 8), 0, 0).getTime();
          
          let actual = d.duration;
          let status: 'completed' | 'aborted' = 'completed';
          const mod = (i * 3 + k) % 10;
          if (mod < 6) {
            actual = d.duration;
          } else if (mod === 6 || mod === 7) {
            actual = Math.max(1, Math.round(d.duration * 0.85));
          } else if (mod === 8) {
            actual = Math.max(1, Math.round(d.duration * 0.60));
          } else {
            actual = Math.max(1, Math.round(d.duration * 0.25));
            status = 'aborted';
          }

          allMockFlights.push({
            id: `mock_2026_${idx++}`,
            flightNo: `FF-99${idx.toString().padStart(2, '0')}`,
            originCode: d.orig,
            destCode: d.dest,
            taskTitle: d.tag,
            durationMin: d.duration,
            actualDurationMin: actual,
            distanceKm: d.dist,
            status: status,
            seatId: '02B',
            startTime: sTime,
            endTime: sTime + actual * 60000,
            eventsJson: '[]'
          });
        }
      }

      // 添加 2 条典型分心/中断记录用于丰富分心报告
      allMockFlights.push({
        id: `mock_dist_01`,
        flightNo: 'FF-7701',
        originCode: 'SZX',
        destCode: 'PEK',
        taskTitle: '需求梳理 (紧急会议中断)',
        durationMin: 25,
        actualDurationMin: 4,
        distanceKm: 1950,
        status: 'aborted',
        seatId: '04C',
        startTime: new Date(2025, 10, 2, 9, 0, 0).getTime(),
        endTime: new Date(2025, 10, 2, 9, 4, 0).getTime(),
        eventsJson: '[]'
      });
      allMockFlights.push({
        id: `mock_dist_02`,
        flightNo: 'FF-7702',
        originCode: 'PEK',
        destCode: 'SHA',
        taskTitle: '深度学习 (切出后台)',
        durationMin: 45,
        actualDurationMin: 8,
        distanceKm: 1088,
        status: 'aborted',
        seatId: '01A',
        startTime: new Date(2026, 4, 12, 11, 0, 0).getTime(),
        endTime: new Date(2026, 4, 12, 11, 8, 0).getTime(),
        eventsJson: '[]'
      });

      for (let i = 0; i < allMockFlights.length; i++) {
        const item = allMockFlights[i];
        const b: relationalStore.ValuesBucket = {
          'id': item.id,
          'flight_no': item.flightNo,
          'origin_code': item.originCode,
          'dest_code': item.destCode,
          'task_title': item.taskTitle,
          'duration_min': item.durationMin,
          'actual_duration_min': item.actualDurationMin,
          'distance_km': item.distanceKm,
          'status': item.status,
          'seat_id': item.seatId,
          'start_time': item.startTime,
          'end_time': item.endTime,
          'events_json': item.eventsJson
        };
        await store.insert('flight_records', b);
      }

      // 解锁对应的城市地标印章
      const cities: [string, string][] = [
        ['SHA', '上海'], ['SZX', '深圳'], ['HGH', '杭州'], ['HND', '东京'],
        ['PEK', '北京'], ['CAN', '广州'], ['CTU', '成都']
      ];
      for (let c of cities) {
        await FlightRecordMockSeeder.unlockStampHelper(store, c[0], c[1]);
      }

      // 同步初始化 user_profile
      const userPredicates = new relationalStore.RdbPredicates('user_profile');
      userPredicates.equalTo('id', 1);
      const userRes = await store.query(userPredicates, ['id']);
      if (userRes.rowCount === 0) {
        const userBucket: relationalStore.ValuesBucket = {
          'id': 1,
          'callsign': '机长',
          'total_flights': 7,
          'total_minutes': 260,
          'total_mileage_km': 9868,
          'current_streak_days': 3,
          'last_flight_date': '2026-08-22'
        };
        await store.insert('user_profile', userBucket);
      }
      userRes.close();

      hilog.info(DOMAIN, TAG, 'Successfully seeded mock flight records.');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to seed mock data: %{public}s', JSON.stringify(e));
    }
  }

  private static async unlockStampHelper(store: relationalStore.RdbStore, airportCode: string, cityName: string): Promise<void> {
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
        const b: relationalStore.ValuesBucket = {
          'airport_code': airportCode,
          'city_name': cityName,
          'stamp_title': `${cityName} 飞行纪念章`,
          'unlocked': 1,
          'visit_count': 1,
          'first_unlock_time': Date.now(),
          'last_visit_time': Date.now()
        };
        await store.insert('passport_stamps', b);
      }
      r.close();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to unlock stamp: %{public}s', JSON.stringify(err));
    }
  }
}
