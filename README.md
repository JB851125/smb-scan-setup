# SMB Scan Setup

> One-click setup for scan-to-folder (SMB) on Windows. Turns a 15-minute manual field procedure into a 2-minute scripted run.

在 Windows 電腦上一鍵完成多功能事務機「掃描至資料夾」所需的全部設定：專用帳號、資料夾權限、網路共用、防火牆與環境檢查。

現場原本需要手動點選十餘個設定畫面，約 15 分鐘；使用本腳本約 2 分鐘完成，且每次設定結果一致。

## 解決什麼問題

事務機掃描至資料夾失敗，九成原因集中在四件事：

- 共用權限與 NTFS 權限只做了一層
- 帳號密碼到期，設定跟著失效
- 防火牆未放行「檔案及印表機共用」
- 電腦處於公用網路，共用被系統擋下

本腳本把這四項一次補齊，並在結尾輸出事務機端需要填寫的資訊。

## 需求

- Windows 10 / 11（家用版亦可）
- 系統管理員權限
- 目的端電腦建議使用有線網路，並固定 IP

## 使用方式

下載後右鍵選「以系統管理員身分執行」：

```
scripts\setup-smb-scan.bat
```

現場無法使用隨身碟時，可於目標電腦直接下載：

```
curl -L -o smb.bat https://raw.githubusercontent.com/JB851125/smb-scan-setup/main/scripts/setup-smb-scan.bat
```

需要調整帳號名稱或資料夾位置時，修改腳本開頭三個變數即可：

```
set "SCAN_USER=scan"
set "FOLDER=C:\Scan"
set "SHARE=Scan"
```

## 腳本做了什麼

| 步驟 | 動作 | 對應指令 |
| --- | --- | --- |
| 1 | 建立掃描專用帳號 | `net user` |
| 2 | 設定密碼永不過期 | `Set-LocalUser` |
| 3 | 建立資料夾並給予 NTFS 修改權限 | `icacls` |
| 4 | 建立網路共用並給予變更權限 | `net share` |
| 5 | 公用網路時詢問是否改為私人網路 | `Set-NetConnectionProfile` |
| 6 | 防火牆放行檔案及印表機共用（僅私人／網域） | `Enable-NetFirewallRule` |
| 7 | 輸出 IP、DHCP 狀態、SMB 版本與設定資訊 | — |

執行結束後會在共用資料夾產生 `_印表機設定資訊.txt`，內含事務機端需填寫的主機路徑與使用者名稱。密碼不會寫入該檔案。

## 事務機端設定

| 欄位 | 填寫內容 |
| --- | --- |
| 通訊協定 | SMB |
| 主機／路徑 | `\\電腦IP\Scan` |
| 使用者名稱 | `電腦名稱\scan` |
| 密碼 | 執行腳本時輸入的密碼 |

Canon 機種的資料夾路徑欄僅需填 `\Scan`，主機名稱欄另外填 IP。

## 已知狀況

- 批次檔從網路下載後，Windows SmartScreen 可能顯示警告，屬正常現象。
- 部分防毒軟體會攔截建立共用或寫入共用資料夾的行為。需要時請將事務機 IP 與掃描資料夾加入信任清單，並由電腦管理者操作。
- 腳本僅處理本機帳號。網域環境的密碼原則由群組原則控管，需由網管人員調整。

## 文件

- [純指令操作手冊](docs/manual-commands.md)：無法執行腳本時，逐行輸入指令的版本
- [除錯對照](docs/troubleshooting.md)：錯誤碼與排查順序

## 免責聲明

本腳本會建立本機帳號、變更資料夾權限、共用設定與防火牆規則。請在取得該電腦管理者同意後使用，並自行評估是否符合所屬組織的資訊安全政策。作者不對使用本腳本造成的任何損失負責。

## 授權

MIT License，詳見 [LICENSE](LICENSE)。
