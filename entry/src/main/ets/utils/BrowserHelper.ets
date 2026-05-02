import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import bridge from '@arkui-x.bridge';
import { promptAction } from '@kit.ArkUI';
import { FileLog } from './FileLog';



const TAG = 'BrowserHelper';

let browserBridgeObj: ESObject = null;
let bridgeChecked: boolean = false;
let bridgeAvailable: boolean = false;

function initBridge(): boolean {
  if (bridgeChecked) {
    return bridgeAvailable;
  }
  bridgeChecked = true;

  try {
    browserBridgeObj = bridge.createBridge('BrowserBridge');
    bridgeAvailable = true;
    FileLog.i(TAG, 'BrowserBridge 初始化成功（Android 平台）');
  } catch (e) {
    let err = e as Error;
    FileLog.w(TAG, `BrowserBridge 不可用（可能在 HarmonyOS 上）: ${err.message}`);
    bridgeAvailable = false;
  }
  return bridgeAvailable;
}


export async function openUrl(url: string, context: common.UIAbilityContext): Promise<void> {
  if (!url) {
    FileLog.w(TAG, '传入的 URL 为空');
    return;
  }

  FileLog.i(TAG, `打开链接: ${url}`);

  
  if (initBridge() && browserBridgeObj) {
    try {
      let result: ESObject = await browserBridgeObj.sendMessage(url);
      let resultStr = String(result);
      FileLog.i(TAG, `BrowserBridge 返回: ${resultStr}`);
      if (resultStr !== 'ok') {
        FileLog.e(TAG, `BrowserBridge 打开失败: ${resultStr}`);
        promptAction.openToast({ message: '无法打开链接' });
      }
    } catch (e) {
      let err = e as Error;
      FileLog.e(TAG, `BrowserBridge 调用异常: ${err.message}`);
      promptAction.openToast({ message: '无法打开链接' });
    }
    return;
  }

  
  try {
    let want: Record<string, string> = {
      'action': 'ohos.want.action.viewData',
      'uri': url
    };
    context.startAbility(want as Object as Want).catch(() => {
      FileLog.w(TAG, `startAbility 异步失败: ${url}`);
    });
  } catch (e) {
    let err = e as Error;
    FileLog.e(TAG, `HarmonyOS 打开浏览器失败: ${err.message}`);
    promptAction.openToast({ message: '无法打开链接' });
  }
}
