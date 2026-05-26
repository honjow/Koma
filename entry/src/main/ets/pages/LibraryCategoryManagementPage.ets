import {
  Comic,
  CustomLibraryCategory,
  LIBRARY_CATEGORY_FAVORITE_ID,
  LIBRARY_CATEGORY_NAME_MAX_LENGTH,
  LIBRARY_CATEGORY_READ_LATER_ID,
} from '../model/ComicModels'
import {
  LibraryCategoryDisplayCategoryId,
  LibraryCategoryDisplayStrategy,
  LibraryReadStateFilter,
  LibrarySortBy,
  LibraryStore,
} from '../model/LibraryStore'
import {
  LibraryStorePersistenceService,
  createCustomCategoryAndPersistLibraryStore,
  deleteCustomCategoryAndPersistLibraryStore,
  moveCustomCategoryAndPersistLibraryStore,
  renameCustomCategoryAndPersistLibraryStore,
  setCategoryDisplayStrategyAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct LibraryCategoryManagementPage {
  libraryStore?: LibraryStore
  libraryPersistenceService?: LibraryStorePersistenceService
  onLibraryChanged: () => void = () => {}
  @State private categories: CustomLibraryCategory[] = []
  @State private draftName: string = ''
  @State private editingCategoryId: string = ''
  @State private editingName: string = ''

  private refreshCategories(): void {
    this.categories = this.libraryStore === undefined ? [] : this.libraryStore.listCustomCategories()
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_error) {
    }
  }

  private categoryStrategy(categoryId: LibraryCategoryDisplayCategoryId): LibraryCategoryDisplayStrategy {
    const strategy = this.libraryStore?.getCategoryDisplayStrategy(categoryId)
    if (strategy !== undefined) {
      return strategy
    }
    return {
      categoryId,
      sortBy: 'lastRead',
      readState: 'all',
      updatedAt: 0,
    }
  }

  private sortLabel(sortBy: LibrarySortBy): string {
    if (sortBy === 'added') {
      return '最近加入'
    }
    if (sortBy === 'title') {
      return '标题'
    }
    if (sortBy === 'source') {
      return '来源'
    }
    return '最近阅读'
  }

  private readStateLabel(readState: LibraryReadStateFilter): string {
    if (readState === 'unread') {
      return '未读'
    }
    if (readState === 'reading') {
      return '读过'
    }
    if (readState === 'completed') {
      return '已完成'
    }
    return '全部状态'
  }

  private persistCategoryStrategy(
    categoryId: LibraryCategoryDisplayCategoryId,
    sortBy: LibrarySortBy,
    readState: LibraryReadStateFilter
  ): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast('分类管理不可用')
      return
    }
    try {
      setCategoryDisplayStrategyAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, {
        categoryId,
        sortBy,
        readState,
        updatedAt: Date.now(),
      })
      this.onLibraryChanged()
      this.showToast('显示方式已更新')
    } catch (_error) {
      this.showToast('显示方式未保存')
    }
  }

  private setCategorySort(categoryId: LibraryCategoryDisplayCategoryId, sortBy: LibrarySortBy): void {
    const strategy = this.categoryStrategy(categoryId)
    this.persistCategoryStrategy(categoryId, sortBy, strategy.readState)
  }

  private setCategoryReadState(categoryId: LibraryCategoryDisplayCategoryId, readState: LibraryReadStateFilter): void {
    const strategy = this.categoryStrategy(categoryId)
    this.persistCategoryStrategy(categoryId, strategy.sortBy, readState)
  }

  private persistCreate(): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast('分类管理不可用')
      return
    }
    try {
      createCustomCategoryAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, this.draftName)
      this.draftName = ''
      this.refreshCategories()
      this.onLibraryChanged()
      this.showToast('分类已创建')
    } catch (error) {
      const e = error as Error
      this.showToast(e.message)
    }
  }

  private startRename(category: CustomLibraryCategory): void {
    this.editingCategoryId = category.id
    this.editingName = category.name
  }

  private cancelRename(): void {
    this.editingCategoryId = ''
    this.editingName = ''
  }

  private persistRename(categoryId: string): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast('分类管理不可用')
      return
    }
    try {
      renameCustomCategoryAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, categoryId, this.editingName)
      this.cancelRename()
      this.refreshCategories()
      this.onLibraryChanged()
      this.showToast('分类已重命名')
    } catch (error) {
      const e = error as Error
      this.showToast(e.message)
    }
  }

  private confirmDelete(category: CustomLibraryCategory): void {
    this.getUIContext().showAlertDialog({
      title: '删除分类',
      message: `删除“${category.name}”？该分类会从已有漫画中移除，收藏和稍后阅读不受影响。`,
      autoCancel: true,
      primaryButton: {
        value: '删除',
        fontColor: $r('app.color.koma_danger'),
        action: () => {
          this.persistDelete(category.id)
        },
      },
      secondaryButton: {
        value: '取消',
        action: () => {},
      },
    })
  }

  private persistDelete(categoryId: string): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast('分类管理不可用')
      return
    }
    try {
      if (deleteCustomCategoryAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, categoryId)) {
        this.refreshCategories()
        this.onLibraryChanged()
        this.showToast('分类已删除')
      }
    } catch (error) {
      const e = error as Error
      this.showToast(e.message)
    }
  }

  @Builder
  private CategorySortMenu(categoryId: LibraryCategoryDisplayCategoryId) {
    Menu() {
      MenuItem({ content: '最近阅读' })
        .onClick(() => {
          this.setCategorySort(categoryId, 'lastRead')
        })
      MenuItem({ content: '最近加入' })
        .onClick(() => {
          this.setCategorySort(categoryId, 'added')
        })
      MenuItem({ content: '标题' })
        .onClick(() => {
          this.setCategorySort(categoryId, 'title')
        })
      MenuItem({ content: '来源' })
        .onClick(() => {
          this.setCategorySort(categoryId, 'source')
        })
    }
  }

  @Builder
  private CategoryReadStateMenu(categoryId: LibraryCategoryDisplayCategoryId) {
    Menu() {
      MenuItem({ content: '全部状态' })
        .onClick(() => {
          this.setCategoryReadState(categoryId, 'all')
        })
      MenuItem({ content: '未读' })
        .onClick(() => {
          this.setCategoryReadState(categoryId, 'unread')
        })
      MenuItem({ content: '读过' })
        .onClick(() => {
          this.setCategoryReadState(categoryId, 'reading')
        })
      MenuItem({ content: '已完成' })
        .onClick(() => {
          this.setCategoryReadState(categoryId, 'completed')
        })
    }
  }

  @Builder
  private StrategyRow(categoryId: LibraryCategoryDisplayCategoryId, title: string) {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('打开分类时自动使用')
          .fontSize(13)
          .fontColor($r('app.color.koma_text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Button(this.sortLabel(this.categoryStrategy(categoryId).sortBy))
        .height(36)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .fontSize(14)
        .fontColor($r('app.color.koma_text_primary'))
        .backgroundColor('#0F000000')
        .bindMenu(this.CategorySortMenu(categoryId))
      Button(this.readStateLabel(this.categoryStrategy(categoryId).readState))
        .height(36)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .fontSize(14)
        .fontColor($r('app.color.koma_text_primary'))
        .backgroundColor('#0F000000')
        .bindMenu(this.CategoryReadStateMenu(categoryId))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private DisplayStrategySection() {
    Column({ space: 10 }) {
      Text('分类显示方式')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      this.StrategyRow('all', '全部分类')
      this.StrategyRow('uncategorized', '未分类')
      this.StrategyRow(LIBRARY_CATEGORY_FAVORITE_ID, '收藏')
      this.StrategyRow(LIBRARY_CATEGORY_READ_LATER_ID, '稍后阅读')
      ForEach(this.categories, (category: CustomLibraryCategory) => {
        this.StrategyRow(category.id, category.name)
      }, (category: CustomLibraryCategory) => category.id)
    }
    .width('100%')
  }

  private persistMove(categoryId: string, direction: 'up' | 'down'): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast('分类管理不可用')
      return
    }
    try {
      if (moveCustomCategoryAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, categoryId, direction)) {
        this.refreshCategories()
        this.onLibraryChanged()
        this.showToast('分类顺序已更新')
      }
    } catch (error) {
      const e = error as Error
      this.showToast(e.message)
    }
  }

  private isFirstCategory(category: CustomLibraryCategory): boolean {
    return this.categories.length > 0 && this.categories[0].id === category.id
  }

  private isLastCategory(category: CustomLibraryCategory): boolean {
    return this.categories.length > 0 && this.categories[this.categories.length - 1].id === category.id
  }

  private categoryUsageCount(categoryId: string): number {
    if (this.libraryStore === undefined) {
      return 0
    }
    return this.libraryStore.listComics().filter((comic: Comic): boolean => {
      return comic.categoryIds !== undefined && comic.categoryIds.includes(categoryId)
    }).length
  }

  @Builder
  private CreateCard() {
    Column({ space: 12 }) {
      Text('新建分类')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Row({ space: 10 }) {
        TextInput({ placeholder: `最多 ${LIBRARY_CATEGORY_NAME_MAX_LENGTH} 个字符`, text: this.draftName })
          .height(42)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.draftName = value
          })
        Button('创建')
          .height(42)
          .padding({ left: 16, right: 16 })
          .borderRadius(8)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.koma_accent'))
          .onClick(() => {
            this.persistCreate()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private CategoryRow(category: CustomLibraryCategory) {
    Column({ space: 10 }) {
      if (this.editingCategoryId === category.id) {
        TextInput({ text: this.editingName })
          .width('100%')
          .height(42)
          .onChange((value: string) => {
            this.editingName = value
          })
        Row({ space: 10 }) {
          Button('保存')
            .height(36)
            .padding({ left: 14, right: 14 })
            .borderRadius(8)
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.koma_accent'))
            .onClick(() => {
              this.persistRename(category.id)
            })
          Button('取消')
            .height(36)
            .padding({ left: 14, right: 14 })
            .borderRadius(8)
            .fontSize(14)
            .fontColor($r('app.color.koma_text_primary'))
            .backgroundColor('#0F000000')
            .onClick(() => {
              this.cancelRename()
            })
        }
        .width('100%')
      } else {
        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text(category.name)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.koma_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${this.categoryUsageCount(category.id)} 本漫画`)
              .fontSize(13)
              .fontColor($r('app.color.koma_text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Button('上移')
            .height(36)
            .padding({ left: 12, right: 12 })
            .borderRadius(8)
            .fontSize(14)
            .fontColor($r('app.color.koma_text_primary'))
            .backgroundColor('#0F000000')
            .enabled(!this.isFirstCategory(category))
            .opacity(this.isFirstCategory(category) ? 0.45 : 1)
            .onClick(() => {
              this.persistMove(category.id, 'up')
            })
          Button('下移')
            .height(36)
            .padding({ left: 12, right: 12 })
            .borderRadius(8)
            .fontSize(14)
            .fontColor($r('app.color.koma_text_primary'))
            .backgroundColor('#0F000000')
            .enabled(!this.isLastCategory(category))
            .opacity(this.isLastCategory(category) ? 0.45 : 1)
            .onClick(() => {
              this.persistMove(category.id, 'down')
            })
          Button('重命名')
            .height(36)
            .padding({ left: 12, right: 12 })
            .borderRadius(8)
            .fontSize(14)
            .fontColor($r('app.color.koma_text_primary'))
            .backgroundColor('#0F000000')
            .onClick(() => {
              this.startRename(category)
            })
          Button('删除')
            .height(36)
            .padding({ left: 12, right: 12 })
            .borderRadius(8)
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.koma_danger'))
            .onClick(() => {
              this.confirmDelete(category)
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private EmptyCard() {
    Text('暂无自定义分类')
      .width('100%')
      .fontSize(15)
      .fontColor($r('app.color.koma_text_secondary'))
      .textAlign(TextAlign.Center)
      .padding({ left: 16, right: 16, top: 24, bottom: 24 })
      .borderRadius(8)
      .backgroundColor($r('app.color.koma_card'))
  }

  aboutToAppear(): void {
    this.refreshCategories()
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 14,
        horizontalPadding: 20,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
      }) {
        ListItem() {
          this.DisplayStrategySection()
        }
        ListItem() {
          this.CreateCard()
        }
        if (this.categories.length === 0) {
          ListItem() {
            this.EmptyCard()
          }
        } else {
          ForEach(this.categories, (category: CustomLibraryCategory) => {
            ListItem() {
              this.CategoryRow(category)
            }
          }, (category: CustomLibraryCategory) => category.id)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
