import { curves } from '@kit.ArkUI';
import router from '@ohos.router';
import { NovelItem } from '../models/DataModels';
import { PreloadEngine } from '../utils/PreloadEngine';
import { Constants } from '../common/Constants';
import { T2SEngine } from '../utils/T2SEngine';

@Component
export struct NovelCard {
  @Prop item: NovelItem;
  @StorageLink('autoSimp') autoSimp: boolean = true;

  build() {
    Row() {
      Image(this.item.pic_url)
        .width(80)
        .height(110)
        .objectFit(ImageFit.Cover)
        .borderRadius(10)
        .backgroundColor(Constants.PLACEHOLDER_BG)
        .border({ width: 0.5, color: 'rgba(0,0,0,0.05)' })
        .sharedTransition(this.item.pic_url, { duration: 350, curve: curves.springMotion() })

      Column() {
        Text(this.autoSimp ? T2SEngine.convert(this.item.title) : this.item.title)
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).lineHeight(24).letterSpacing(0.5)

        Blank()
        Row() {
          if (this.item.action_type === 2) {
            Text('合集')
              .fontSize(10).fontColor(Color.White).backgroundColor(Constants.THEME_COLOR)
              .padding(4).borderRadius(4).margin({ right: 6 })
          }

          if (this.item.parent_group_name) {
            Text(this.autoSimp ? T2SEngine.convert(this.item.parent_group_name) : this.item.parent_group_name)
              .fontSize(11).fontWeight(FontWeight.Medium).fontColor(Constants.THEME_COLOR)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(Constants.THEME_TINT_BG).borderRadius(6).margin({ right: 10 })
          }
          if (this.item.hits !== undefined) {
            Row() {
              SymbolGlyph($r('sys.symbol.eye')).fontSize(14).fontColor([Constants.TEXT_SECONDARY]).margin({ right: 4 })
              Text(`${this.item.hits}`).fontSize(12).fontColor(Constants.TEXT_SECONDARY)
            }
          }
        }
        .width('100%').alignItems(VerticalAlign.Center)
      }
      .height(110).alignItems(HorizontalAlign.Start).margin({ left: 16 }).layoutWeight(1).padding({ top: 4, bottom: 4 })
    }
    .padding(16).width('100%').backgroundColor(Constants.CARD_BG_COLOR)
    .borderRadius(20).border({ width: 1, color: 'rgba(0,0,0,0.02)' })
    .shadow({ radius: 24, color: 'rgba(0,0,0,0.03)', offsetY: 8 })
    .stateStyles({
      pressed: { .scale({ x: 0.97, y: 0.97 }).opacity(0.9) },
      normal: { .scale({ x: 1, y: 1 }).opacity(1) }
    })
    .animation({ curve: curves.interpolatingSpring(10, 1, 228, 30) })
    .onAppear(() => {
      if (this.item.action_type === 1 && typeof this.item.action_params === 'number') {
        
        PreloadEngine.enqueue(this.item.action_params, 1);
      }
    })
    .onClick(() => {
      if (this.item.action_type === 1 && typeof this.item.action_params === 'number') {
        
        router.pushUrl({ url: 'pages/ArticleDetail', params: { aid: this.item.action_params, tag: this.item.parent_group_name } }).catch(()=>{});
      } else if (this.item.action_type === 2 && typeof this.item.action_params === 'number') {
        router.pushUrl({ url: 'pages/CollectionDetailView', params: { sid: this.item.action_params, title: this.item.title } }).catch(()=>{});
      }
    })
  }
}


@Component
export struct NovelCardGrid {
  @Prop item: NovelItem;
  @StorageLink('autoSimp') autoSimp: boolean = true;

  build() {
    Column() {
      
      Stack() {
        Image(this.item.pic_url)
          .width('100%').height('100%')
          .objectFit(ImageFit.Cover)
          .backgroundColor(Constants.PLACEHOLDER_BG)

        
        if (this.item.action_type === 2) {
          Text('合集')
            .fontSize(9).fontColor(Color.White).fontWeight(FontWeight.Bold)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .backgroundColor(Constants.THEME_COLOR)
            .borderRadius({ topLeft: 0, topRight: 8, bottomLeft: 8, bottomRight: 0 })
            .position({ right: 0, top: 0 })
        }
      }
      .width('100%').aspectRatio(0.75)
      .borderRadius({ topLeft: 12, topRight: 12, bottomLeft: 0, bottomRight: 0 })
      .clip(true)

      
      Column() {
        Text(this.autoSimp ? T2SEngine.convert(this.item.title) : this.item.title)
          .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(18).width('100%')

        Blank()

        Row() {
          if (this.item.parent_group_name) {
            Text(this.autoSimp ? T2SEngine.convert(this.item.parent_group_name) : this.item.parent_group_name)
              .fontSize(9).fontColor(Constants.THEME_COLOR)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Blank()
          if (this.item.hits !== undefined && this.item.hits > 0) {
            Text(`${this.item.hits}`).fontSize(9).fontColor(Constants.TEXT_SECONDARY)
          }
        }.width('100%').alignItems(VerticalAlign.Center)
      }
      .width('100%').padding({ left: 8, right: 8, top: 6, bottom: 8 })
      .height(64).alignItems(HorizontalAlign.Start)
    }
    .width('100%').backgroundColor(Constants.CARD_BG_COLOR)
    .borderRadius(12).border({ width: 0.5, color: 'rgba(0,0,0,0.04)' })
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.04)', offsetY: 4 })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onAppear(() => {
      if (this.item.action_type === 1 && typeof this.item.action_params === 'number') {
        PreloadEngine.enqueue(this.item.action_params, 1);
      }
    })
    .onClick(() => {
      if (this.item.action_type === 1 && typeof this.item.action_params === 'number') {
        router.pushUrl({ url: 'pages/ArticleDetail', params: { aid: this.item.action_params, tag: this.item.parent_group_name } }).catch(()=>{});
      } else if (this.item.action_type === 2 && typeof this.item.action_params === 'number') {
        router.pushUrl({ url: 'pages/CollectionDetailView', params: { sid: this.item.action_params, title: this.item.title } }).catch(()=>{});
      }
    })
  }
}