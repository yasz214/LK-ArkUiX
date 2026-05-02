import { ContentItem } from '../models/DataModels';
import { FileLog } from './FileLog';

export class ContentDataSource implements IDataSource {
  private dataArray: ContentItem[] = [];
  private listeners: DataChangeListener[] = [];

  public totalCount(): number { return this.dataArray.length; }
  public getData(index: number): ContentItem { return this.dataArray[index]; }

  public setData(dataArray: ContentItem[]): void {
    FileLog.i('ContentDS', `setData: 收到 ${dataArray.length} 条内容, listeners=${this.listeners.length}`);
    this.dataArray = dataArray;
    this.notifyDataReload();
  }

  
  public pushDataArray(dataArray: ContentItem[]): void {
    let startIndex = this.dataArray.length;
    this.dataArray.push(...dataArray);
    this.listeners.forEach(listener => {
      for (let i = 0; i < dataArray.length; i++) {
        listener.onDataAdd(startIndex + i);
      }
    });
  }

  
  public clear(): void {
    this.dataArray = [];
    this.notifyDataReload();
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
    FileLog.i('ContentDS', `registerListener: 现在有 ${this.listeners.length} 个监听器`);
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) { this.listeners.splice(pos, 1); }
  }
  notifyDataReload(): void {
    FileLog.i('ContentDS', `notifyDataReload: 通知 ${this.listeners.length} 个监听器, 数据量=${this.dataArray.length}`);
    this.listeners.forEach(listener => { listener.onDataReloaded(); })
  }
}