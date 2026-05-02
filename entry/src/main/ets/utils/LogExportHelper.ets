import fs from '@ohos.file.fs';
import { FileLog } from './FileLog';
import { ImageSaveHelper } from './ImageSaveHelper';

const TAG = 'LogExportHelper';

export class LogExportHelper {
  static async saveText(targetUri: string, content: string): Promise<boolean> {
    if (targetUri.startsWith('content://')) {
      try {
        return await ImageSaveHelper.saveTextViaContentResolver(targetUri, content);
      } catch (e) {
        let err = e as Error;
        FileLog.e(TAG, `content:// 写入日志失败: ${err.message}`);
        return false;
      }
    }

    try {
      let file = fs.openSync(targetUri, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, content);
      fs.closeSync(file);
      FileLog.i(TAG, `日志已写入: ${targetUri}`);
      return true;
    } catch (e) {
      let err = e as Error;
      FileLog.e(TAG, `fs 写入日志失败: ${err.message}`);
      return false;
    }
  }
}
