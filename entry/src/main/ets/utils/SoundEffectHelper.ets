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

import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

/**
 * 航空客舱原声与音频音效管理服务 (SoundEffectHelper)
 * 支持播放高保真客舱“叮咚”提示音 (Cabin Chime) 等无损音频
 */
export class SoundEffectHelper {
  /**
   * 播放经典民航客舱“叮咚～”双音提示音 (Cabin Chime)
   */
  static async playCabinArrivalChime(context?: common.Context): Promise<void> {
    try {
      const ctx: common.Context | undefined = context || AppStorage.get<common.UIAbilityContext>('abilityContext');
      if (!ctx) {
        return;
      }
      const resourceMgr = ctx.resourceManager;
      const rawFd = await resourceMgr.getRawFd('audio/cabin_chime_arrival.wav');

      const player = await media.createAVPlayer();
      player.on('stateChange', async (state: string) => {
        if (state === 'initialized') {
          player.prepare();
        } else if (state === 'prepared') {
          player.play();
        } else if (state === 'completed' || state === 'stopped' || state === 'error') {
          try {
            await resourceMgr.closeRawFd('audio/cabin_chime_arrival.wav');
          } catch (_e) { }
          player.release();
        }
      });
      player.fdSrc = rawFd;
      hilog.info(DOMAIN, 'SoundEffectHelper', 'Cabin arrival chime playback started');
    } catch (e) {
      hilog.error(DOMAIN, 'SoundEffectHelper', 'Failed to play cabin chime: %{public}s', JSON.stringify(e));
    }
  }
}
