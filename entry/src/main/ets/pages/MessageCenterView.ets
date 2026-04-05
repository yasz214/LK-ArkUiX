import router from '@ohos.router';
import { Constants } from '../common/Constants';
import { NovelRepository } from '../repository/NovelRepository';
import { ReplyMessageItem, SysMessageItem, GuildMessageItem } from '../models/DataModels';
import { T2SEngine } from '../utils/T2SEngine';
import { curves } from '@kit.ArkUI';

@Entry
@Component
struct MessageCenterView {
  @StorageLink('autoSimp') autoSimp: boolean = true;
  @State currentTab: number = 0;
  
  @State indicatorPos: number = 0;
  @State tabBarWidth: number = 360;
  @State replyMessages: ReplyMessageItem[] = [];
  @State sysMessages: SysMessageItem[] = [];
  @State guildMessages: GuildMessageItem[] = [];
  @State isLoading: boolean = true;
  private swiperController: SwiperController = new SwiperController();

  aboutToAppear() {
    this.loadMessages();
  }

  async loadMessages() {
    this.isLoading = true;

    
    try {
      let replyRes = await NovelRepository.getReplyMessages();
      this.replyMessages = replyRes.list || [];
    } catch (e) {
      console.error('加载评论消息失败:', JSON.stringify(e));
    }

    try {
      let sysRes = await NovelRepository.getSysMessages();
      this.sysMessages = sysRes.list || [];
    } catch (e) {
      console.error('加载系统通知失败:', JSON.stringify(e));
    }

    try {
      let guildRes = await NovelRepository.getGuildMessages();
      this.guildMessages = guildRes.list || [];
    } catch (e) {
      console.error('加载工会消息失败:', JSON.stringify(e));
    }

    this.isLoading = false;
  }

  private displayText(text: string): string {
    return this.autoSimp ? T2SEngine.convert(text) : text;
  }

  
  private formatRelativeTime(timeStr: string): string {
    if (!timeStr) return '';
    try {
      let timestamp = Date.parse(timeStr.replace(/-/g, '/'));
      if (isNaN(timestamp)) return timeStr;
      let now = Date.now();
      let diffMs = now - timestamp;
      if (diffMs < 0) return '刚刚';

      let diffMin = Math.floor(diffMs / 60000);
      if (diffMin < 1) return '刚刚';
      if (diffMin < 60) return `${diffMin}分钟前`;

      let diffHour = Math.floor(diffMin / 60);
      if (diffHour < 24) return `${diffHour}小时前`;

      let diffDay = Math.floor(diffHour / 24);
      if (diffDay < 30) return `${diffDay}天前`;

      return timeStr.split(' ')[0];
    } catch (e) {
      return timeStr;
    }
  }

  
  private isTabActive(index: number): boolean {
    return Math.round(this.indicatorPos) === index;
  }

