import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'EntryFormAbility';
const DOMAIN: number = 0x0000;

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want) {
    hilog.info(DOMAIN, TAG, 'onAddForm');
    const formData: Record<string, string | number | boolean> = {
      'flightNo': 'FF-2026',
      'taskTitle': '深度专注',
      'originCode': 'CTU',
      'destCode': 'PEK',
      'destCity': '北京',
      'remainingTime': '25:00',
      'remainingKm': 1680,
      'progressPercent': 0,
      'isFlightActive': false,
      'todayFocusHours': '2.5',
      'rankTitle': '资深机长'
    };
    return formBindingData.createFormBindingData(formData);
  }

  onCastToNormalForm(formId: string) {
    hilog.info(DOMAIN, TAG, 'onCastToNormalForm');
  }

  onUpdateForm(formId: string) {
    hilog.info(DOMAIN, TAG, 'onUpdateForm');
  }

  onChangeFormVisibility(newStatus: Record<string, number>) {
    hilog.info(DOMAIN, TAG, 'onChangeFormVisibility');
  }

  onFormEvent(formId: string, message: string) {
    hilog.info(DOMAIN, TAG, 'onFormEvent, message: %{public}s', message);
  }

  onRemoveForm(formId: string) {
    hilog.info(DOMAIN, TAG, 'onRemoveForm');
  }

  onAcquireFormState(want: Want) {
    return formInfo.FormState.READY;
  }
}
