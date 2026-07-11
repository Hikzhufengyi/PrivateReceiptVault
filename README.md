# PrivateReceiptVault

## 开发日志

### 2026-07-11

Commit: `022b9c3` - `Improve receipt scanning and app privacy flows`

- 重组 iOS 工程目录，将代码按 `App`、`Models`、`Stores`、`Services`、`Security`、`Views`、`Components`、`Integrations` 分类。
- 优化首页：搜索入口回到页面顶部；首页只展示最近收据；统计卡调整为收据、可报销、税务记录；信任标签扩展为私密、AI识别、加密备份、本地离线。
- 优化添加收据流程：扫描入口文案改为拍照导入；扫描结果页固定底部保存按钮；保存前支持重复收据提醒。
- 增强 OCR 识别：改进 AMOUNT、Sub-total、Sales Tax、Balance 等字段解析；增加中文电商订单实付金额识别；修复话费充值账单 `-50.00` 被当作负实付金额的问题。
- 增加本地 AI 理解能力：扫描后自动推断分类、生成备注、判断报销用途，并在扫描结果页展示。
- 优化收据列表：所有收据放到二级页面；支持搜索、分类、报销状态、日期筛选和自定义日期区间；列表标题旁显示当前筛选结果数量和总金额。
- 优化收据详情：支持编辑保存反馈、底部删除、点击原始收据图片放大、双指缩放、下拉关闭；移除用户界面中的 OCR 原文调试信息。
- 完善报销状态：新增不报销、可报销、已报销状态；支持列表筛选和一键标记已报销。
- 强化隐私体验：Face ID / 设备认证锁提升到 App 根层级，进入后台后无论停在哪个页面，回到前台都需要解锁。
- 更新设置页链接：隐私条款改为 `https://getreceiptvault.com/privacy`，技术支持改为 `https://getreceiptvault.com/support`。
