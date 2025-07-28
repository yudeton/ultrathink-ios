# UltraThink - 智能工作日誌生成器

## 項目概述

UltraThink 是一款功能強大的iOS應用程式，旨在自動化收集和分析您的日常工作數據，並生成智能工作日誌。該應用整合了多個平台和服務，包括GitHub、Gmail、Obsidian、自動打卡系統等，利用AI技術為您提供深度的工作洞察和自動化的日誌生成。

## 主要功能

### 🔄 自動化數據收集
- **Git活動追蹤**: 自動收集每日的GitHub commit記錄
- **郵件智能分析**: 整合Gmail API，分析重要工作郵件
- **筆記同步**: 與Obsidian連接，同步當日筆記修改
- **自動打卡**: 基於地理位置的智能打卡系統

### 🤖 AI驅動分析
- **智能日誌生成**: 使用GPT-4自動生成專業工作日誌
- **工作模式分析**: 提供個人化的效率改進建議
- **會議摘要**: 自動整理會議記錄和重點

### 📋 任務管理
- **智能任務追蹤**: 完整的任務管理系統
- **Deadline監控**: 自動提醒即將到期的任務
- **優先級管理**: 多層次優先級和分類系統

### 🔗 N8N自動化工作流
- **事件觸發**: 基於工作事件的自動化流程
- **定時執行**: 定期執行數據同步和分析
- **自定義工作流**: 靈活的工作流配置

## 技術架構

### 前端技術
- **SwiftUI**: 現代化的iOS用戶界面
- **Combine**: 響應式程式設計框架
- **Core Data**: 本地數據持久化

### 後端整合
- **RESTful API**: 標準化的API接口
- **OAuth 2.0**: 安全的第三方服務認證
- **Core Location**: 地理位置和地理圍欄

### AI整合
- **OpenAI GPT-4**: 智能文本生成和分析
- **自然語言處理**: 郵件和文檔智能分析

### 自動化平台
- **n8n**: 工作流自動化和數據同步
- **Webhook**: 即時事件觸發

## 項目結構

```
UltraThink/
├── UltraThink/
│   ├── UltraThinkApp.swift          # 應用程式入口
│   ├── ContentView.swift            # 主界面
│   ├── PersistenceController.swift  # Core Data控制器
│   ├── Services/                    # 服務層
│   │   ├── APIService.swift         # 基礎API服務
│   │   ├── GitHubService.swift      # GitHub整合
│   │   ├── GmailService.swift       # Gmail整合
│   │   ├── ObsidianService.swift    # Obsidian整合
│   │   ├── AttendanceService.swift  # 打卡服務
│   │   ├── TaskManagerService.swift # 任務管理
│   │   ├── AIAnalysisService.swift  # AI分析服務
│   │   └── N8NService.swift         # N8N工作流
│   ├── Models/                      # 數據模型
│   │   └── ConfigurationManager.swift
│   └── DataModel.xcdatamodeld/      # Core Data模型
└── README.md
```

## 安裝和配置

### 1. 系統要求
- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

### 2. 第三方服務配置

#### GitHub API
1. 在GitHub創建Personal Access Token
2. 在應用設置中配置Token和用戶名

#### Gmail API
1. 在Google Cloud Console創建項目
2. 啟用Gmail API
3. 配置OAuth 2.0憑證

#### Obsidian REST API
1. 安裝Obsidian REST API插件
2. 配置本地API訪問端口

#### OpenAI API
1. 獲取OpenAI API密鑰
2. 在應用中配置API訪問

#### N8N工作流
1. 設置N8N實例
2. 創建Webhook端點
3. 配置自動化工作流

### 3. 編譯和運行
```bash
# 克隆項目
git clone [project-url]

# 打開Xcode項目
open UltraThink.xcodeproj

# 配置Bundle Identifier和簽名
# 編譯並運行到設備
```

## 使用指南

### 初次設置
1. 開啟應用並進入設置頁面
2. 按順序配置各項服務的API密鑰
3. 設置辦公室位置（用於自動打卡）
4. 測試各項服務連接

### 日常使用
1. **自動數據收集**: 應用會在後台自動收集工作數據
2. **查看儀表板**: 主頁面顯示今日工作摘要
3. **生成工作日誌**: 點擊"生成工作日誌"按鈕
4. **任務管理**: 添加和管理日常任務
5. **查看分析**: 獲取AI生成的工作效率建議

### 自動化功能
- **地理圍欄打卡**: 到達/離開辦公室自動打卡
- **定時數據同步**: 每小時同步一次數據
- **智能提醒**: 任務截止日期和重要事件提醒

## 開發路線圖

### 已完成功能 ✅
- [x] iOS專案基礎架構
- [x] GitHub API整合
- [x] Gmail API整合
- [x] Obsidian API串接
- [x] 自動打卡系統
- [x] 任務管理系統
- [x] AI分析功能
- [x] N8N自動化工作流

### 計劃功能 📋
- [ ] 數據可視化界面
- [ ] Apple Watch應用
- [ ] Siri快捷指令整合
- [ ] 更多第三方服務整合
- [ ] 團隊協作功能
- [ ] 數據導出功能

## 教學內容規劃

本項目適合製作成完整的iOS開發教學系列：

1. **基礎篇**: SwiftUI基礎和項目架構
2. **API整合篇**: RESTful API調用和數據處理
3. **數據持久化篇**: Core Data實戰應用
4. **定位服務篇**: Core Location和地理圍欄
5. **AI整合篇**: OpenAI API整合和智能分析
6. **自動化篇**: N8N工作流設計和整合
7. **優化篇**: 性能優化和用戶體驗提升

## 注意事項

### 隱私和安全
- 所有API密鑰均存儲在設備本地
- 支持Face ID/Touch ID解鎖敏感功能
- 數據傳輸使用HTTPS加密

### 法律合規
- 自動打卡功能需符合當地勞動法規
- 郵件分析需要適當的授權
- 數據收集遵循GDPR和相關隱私法規

## 貢獻指南

歡迎提交Issue和Pull Request來改進這個項目。請確保：
1. 代碼遵循Swift編碼規範
2. 提交前進行充分測試
3. 更新相關文檔

## 授權

本項目採用MIT授權，詳見LICENSE文件。

## 聯繫方式

如有問題或建議，請通過以下方式聯繫：
- GitHub Issues: [項目Issues頁面]
- Email: [聯繫郵箱]

---

**UltraThink** - 讓工作更智能，讓思考更深入