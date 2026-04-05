import bridge from '@arkui-x.bridge';
import { FileLog } from './FileLog';
import buffer from '@ohos.buffer';



let bridgeObj: ESObject = null;
let hasChecked: boolean = false;
let isAvailable: boolean = false;

function initBridge(): boolean {
  if (hasChecked) {
    return isAvailable;
  }
  hasChecked = true;

  try {
    bridgeObj = bridge.createBridge('ImageSaveBridge');
    isAvailable = true;
    FileLog.i('ImageSaveHelper', 'Bridge 初始化成功');
  } catch (e) {
    let err = e as Error;
    FileLog.w('ImageSaveHelper', `Bridge 不可用: ${err.message}`);
    isAvailable = false;
  }
  return isAvailable;
}

export class ImageSaveHelper {
  
  static async saveViaContentResolver(targetUri: string, imageBuffer: ArrayBuffer): Promise<boolean> {
    if (!initBridge() || !bridgeObj) {
      return false;
    }

    try {
      
      let buf = buffer.from(imageBuffer);
      let base64Str = buf.toString('base64');
      FileLog.i('ImageSaveHelper', `Base64 编码完成, 长度=${base64Str.length}, 原始=${imageBuffer.byteLength}bytes`);

      
      let message = `${targetUri}||${base64Str}`;
      FileLog.i('ImageSaveHelper', `发送桥接消息, URI=${targetUri}`);

      let result: ESObject = await bridgeObj.sendMessage(message);
      let resultStr = String(result);
      FileLog.i('ImageSaveHelper', `桥接返回: ${resultStr}`);

      return resultStr === 'ok';
    } catch (e) {
      let err = e as Error;
      FileLog.e('ImageSaveHelper', `桥接调用异常: ${err.message}`);
      return false;
    }
  }

  
  static isBridgeAvailable(): boolean {
    return initBridge();
  }
}
