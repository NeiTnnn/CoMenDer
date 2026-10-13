# CoMenDer — Your Local AI Command-Line Coworker

[English](README.md) | [繁體中文](README.zh-TW.md)

> 直接輸入 PowerShell 指令。出錯時取得修正建議，確認後再執行。

CoMenDer 是一個在 Windows 終端機運作的 demo 小產品。它結合 PowerShell 的環境資訊與本地語言模型，協助處理指令名稱、參數和檔名輸入錯誤，減少來回修改指令的操作。

模型透過 **Ollama** 在本機執行，預設使用 **Qwen2.5-Coder 3B**。檔名候選由程式搜尋、排序；指令與參數修正則交給模型。使用者始終負責確認修正是否符合原意。

## 功能

| 功能 | 行為 |
|---|---|
| 自動接上修正流程 | 在 CoMenDer 模式直接輸入指令，失敗時自動處理，不必加 `fix` |
| 指令名稱修正 | 例如 `Get-ChlidItem` → `Get-ChildItem` |
| 參數名稱修正 | 提供合法參數與別名給模型，例如 `-TotalCont` → `-TotalCount` |
| 檔名候選搜尋 | 只搜尋目前資料夾，依檔名編輯距離顯示最多 3 個候選 |
| 使用者選檔 | 明確區分近似與較弱匹配，不直接把候選當作正確答案 |
| 執行前確認 | 顯示原始指令、建議指令與理由，輸入 `y`／`yes` 才執行 |
| 不必要時不呼叫模型 | 正確指令直接完成；檔名搜尋由程式處理 |
| 批次驗證 | 提供測試腳本及 CSV 結果輸出 |

## 執行環境

