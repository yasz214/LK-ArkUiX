import { NovelGroup } from '../models/DataModels';
import { NovelRepository } from '../repository/NovelRepository';
import { PreferenceManager } from '../utils/PreferenceManager';

@Observed
export class IndexViewModel {
  recommendGroups: NovelGroup[] = [];
  isLoading: boolean = true;
  message: string = '加载中...';

  isUpdating: boolean = false;
  lastUpdateTime: string = '';

  
  private getFormattedTime(): string {
    let d = new Date();
    let y = d.getFullYear();
    let m = (d.getMonth() + 1).toString().padStart(2, '0');
    let day = d.getDate().toString().padStart(2, '0');
    let h = d.getHours().toString().padStart(2, '0');
    let min = d.getMinutes().toString().padStart(2, '0');
    let s = d.getSeconds().toString().padStart(2, '0');
    return `${y}/${m}/${day} ${h}:${min}:${s}`;
  }

  
  async fetchRecommends(isRefresh: boolean = false) {
    if (!isRefresh) {
      let cached = await PreferenceManager.getString('cache_home', '');
      let time = await PreferenceManager.getString('time_home', '');
      if (cached) {
        try {
          this.recommendGroups = JSON.parse(cached);
          this.isLoading = false;
        } catch(e) {}
      }
      if (time) this.lastUpdateTime = time;
    }

    this.isUpdating = true;
    try {
      let res = await NovelRepository.getRecommends();
      this.recommendGroups = res;
      this.message = '';

      let now = this.getFormattedTime();
      this.lastUpdateTime = now;
      PreferenceManager.putString('cache_home', JSON.stringify(res));
      PreferenceManager.putString('time_home', now);
    } catch (error) {
      if (this.recommendGroups.length === 0) this.message = '网络请求失败或数据异常';
    } finally {
      this.isLoading = false;
      this.isUpdating = false;
    }
  }
}