  @Builder TabButton(title: string, index: number, count: number) {
    Column() {
      Row() {
        Text(title)
          .fontSize(15)
          .fontWeight(this.isTabActive(index) ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.isTabActive(index) ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY)
          .animation({ duration: 200 })
        if (count > 0) {
          Text(` ${count}`)
            .fontSize(11).fontColor(Color.White).fontWeight(FontWeight.Bold)
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .borderRadius(8).backgroundColor('#FF3B30')
            .margin({ left: 4 })
        }
      }
    }
    .layoutWeight(1).height('100%').justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentTab = index;
      this.swiperController.changeIndex(index);
    })
  }

  
  @Builder ReplyList() {
    if (this.isLoading) {
      Column() {
        LoadingProgress().width(40).height(40).color(Constants.THEME_COLOR)
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.replyMessages.length === 0) {
      Column() {
        Text("暂无评论消息").fontSize(15).fontColor(Constants.TEXT_SECONDARY)
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else {
      List({ space: 8 }) {
        ForEach(this.replyMessages, (item: ReplyMessageItem) => {
          ListItem() {
            Row() {
              if (item.avatar) {
                Image(item.avatar).width(40).height(40).borderRadius(20).objectFit(ImageFit.Cover)
                  .margin({ right: 12 })
              } else {
                Row() {
                  Text(item.nickname.substring(0, 1)).fontSize(16).fontColor(Color.White).fontWeight(FontWeight.Bold)
                }
                .width(40).height(40).borderRadius(20).backgroundColor(Constants.THEME_COLOR)
                .justifyContent(FlexAlign.Center).margin({ right: 12 })
              }
              Column() {
                Row() {
                  Text(item.nickname).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  Blank()
                  Text(this.formatRelativeTime(item.time)).fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                }.width('100%')

                Text(this.displayText(item.content))
                  .fontSize(14).fontColor(Constants.TEXT_PRIMARY)
                  .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 4 })

                if (item.title) {
                  Text(`回复: ${this.displayText(item.title)}`)
                    .fontSize(12).fontColor(Constants.TEXT_SECONDARY)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 4 })
                    .padding({ left: 8, top: 4, bottom: 4 })
                    .backgroundColor(Constants.THEME_TINT_BG).borderRadius(4)
                }
              }.layoutWeight(1)
            }
            .width('100%').padding(14).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(14)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
            .onClick(() => {
              if (item.aid > 0) {
                router.pushUrl({ url: 'pages/ArticleDetail', params: { aid: item.aid } }).catch(() => {});
              }
            })
          }
        }, (item: ReplyMessageItem) => `reply_${item.id}`)

        ListItem() { Row().height(80) }
      }
      .width('100%').height('100%').padding({ left: 16, right: 16, top: 8 })
      .scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
    }
  }

  
  @Builder SysList() {
    if (this.isLoading) {
      Column() {
        LoadingProgress().width(40).height(40).color(Constants.THEME_COLOR)
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.sysMessages.length === 0) {
      Column() {
        Text("暂无系统通知").fontSize(15).fontColor(Constants.TEXT_SECONDARY)
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else {
      List({ space: 8 }) {
        ForEach(this.sysMessages, (item: SysMessageItem) => {
          ListItem() {
            Column() {
              Row() {
                if (item.is_read === 0) {
                  Row().width(8).height(8).borderRadius(4).backgroundColor('#FF3B30').margin({ right: 8 })
                }
                Text(this.displayText(item.title))
                  .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.formatRelativeTime(item.time)).fontSize(11).fontColor(Constants.TEXT_SECONDARY)
              }.width('100%')

              Text(this.displayText(item.content))
                .fontSize(14).fontColor(Constants.TEXT_SECONDARY)
                .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 6 })
            }
            .width('100%').padding(14).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(14)
          }
        }, (item: SysMessageItem) => `sys_${item.id}`)

        ListItem() { Row().height(80) }
      }
      .width('100%').height('100%').padding({ left: 16, right: 16, top: 8 })
      .scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
    }
  }

  
  @Builder GuildList() {
    if (this.isLoading) {
      Column() {
        LoadingProgress().width(40).height(40).color(Constants.THEME_COLOR)
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.guildMessages.length === 0) {
      Column() {
        Text("暂无工会消息").fontSize(15).fontColor(Constants.TEXT_SECONDARY)
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else {
      List({ space: 8 }) {
        ForEach(this.guildMessages, (item: GuildMessageItem) => {
          ListItem() {
            Row() {
              if (item.avatar) {
                Image(item.avatar).width(40).height(40).borderRadius(20).objectFit(ImageFit.Cover)
                  .margin({ right: 12 })
              } else {
                Row() {
                  Text(item.nickname.substring(0, 1)).fontSize(16).fontColor(Color.White).fontWeight(FontWeight.Bold)
                }
                .width(40).height(40).borderRadius(20).backgroundColor('#FF8C00')
                .justifyContent(FlexAlign.Center).margin({ right: 12 })
              }
              Column() {
                Row() {
                  Text(item.nickname).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  Blank()
                  Text(this.formatRelativeTime(item.time)).fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                }.width('100%')

                Text(this.displayText(item.content))
                  .fontSize(14).fontColor(Constants.TEXT_PRIMARY)
                  .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 4 })
              }.layoutWeight(1)
            }
            .width('100%').padding(14).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(14)
          }
        }, (item: GuildMessageItem) => `guild_${item.id}`)

        ListItem() { Row().height(80) }
      }
      .width('100%').height('100%').padding({ left: 16, right: 16, top: 8 })
      .scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
    }
  }

  build() {
    Column() {
      
      Row() {
        Row() { Text("❮").fontSize(22).fontWeight(FontWeight.Bolder).fontColor(Constants.TEXT_PRIMARY).margin({ top: -2 }) }
        .width(44).height(44).justifyContent(FlexAlign.Center).margin({ left: 8 })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => router.back())

        Text("消息中心").fontSize(20).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
          .layoutWeight(1).padding({ right: 52 }).textAlign(TextAlign.Center)
      }
      .width('100%').height(64).padding({ top: 20 })

      
      Stack({ alignContent: Alignment.BottomStart }) {
        
        Row().width('33.3%').height(3).borderRadius(2).backgroundColor(Constants.THEME_COLOR)
          .translate({ x: `${this.indicatorPos * 100}%` })
          .animation({ duration: 350, curve: curves.springMotion(0.32, 0.78) })

        Row() {
          this.TabButton('评论', 0, this.replyMessages.length)
          this.TabButton('系统通知', 1, this.sysMessages.length)
          this.TabButton('工会大厅', 2, this.guildMessages.length)
        }.width('100%').height('100%')
      }
      .width('100%').height(48)
      .onAreaChange((_: Area, newArea: Area) => {
        let w = newArea.width;
        if (typeof w === 'number') {
          this.tabBarWidth = w;
        }
      })

      
      
      Swiper(this.swiperController) {
        this.ReplyList()
        this.SysList()
        this.GuildList()
      }
      .index(this.currentTab)
      .indicator(false)
      .loop(false)
      .cachedCount(2)
      .layoutWeight(1)
      .duration(300)
      
      .onGestureSwipe((index: number, extraInfo: TabsAnimationEvent) => {
        let progress = extraInfo.currentOffset / this.tabBarWidth;
        this.indicatorPos = index - progress;
      })
      .onAnimationStart((_: number, targetIndex: number) => {
        this.currentTab = targetIndex;
        animateTo({ duration: 350, curve: curves.springMotion(0.35, 0.8) }, () => {
          this.indicatorPos = targetIndex;
        });
      })
      .onChange((index: number) => {
        this.currentTab = index;
        this.indicatorPos = index;
      })
    }
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
