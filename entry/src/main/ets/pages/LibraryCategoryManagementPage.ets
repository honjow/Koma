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
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider, SectionHeader } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaDisclosureListRow } from '../components/ui/KomaDisclosureListRow'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { KomaMenuListRow } from '../components/ui/KomaMenuListRow'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct LibraryCategoryManagementPage {
  @Param libraryStore?: LibraryStore = undefined
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}
  @Local private categories: CustomLibraryCategory[] = []
  @Local private draftName: string = ''
  @Local private editingCategoryId: string = ''
  @Local private editingName: string = ''
  @Local private categoryMenuKey: string = ''
  @Local private expandedStrategyCategoryId: LibraryCategoryDisplayCategoryId = 'all'

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
    this.categoryMenuKey = ''
  }

  private setCategoryReadState(categoryId: LibraryCategoryDisplayCategoryId, readState: LibraryReadStateFilter): void {
    const strategy = this.categoryStrategy(categoryId)
    this.persistCategoryStrategy(categoryId, strategy.sortBy, readState)
    this.categoryMenuKey = ''
  }

  private strategyMenuKey(categoryId: LibraryCategoryDisplayCategoryId, kind: string): string {
    return `${categoryId}:${kind}`
  }

  private categoryActionMenuKey(categoryId: string): string {
    return `${categoryId}:actions`
  }

  private categoryStrategySummary(categoryId: LibraryCategoryDisplayCategoryId): string {
    const strategy = this.categoryStrategy(categoryId)
    return `${this.sortLabel(strategy.sortBy)} · ${this.readStateLabel(strategy.readState)}`
  }

  private toggleStrategyExpansion(categoryId: LibraryCategoryDisplayCategoryId): void {
    this.expandedStrategyCategoryId = this.expandedStrategyCategoryId === categoryId ? '' : categoryId
    this.categoryMenuKey = ''
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
    this.categoryMenuKey = ''
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
        if (this.expandedStrategyCategoryId === categoryId) {
          this.expandedStrategyCategoryId = 'all'
        }
        this.categoryMenuKey = ''
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
  private StrategySummaryRow(categoryId: LibraryCategoryDisplayCategoryId, title: string) {
    KomaDisclosureListRow({
      title,
      subtitle: this.categoryStrategySummary(categoryId),
      isExpanded: this.expandedStrategyCategoryId === categoryId,
      toggle: () => {
        this.toggleStrategyExpansion(categoryId)
      },
    }) {
      KomaMenuListRow({
        title: '默认排序',
        trailingText: this.sortLabel(this.categoryStrategy(categoryId).sortBy),
        trailingDropdown: true,
        showChevron: false,
        isMenuOpen: this.categoryMenuKey === this.strategyMenuKey(categoryId, 'sort'),
        action: () => {
          this.categoryMenuKey = this.strategyMenuKey(categoryId, 'sort')
        },
      }) {
        this.CategorySortMenu(categoryId)
      }
      ListDivider()
      KomaMenuListRow({
        title: '阅读状态',
        trailingText: this.readStateLabel(this.categoryStrategy(categoryId).readState),
        trailingDropdown: true,
        showChevron: false,
        isMenuOpen: this.categoryMenuKey === this.strategyMenuKey(categoryId, 'read'),
        action: () => {
          this.categoryMenuKey = this.strategyMenuKey(categoryId, 'read')
        },
      }) {
        this.CategoryReadStateMenu(categoryId)
      }
    }
  }

  @Builder
  private DisplayStrategySection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      SectionHeader({ title: '分类显示' })
      GroupedListSection() {
        this.StrategySummaryRow('all', '全部分类')
        ListDivider()
        this.StrategySummaryRow('uncategorized', '未分类')
        ListDivider()
        this.StrategySummaryRow(LIBRARY_CATEGORY_FAVORITE_ID, '收藏')
        ListDivider()
        this.StrategySummaryRow(LIBRARY_CATEGORY_READ_LATER_ID, '稍后阅读')
        if (this.categories.length > 0) {
          ListDivider()
        }
        ForEach(this.categories, (category: CustomLibraryCategory, index: number) => {
          this.StrategySummaryRow(category.id, category.name)
          if (index < this.categories.length - 1) {
            ListDivider()
          }
        }, (category: CustomLibraryCategory) => category.id)
      }
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
  private CategoryActionMenu(category: CustomLibraryCategory) {
    Menu() {
      MenuItem({ content: '重命名' })
        .onClick(() => {
          this.startRename(category)
        })
      MenuItem({ content: '上移' })
        .enabled(!this.isFirstCategory(category))
        .onClick(() => {
          this.persistMove(category.id, 'up')
        })
      MenuItem({ content: '下移' })
        .enabled(!this.isLastCategory(category))
        .onClick(() => {
          this.persistMove(category.id, 'down')
        })
      MenuItem({ content: '删除' })
        .onClick(() => {
          this.confirmDelete(category)
        })
    }
  }

  @Builder
  private CustomCategoriesSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      SectionHeader({ title: '自定义分类' })
      GroupedListSection() {
        if (this.categories.length === 0) {
          ConciseListRow({
            title: '暂无自定义分类',
            showChevron: false,
          })
        } else {
          ForEach(this.categories, (category: CustomLibraryCategory, index: number) => {
            this.CategoryRow(category)
            if (index < this.categories.length - 1) {
              ListDivider()
            }
          }, (category: CustomLibraryCategory) => category.id)
        }
      }
    }
    .width('100%')
  }

  @Builder
  private CreateSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      SectionHeader({ title: '新建分类' })
      GroupedListSection({ inset: ThemeConstants.SPACE_LG }) {
        Column({ space: ThemeConstants.SPACE_MD }) {
          KomaFormTextField({
            label: '分类名称',
            placeholder: `最多 ${LIBRARY_CATEGORY_NAME_MAX_LENGTH} 个字符`,
            value: this.draftName,
            submit: () => {
              this.persistCreate()
            },
            change: (value: string) => {
              this.draftName = value
            },
          })
          KomaActionButton({
            label: '创建',
            kind: 'primary',
            fullWidth: true,
            isEnabled: this.draftName.trim().length > 0,
            action: () => {
              this.persistCreate()
            },
          })
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private CategoryRow(category: CustomLibraryCategory) {
    if (this.editingCategoryId === category.id) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        KomaFormTextField({
          label: '分类名称',
          value: this.editingName,
          submit: () => {
            this.persistRename(category.id)
          },
          change: (value: string) => {
            this.editingName = value
          },
        })
        Row({ space: ThemeConstants.SPACE_MD }) {
          KomaActionButton({
            label: '保存',
            kind: 'primary',
            fill: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            action: () => {
              this.persistRename(category.id)
            },
          })
          KomaActionButton({
            label: '取消',
            kind: 'secondary',
            fill: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            action: () => {
              this.cancelRename()
            },
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    } else {
      KomaMenuListRow({
        title: category.name,
        subtitle: `${this.categoryUsageCount(category.id)} 本漫画`,
        isMenuOpen: this.categoryMenuKey === this.categoryActionMenuKey(category.id),
        action: () => {
          this.categoryMenuKey = this.categoryActionMenuKey(category.id)
        },
      }) {
        this.CategoryActionMenu(category)
      }
    }
  }

  aboutToAppear(): void {
    this.refreshCategories()
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_LG,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
      }) {
        ListItem() {
          this.DisplayStrategySection()
        }
        ListItem() {
          this.CustomCategoriesSection()
        }
        ListItem() {
          this.CreateSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
