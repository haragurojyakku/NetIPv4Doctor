# NetIPv4Doctor

「pingは通るのに、Webやゲームランチャーだけ`connect timed out`になる」という、
IPv4 over IPv6(MAP-E系: v6プラス/transix/OCNバーチャルコネクト/クロスパス等)の
トンネル障害を検知して、自動修復を試みる簡単なツールです。

> **この機能は DeskAssistant にも取り込まれています。**
> 常駐アプリ [DeskAssistant](https://github.com/haragurojyakku/DeskAssistant) の
> 「ネットワーク」タブに、ここと同じ判定・修復手順を Python で移植したものが入っています。
> 普段使いはそちら（自動監視・トレイからのワンクリック診断が付きます）、
> このリポジトリは単体で持ち出せる版として残しています。

## 背景

SyncLauncherが `Failed to fetch https://launchermeta.mojang.com/... HTTP connect timed out`
で失敗した際に調査したところ、次のパターンが確認されました。

- IPv4のTCP接続(443番等)はすべて失敗(Mojang・Google・GitHubなど、宛先を問わず)
- IPv4のping(ICMP)は成功
- IPv6のTCP接続は正常

これは、フレッツ光などのIPv6 IPoE + IPv4 over IPv6方式で、ルーター(ホームゲートウェイ)側の
IPv4トンネルセッションだけが壊れたときに典型的に出る症状です。PC側の設定(ファイアウォール・
Winsock・ドライバ)には原因が見当たらず、直すには基本的に**ルーターの再起動**が必要でした。

## できること

1. **検知** - IPv4 TCP / IPv4 ping / IPv6 TCPをそれぞれ調べ、上記のパターンに一致するか判定
2. **軽い自動修復** - DNSキャッシュのクリア、IPv4リースの再取得(release/renew)
3. **アダプタ再起動**(管理者権限がある場合のみ)
4. それでも直らなければ、**ルーターの再起動が必要である旨を通知**し、ルーターの管理画面
   (`http://<デフォルトゲートウェイ>`)を自動で開きます

**PCの再起動は一切行いません。** ルーター自体の電源を入れ直す操作も自動化していません
(認証情報が必要かつ機種依存のため)。あくまで「PC側で直せる範囲を試し、ダメなら
ルーター再起動が必要だとはっきり教える」ツールです。

## 使い方

| ファイル | 用途 | 管理者権限 |
|---|---|---|
| `Check-NetIPv4.bat` | 今の状態を見るだけ(何も変更しない) | 不要 |
| `Run-NetIPv4Doctor.bat` | 検知→自動修復→ダメならルーター再起動を案内 | 必要(実行時にUAC確認あり) |
| `NetIPv4Doctor.exe` | 上の2本をまとめた単体exe(下記のオプション) | 既定は必要(自動でUAC) |

ダブルクリックで実行してください。結果は画面表示に加え、`logs/netipv4doctor.log` に
タイムスタンプ付きで記録されます。

### exe版のオプション

```
NetIPv4Doctor.exe            管理者権限に昇格して自動修復まで行う(Run-NetIPv4Doctor.bat 相当)
NetIPv4Doctor.exe --check    昇格せずチェックのみ(Check-NetIPv4.bat 相当)
NetIPv4Doctor.exe --silent   無人実行(ブラウザもダイアログも出さない。タスクスケジューラ用)
NetIPv4Doctor.exe --no-open-router-page  ルーター管理画面を自動で開かない
```

exeはPowerShell本体を同梱しません。中に`.ps1`だけを埋め込み、実行時に
`%LOCALAPPDATA%/NetIPv4Doctor/scripts` へ取り出してWindows標準の`powershell.exe`へ渡します
(exeの隣に`.ps1`が揃っている場合はそちらを優先し、従来どおりの場所へログを書きます)。

## ファイル構成

```
_NetIPv4Doctor/
  Check-NetIPv4.bat        クイックチェック起動用(ダブルクリック)
  Run-NetIPv4Doctor.bat    自動修復起動用(ダブルクリック、管理者権限を要求)
  Check-Ipv4Health.ps1     チェック本体
  Fix-Ipv4Tunnel.ps1       自動修復本体
  Ipv4HealthCore.ps1       判定ロジック(共通関数)
  netipv4doctor.py         exe版のエントリポイント
  assets/                  exeのアイコン
  logs/                    実行ログ
```

## ビルド

配布物は`release/`に出します(`build/`・`release/`・`.spec`はリポジトリに含めません)。

```
py -m venv .venv
.venv/Scripts/pip install pyinstaller
.venv/Scripts/pyinstaller --noconfirm --onefile --console ^
  --name NetIPv4Doctor --icon assets/NetIPv4Doctor.ico ^
  --add-data "Ipv4HealthCore.ps1;." ^
  --add-data "Check-Ipv4Health.ps1;." ^
  --add-data "Fix-Ipv4Tunnel.ps1;." ^
  --distpath release --workpath build/_work --specpath build ^
  netipv4doctor.py
```

## 補足

- 定期監視(タスクスケジューラへの登録)はデフォルトでは行っていません。常時監視したい場合は
  `Fix-Ipv4Tunnel.ps1 -Silent` (ポップアップ・ブラウザ起動なし、ログのみ)をタスクスケジューラに
  管理者権限で登録してください。exe版なら`NetIPv4Doctor.exe --silent`でも同じです。
  DeskAssistantの「ネットワーク」タブを使う場合は、そちらの自動監視で足ります。
- Windows PowerShell 5.1 (Windows 11標準) で動作確認済みです。追加のインストールは不要です。
