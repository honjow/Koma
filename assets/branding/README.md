# Koma 品牌图形

当前采用三层翻页式 K：水平收口、中央细连接，应用图标沿用已选 B 比例。

- `app-icon-foreground.svg`：1024 × 1024 透明白色图标前景，对应 `entry/src/main/resources/base/media/app_icon_emerald_solid_foreground.png`。背景继续使用原 emerald PNG。
- `startup-foreground-light.svg` / `startup-foreground-dark.svg`：1024 × 1024 透明启动资源，对应 `base/media/startup_foreground.png` 与 `dark/media/startup_foreground.png`；浅色 `#37A48B`，深色 `#5CC8A8`。
- `logo-light.svg` / `logo-dark.svg`：同字形的紧边透明 Logo，供独立使用。

SVG 是可编辑母版。PNG 以 SVG 的原始尺寸导出，保留透明度；不额外裁切、缩放或添加效果。启动图与图标共用字形；首轮实机反馈首屏过小后，启动资源内的字形改为原始路径尺寸（高度524px），比首轮0.60缩放放大约1.67倍。