- Windows 與 Windows PowerShell 5.1；腳本亦以 PowerShell 7 相容語法撰寫，但尚未提供完整跨版本驗證。
- 已安裝並開啟 [Ollama](https://ollama.com/download/windows)。
- 已下載 `qwen2.5-coder:3b`，或其他相容的本地文字模型。
- 不需要額外安裝 Python、Node.js 或 Python 套件。

首次下載模型需要網路。模型下載完成後，這份 demo 的推論請求只送到本機 Ollama；一般指令本身是否連網，仍取決於你輸入的指令。

## 快速開始

### 1. 下載本地模型

安裝 Ollama 後，重新開啟 PowerShell，執行：

```powershell
ollama --version
ollama pull qwen2.5-coder:3b
```

下載完成後，保持 Ollama 開啟。

### 2. 解壓並啟動

完整解壓 `CoMenDer-Demo.zip`，保留資料夾結構。雙擊 `CoMenDer` 資料夾裡的：

```text
Launch-CoMenDer.cmd
```

啟動檔會開啟 Windows PowerShell，顯示模型狀態，並進入附帶的 `demo` 資料夾。

如果希望沿用目前的 PowerShell／Conda 環境，先切換到解壓後的 `CoMenDer` 資料夾，再執行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
Get-ChildItem -Filter *.ps1 | Unblock-File
.\Start-CoMenDer.ps1
```

`Process` 的執行原則調整只影響目前 PowerShell 程序；`Unblock-File` 移除下載來源標記，不會執行腳本或檢查安全性。

### 3. 輸入第一條指令

在 CoMenDer 的輸入提示直接輸入：

```powershell
Get-ChlidItem
```

這條指令故意拼錯。預期流程如下；模型理由可能不同：

```text
Original : Get-ChlidItem
Suggested: Get-ChildItem
Reason   : 指令名稱拼字錯誤。
Run suggested command once? [y/N]:
```

確認建議符合原意後輸入 `y`。直接 Enter 會取消修正。

## 三分鐘 demo 流程

輸入 `/demo`，透過編號選擇案例。每次選案例會切回隨附的 `demo` 資料夾。

| 案例 | 輸入 | 預期展示 |
|---|---|---|
| 1. 指令拼錯 | `Get-ChlidItem` | 本地模型建議改成 `Get-ChildItem`，確認後列出檔案 |
| 2. 檔名拼錯 | `Get-Content .\ntoes.txt -TotalCount 2` | 將 `notes.txt` 列為近似候選，先選檔，再確認指令 |
| 3. 參數拼錯 | `Get-Content .\notes.txt -TotalCont 2` | 參考合法參數名稱，建議 `-TotalCount`，保留數字 `2` |
| 4. 沒有明確匹配 | `Get-Content .\unavailable_document_92847.txt -TotalCount 2` | 顯示較弱的候選，不自動假定使用者意圖；可取消或明確選檔 |
| 5. 正確指令 | `Get-Content .\notes.txt -TotalCount 2` | 直接輸出內容，不呼叫模型 |

展示時可依序說明：輸入錯誤 → 收集本地情境 → 提出建議 → 使用者確認 → 執行一次。

### 檔案選擇示例

```text
找不到指定檔案。以下只是目前資料夾的搜尋候選，請先選擇檔案。
[1] notes.txt (close spelling)
[2] meeting.txt (weak match; may be unrelated)
Select a file number, or Enter to cancel:
```

先輸入編號；接著查看完整指令，輸入 `y` 才會執行。即使是排名第一的候選，也不代表它一定是使用者原本想讀的檔案。

## 操作指令

| 指令 | 用途 |
|---|---|
| `/demo` | 選擇內建展示案例 |
| `/status` | 查看本地模型、Ollama 狀態、目前資料夾與限制 |
| `/models` | 列出已下載的模型 |
| `/model 模型名稱` | 切換本次操作模式使用的模型 |
| `/help` | 查看說明 |
| `/clear` | 清除終端機畫面 |
| `/exit` 或 `exit` | 離開 CoMenDer |
| `cd "資料夾路徑"` | 切換目前資料夾 |

可指定起始資料夾：

```powershell
.\Start-CoMenDer.ps1 -WorkingDirectory "C:\Users\USER\Downloads"
```

也可指定已下載的模型：

```powershell
.\Start-CoMenDer.ps1 -Model "qwen2.5-coder:3b"
```

模型必須先透過 Ollama 下載。更換模型可能影響修正品質、回應格式與速度，需要重新測試。

## 系統如何運作

### 指令／參數錯誤

1. PowerShell 執行原始指令，取得狀態與輸出。
2. 如果失敗，整理指令、輸出尾端、目前位置、部分檔名與相關指令名稱。
3. 對可辨識的 PowerShell 指令，加入實際參數名稱、別名與型態。
4. 透過 `http://127.0.0.1:11434/api/generate` 呼叫本地模型，要求 JSON 格式的修正與理由。
5. 檢查回答格式和 PowerShell 語法，顯示完整建議並要求確認。
6. 使用者同意後執行一次；仍然失敗就停止。

### 檔案不存在

1. 解析支援的讀檔指令，取得文字路徑。
2. 在獨立 PowerShell 子程序中，只列舉目前資料夾的檔案。
3. 計算檔名的編輯距離，依距離與名稱排序，保留最多 3 個候選。
4. 使用者先選檔。程式只替換原指令中的路徑，保留其他參數。
5. 再次確認完整指令後執行。

這個流程不使用模型猜測替代檔名。候選是程式找到的現有檔案，最終選擇由使用者完成。

## 搜尋與等待限制

| 項目 | 設定與行為 |
|---|---|
| 搜尋範圍 | 目前資料夾的檔案；不搜尋子資料夾 |
| 掃描數量 | 最多 5,000 個檔案 |
| 搜尋子程序 | 最多等待 2 秒；啟動與清理可能增加少量時間 |
| 候選數量 | 最多 3 個 |
| 不完整搜尋 | 標示候選只來自已掃描範圍；子程序硬逾時時可能沒有候選 |
| 模型 HTTP 請求 | 30 秒逾時 |
| 執行修正 | 每次最多重跑一次 |

搜尋只讀取檔名，不讀檔案內容。逾時限制針對搜尋與模型請求，**不包含原始指令的執行時間**。

## 測試

在一般 PowerShell 中，切換到專案資料夾執行：

```powershell
.\Test-CommandFix.ps1
```

目前有 10 個行為案例，以及 2 個搜尋邊界案例：

- 指令名稱、帶路徑的指令、參數名稱修正。
- 檔名與含空格路徑的候選選擇。
- 缺少檔案時，要求選擇候選而非自動替換。
- 正確指令不呼叫模型。
- 候選只來自目前資料夾，不包含子資料夾。
- 檔案掃描數量上限。
- 搜尋工作故意停頓時，主程序按逾時返回。

測試在暫存資料夾執行固定的唯讀案例，**不執行模型提出的修正**。結束後會在測試腳本旁產生 `CommandFix-results-時間.csv`，包含案例、預期、實際回答、理由、錯誤與耗時。

重複模型／行為案例三輪：

```powershell
.\Test-CommandFix.ps1 -Repeat 3
```

此時是 10 × 3 個行為案例，加上執行一次的 2 個搜尋邊界案例，共 32 項。

目前使用者已在 Windows 回報 **12／12 通過**，也手動確認過候選選檔與確認執行。這是目前固定案例的結果，不代表所有 PowerShell 指令都能正確修正。新增的 CoMenDer 啟動介面完成靜態檢查，尚待 Windows 實際試跑。

測試中的耗時包含指令執行和搜尋等工作；CoMenDer 顯示的操作耗時也包含使用者確認時間，不能直接當成模型推論速度。

## 專案檔案

| 檔案 | 用途 |
|---|---|
| `Launch-CoMenDer.cmd` | 雙擊啟動 Windows PowerShell demo |
| `Start-CoMenDer.ps1` | 專用指令迴圈、模型狀態、展示選單與快捷操作 |
| `CommandFix.ps1` | 執行指令、收集情境、呼叫模型、搜尋候選與確認修正 |
| `Test-CommandFix.ps1` | 批次行為與搜尋邊界測試 |
| `demo/notes.txt` | 拼字與參數修正的讀檔範例 |
| `demo/meeting.txt` | 第二個檔案候選 |
| `README.md` | 英文版安裝、展示、測試與限制說明 |
| `README.zh-TW.md` | 繁體中文版安裝、展示、測試與限制說明 |

## 資料處理

- 模型請求只送到本機 Ollama，不使用雲端 AI API。
- 模型可收到指令文字、輸出尾端、目前資料夾路徑、部分檔名和指令參數資訊。
- 程式不主動讀檔案內容給模型，也不收集完整指令歷史或環境變數；但指令輸出本身可能包含檔案內容或其他資料。
- 測試會產生本地 CSV。demo 介面沒有額外的遙測或歷史紀錄功能。

## 已知限制

- 這是專用指令迴圈，不會攔截其他既有 PowerShell 視窗。
- 不提供完整 PowerShell 的補全、歷史編輯或持續變數作用域；新定義的變數與函式不保證跨指令保留。
- 輸出先收集再顯示，不適合互動程式、大量持續輸出或長時間任務。
- 檔名候選流程目前支援簡單 `Get-Content`／`cat`／`type`／`gc` 的文字路徑；不處理動態路徑、萬用字元、多檔案與複合語法。
- 有語法檢查和確認提示，但沒有完整的命令沙箱或危險操作封鎖。模型提示規則不能替代程式層級的權限控制。
- 原始指令會先執行；如果部分成功後才失敗，可能已經改變檔案或環境。
- 較慢硬體或模型冷啟動可能超過 30 秒請求上限。

## 常見問題

**找不到 Ollama 或模型**  
開啟 Ollama，在另一個 PowerShell 執行 `ollama --version` 與 `ollama pull qwen2.5-coder:3b`。在 demo 輸入 `/status` 再檢查。

**腳本被執行原則阻擋**  
在自己的專案資料夾使用前述 `Set-ExecutionPolicy -Scope Process Bypass` 與 `Unblock-File` 步驟。組織電腦若有群組原則限制，需遵循該環境的設定。

**測試說找不到 `Get-FixSuggestion`**  
確認同資料夾的 `CommandFix.ps1` 是新版，下載檔沒有變成 `CommandFix (1).ps1`，並已覆蓋舊檔。

**搜尋逾時或找不到候選**  
搜尋可能在檔案多、磁碟慢或子程序啟動較慢時達上限。候選搜尋只涵蓋目前資料夾；可先用 `cd` 切換到正確位置，再重試。

**為什麼檔名修正沒有顯示 Asking local model？**  
檔名搜尋和候選排序由程式處理，選檔後直接替換路徑，不需要模型呼叫。
