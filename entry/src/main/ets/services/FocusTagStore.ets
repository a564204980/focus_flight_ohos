/**
 * FocusTagStore.ets
 * 专注主题与任务标签持久化存储与状态管理服务
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FocusTagItem, PRESET_FOCUS_TAGS } from '../models/FocusTagModel';

const DOMAIN = 0x0000;
const STORE_NAME = 'focus_flight_tag_store';
const KEY_CURRENT_TAG_ID = 'current_focus_tag_id';
const KEY_CUSTOM_TAGS = 'custom_focus_tags_json';

export class FocusTagStore {
  private static prefInstance: preferences.Preferences | null = null;

  private static async getPref(context?: common.Context): Promise<preferences.Preferences | null> {
    if (FocusTagStore.prefInstance) {
      return FocusTagStore.prefInstance;
    }
    try {
      const ctx: common.Context | undefined = context || AppStorage.get<common.UIAbilityContext>('abilityContext');
      if (ctx) {
        FocusTagStore.prefInstance = await preferences.getPreferences(ctx, STORE_NAME);
        return FocusTagStore.prefInstance;
      }
    } catch (err) {
      hilog.error(DOMAIN, 'FocusTagStore', 'Failed to getPreferences: %{public}s', JSON.stringify(err));
    }
    return null;
  }

  /** 获取所有自定义标签 */
  public static async getCustomTags(context?: common.Context): Promise<FocusTagItem[]> {
    try {
      const pref = await FocusTagStore.getPref(context);
      if (pref) {
        const json = await pref.get(KEY_CUSTOM_TAGS, '[]') as string;
        const list = JSON.parse(json) as FocusTagItem[];
        return Array.isArray(list) ? list : [];
      }
    } catch (e) {
      hilog.error(DOMAIN, 'FocusTagStore', 'Failed to getCustomTags: %{public}s', JSON.stringify(e));
    }
    return [];
  }

  /** 获取全量标签列表（预设 + 自定义） */
  public static async getAllTags(context?: common.Context): Promise<FocusTagItem[]> {
    const customList = await FocusTagStore.getCustomTags(context);
    return [...PRESET_FOCUS_TAGS, ...customList];
  }

  /** 保存自定义标签 */
  public static async addCustomTag(tag: FocusTagItem, context?: common.Context): Promise<void> {
    try {
      const currentList = await FocusTagStore.getCustomTags(context);
      const filtered = currentList.filter(item => item.id !== tag.id);
      filtered.unshift(tag);
      const pref = await FocusTagStore.getPref(context);
      if (pref) {
        await pref.put(KEY_CUSTOM_TAGS, JSON.stringify(filtered));
        await pref.flush();
      }
      AppStorage.setOrCreate('customFocusTags', filtered);
    } catch (e) {
      hilog.error(DOMAIN, 'FocusTagStore', 'Failed to addCustomTag: %{public}s', JSON.stringify(e));
    }
  }

  /** 删除自定义标签 */
  public static async deleteCustomTag(tagId: string, context?: common.Context): Promise<void> {
    try {
      const currentList = await FocusTagStore.getCustomTags(context);
      const filtered = currentList.filter(item => item.id !== tagId);
      const pref = await FocusTagStore.getPref(context);
      if (pref) {
        await pref.put(KEY_CUSTOM_TAGS, JSON.stringify(filtered));
        await pref.flush();
      }
      AppStorage.setOrCreate('customFocusTags', filtered);
    } catch (e) {
      hilog.error(DOMAIN, 'FocusTagStore', 'Failed to deleteCustomTag: %{public}s', JSON.stringify(e));
    }
  }

  /** 获取当前选中的标签 ID */
  public static async getCurrentTagId(context?: common.Context): Promise<string> {
    try {
      const pref = await FocusTagStore.getPref(context);
      if (pref) {
        return (await pref.get(KEY_CURRENT_TAG_ID, 'study')) as string;
      }
    } catch (e) {
      hilog.error(DOMAIN, 'FocusTagStore', 'Failed to getCurrentTagId: %{public}s', JSON.stringify(e));
    }
    return 'study';
  }

  /** 保存当前选中的标签 ID 与相关信息 */
  public static async saveCurrentTag(tag: FocusTagItem, context?: common.Context): Promise<void> {
    try {
      const pref = await FocusTagStore.getPref(context);
      if (pref) {
        await pref.put(KEY_CURRENT_TAG_ID, tag.id);
        await pref.flush();
      }
      AppStorage.setOrCreate('currentFocusTagId', tag.id);
      AppStorage.setOrCreate('currentFocusTagTitle', tag.title);
      AppStorage.setOrCreate('currentFocusTagIcon', tag.icon);
      AppStorage.setOrCreate('currentFocusTagColor', tag.color);
      AppStorage.setOrCreate('currentFocusTagBg', tag.bg);
    } catch (e) {
      hilog.error(DOMAIN, 'FocusTagStore', 'Failed to saveCurrentTag: %{public}s', JSON.stringify(e));
    }
  }
}
