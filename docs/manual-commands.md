# 純指令操作手冊

無法使用隨身碟或下載腳本時，在目標電腦逐行輸入指令，效果等同 `setup-smb-scan.bat`。

## 前置確認

- 已取得電腦管理者同意建立 `scan` 專用帳號
- 具備本機系統管理員權限
- 目的端電腦建議使用有線網路並固定 IP

以下指令中的 `scan`、`C:\Scan`、`Scan` 可依現場替換；`密碼` 請換成實際密碼，避開 `& % ^ ! |` 等符號。

## 開啟系統管理員 CMD

1. 按 Win 鍵，輸入 `cmd`
2. 右鍵「命令提示字元」→ 以系統管理員身分執行
3. 視窗標題出現「系統管理員」才算成功

確認權限：

```
net session
```

沒有出現「拒絕存取」即為管理員權限。

## 六個步驟

### 1. 建立 scan 帳號

```
net user scan 密碼 /add
```

不想讓密碼顯示在畫面，改打 `net user scan * /add`，會要求輸入兩次。帳號已存在只要改密碼：`net user scan 密碼`。

驗證：`net user scan`，看到帳戶資訊即成功。

### 2. 密碼永不過期

```
powershell -Command "Set-LocalUser -Name 'scan' -PasswordNeverExpires $true"
```

舊版 Windows 10 也可用 `wmic useraccount where "Name='scan'" set PasswordExpires=false`。注意 `net user /expires:never` 是帳號不過期，不是密碼，兩者不同。

驗證：`net user scan`，「密碼到期日」顯示「從不」。

### 3. 建資料夾與 NTFS 修改權限

```
mkdir C:\Scan
icacls "C:\Scan" /grant "scan:(OI)(CI)M"
```

`M` 為修改權限（讀、寫、刪）；`(OI)(CI)` 讓子檔案與子資料夾繼承。

驗證：`icacls "C:\Scan"`，清單中出現 `scan:(OI)(CI)(M)`。

### 4. 建立網路共用與變更權限

```
net share Scan=C:\Scan /grant:scan,CHANGE
```

共用已存在會報錯，先刪再建：`net share Scan /delete /y`。

共用權限與 NTFS 權限取較嚴格者生效，步驟 3、4 缺一不可。這是掃描失敗最常見的原因。

驗證：`net share Scan`，權限欄出現 `scan, CHANGE`。

### 5. 網路類型改為私人

先查看目前狀態：

```
powershell -Command "Get-NetConnectionProfile"
```

`NetworkCategory` 顯示 `Public` 時改為私人：

```
powershell -Command "Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq 'Public' } | Set-NetConnectionProfile -NetworkCategory Private"
```

顯示 `Private` 或 `DomainAuthenticated` 時跳過此步驟。

### 6. 防火牆放行檔案及印表機共用

```
powershell -Command "Get-NetFirewallRule -Group '@FirewallAPI.dll,-28502' | Where-Object { $_.Profile -match 'Private|Domain' } | Enable-NetFirewallRule"
```

事務機是主動連入電腦的 TCP 445 埠，Windows 防火牆預設阻擋輸入連線，未放行會直接連不上。此處僅開放私人與網域設定檔，公用網路維持關閉。

驗證：從同網段另一台裝置 ping 這台電腦的 IP，有回應即正常。

## 環境檢查

設定完成後記錄以下三項，事務機端會用到。

| 項目 | 指令 | 判讀 |
| --- | --- | --- |
| 電腦名稱 | `hostname` | 填入事務機使用者名稱前綴 |
| IP 與 DHCP | `ipconfig /all` | 「已啟用 DHCP：是」代表 IP 可能變動 |
| SMB 版本 | `powershell -Command "Get-SmbServerConfiguration \| Select EnableSMB1Protocol,EnableSMB2Protocol"` | SMB2 應為 True |

DHCP 為「是」時，請於路由器設定 DHCP 保留，或改用事務機本身的儲存空間作為掃描目的地。

## 事務機端填寫

| 欄位 | 填寫內容 |
| --- | --- |
| 通訊協定 | SMB |
| 主機 | 電腦 IP |
| 資料夾路徑 | `\Scan`（部分機種需填完整路徑 `\\電腦IP\Scan`） |
| 使用者名稱 | `電腦名稱\scan` |
| 密碼 | 建立帳號時設定的密碼 |

儲存後執行連線測試，通過再實際掃描一份文件確認。

## 手機備忘錄版

整段複製到手機，現場在系統管理員 CMD 逐行貼上；第一行的密碼先改掉。

```
net user scan 密碼 /add
powershell -Command "Set-LocalUser -Name 'scan' -PasswordNeverExpires $true"
mkdir C:\Scan
icacls "C:\Scan" /grant "scan:(OI)(CI)M"
net share Scan=C:\Scan /grant:scan,CHANGE
powershell -Command "Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq 'Public' } | Set-NetConnectionProfile -NetworkCategory Private"
powershell -Command "Get-NetFirewallRule -Group '@FirewallAPI.dll,-28502' | Where-Object { $_.Profile -match 'Private|Domain' } | Enable-NetFirewallRule"
hostname
ipconfig
```

最後兩行印出的電腦名稱與 IP，即為事務機端需填寫的資料。

## 復原

客戶要求移除設定時：

```
net share Scan /delete /y
net user scan /delete
```

資料夾 `C:\Scan` 與其中檔案不會被刪除，需要時請由電腦使用者自行處理。
