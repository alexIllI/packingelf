# PackingElf

- [安裝說明](docs/INSTALLATION.md)
- [測試說明](docs/TESTING.md)

## Client 如何連到 Host

當 `Host` 安裝在另一台電腦時，請先在 `Host` 電腦打開 **包貨小精靈 Host**，然後查看畫面上的 **主機網址**。

![Host 主機網址](docs/images/host_address_on_host_app.png)

接著在 `Client` 電腦打開 **設定**，切到 **Host 連線** 分頁，把剛剛看到的網址填進 `Host URL`，再輸入 `Host` 顯示的 `Pairing Token`，最後按 **儲存並測試**。

![Client Host 連線設定](docs/images/host_address_on_client_app.png)

建議：

- 優先使用 `http://192.168.x.x:48080` 這種區網 IP
- 不要先用 `127.0.0.1`，那只代表目前這台電腦自己
- 如果測試失敗，請先確認 `Host` 電腦的 Windows Firewall 已放行 TCP `48080`

### 如何在 host 電腦放行 Windows Firewall 的入站 TCP 48080

最直接的做法:

在 host 電腦用系統管理員權限打開 PowerShell，執行：

```bash
New-NetFirewallRule -DisplayName "PackingElf Host 48080" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 48080
```

或者透過 GUI 的做法：

1. 在 host 電腦按 Win，搜尋 Windows Defender 防火牆 with Advanced Security
2. 打開後，左邊點 Inbound Rules
3. 右邊點 New Rule...
4. 選 Port
5. 選 TCP
6. Specific local ports 輸入： `48080`
7. 下一步選 Allow the connection
8. Domain / Private / Public
   - 如果是你自己的辦公室或家用網路，至少勾 Private
   - 如果不確定，可以三個都勾，但會比較寬鬆
9. 名稱輸入：`PackingElf Host 48080`
10. 完成
