

import { window } from '@kit.ArkUI';
import { FileLog } from './FileLog';

const TAG = 'Immersive';


export interface StepResult {
  step: string;
  success: boolean;
  error: string;
}


export interface ImmersiveLightResult {
  
  called: boolean;
  
  platform: string;
  
  isDark: boolean;
  
  steps: StepResult[];
  
  summary: string;
}

const TAG2 = 'ImmersiveHelper';


export function getImmersiveSystemBarProps(isDark: boolean): window.SystemBarProperties {
  return {
    statusBarColor: '#00000000',
    navigationBarColor: '#00000000',
    statusBarContentColor: isDark ? '#FFFFFF' : '#182431',
    navigationBarContentColor: isDark ? '#FFFFFF' : '#182431'
  };
}


export function getAmbientLightColors(isDark: boolean): Array<[string, number]> {
  if (isDark) {
    return [
      ['rgba(10, 166, 166, 0.08)', 0.0],
      ['rgba(10, 166, 166, 0.03)', 0.4],
      ['transparent', 1.0]
    ];
  } else {
    return [
      ['rgba(10, 166, 166, 0.06)', 0.0],
      ['rgba(10, 166, 166, 0.02)', 0.5],
      ['transparent', 1.0]
    ];
  }
}


function buildSummary(steps: StepResult[]): string {
  let parts: string[] = [];
  for (let s of steps) {
    let icon = s.success ? '✓' : '✗';
    parts.push(`${icon} ${s.step}`);
    if (!s.success && s.error) {
      parts.push(`  ↳ ${s.error}`);
    }
  }
  return parts.join('\n');
}


export async function setupImmersiveLight(
  mainWindow: window.Window,
  isDark: boolean
): Promise<ImmersiveLightResult> {
  let steps: StepResult[] = [];
  let result: ImmersiveLightResult = {
    called: true,
    platform: 'auto',
    isDark: isDark,
    steps: steps,
    summary: ''
  };

  FileLog.i(TAG, `========== 沉浸光感初始化开始 ==========`);
  FileLog.i(TAG, `  平台: ${result.platform}`);
  FileLog.i(TAG, `  暗色模式: ${isDark}`);

  try {
    
    try {
      mainWindow.setWindowLayoutFullScreen(true);
      steps.push({ step: 'setWindowLayoutFullScreen(true)', success: true, error: '' });
      FileLog.i(TAG, '  ✓ 步骤1: setWindowLayoutFullScreen → 成功');
    } catch (e) {
      let msg = (e as Error).message;
      steps.push({ step: 'setWindowLayoutFullScreen(true)', success: false, error: msg });
      FileLog.e(TAG, `  ✗ 步骤1: setWindowLayoutFullScreen → 失败: ${msg}`);
    }

    
    try {
      let sysBarProps = getImmersiveSystemBarProps(isDark);
      await mainWindow.setWindowSystemBarProperties(sysBarProps);
      steps.push({ step: 'setWindowSystemBarProperties(透明)', success: true, error: '' });
      FileLog.i(TAG, '  ✓ 步骤2: setWindowSystemBarProperties → 成功');
    } catch (e) {
      let msg = (e as Error).message;
      steps.push({ step: 'setWindowSystemBarProperties(透明)', success: false, error: msg });
      FileLog.e(TAG, `  ✗ 步骤2: setWindowSystemBarProperties → 失败: ${msg}`);
    }

    
    try {
      FileLog.i(TAG, '  → 步骤3: 尝试 setWindowShadowEnabled...');
      let win = mainWindow as Object as Record<string, Function>;
      if (typeof win['setWindowShadowEnabled'] === 'function') {
        await win['setWindowShadowEnabled'](true);
        steps.push({ step: 'setWindowShadowEnabled(true)', success: true, error: '' });
        FileLog.i(TAG, '  ✓ 步骤3: setWindowShadowEnabled → 成功');
      } else {
        steps.push({ step: 'setWindowShadowEnabled(true)', success: false, error: 'API 不存在' });
        FileLog.w(TAG, '  ✗ 步骤3: setWindowShadowEnabled → API 不存在');
      }
    } catch (e) {
      let msg = (e as Error).message;
      steps.push({ step: 'setWindowShadowEnabled(true)', success: false, error: msg });
      FileLog.w(TAG, `  ✗ 步骤3: setWindowShadowEnabled → 失败: ${msg}`);
    }

    FileLog.i(TAG, `========== 沉浸光感初始化结束 ==========`);
  } catch (e) {
    let msg = (e as Error).message;
    FileLog.e(TAG, `  ✗ 外层异常: ${msg}`);
    steps.push({ step: 'setupImmersiveLight(整体)', success: false, error: msg });
  }

  result.summary = buildSummary(steps);
  AppStorage.setOrCreate('immersive_light_result', result);
  FileLog.i(TAG, `摘要:\n${result.summary}`);
  FileLog.forceFlush(); 
  return result;
}
