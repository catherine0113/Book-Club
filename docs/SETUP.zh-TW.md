# 本機開發與服務設定

目前先本機開發，不需要購買網域或部署 Vercel。主辦人為 `sonderme13@gmail.com`；主辦人 Email 與寄件地址是兩個不同設定。

## 現在可以執行

```sh
npm ci --cache /tmp/book-club-npm
npm test
npm run dev
```

`npm test` 包含配對測試與 PGlite PostgreSQL 資料庫測試：不需 Supabase、Docker 或金鑰，不會寄出郵件。資料只存在該次測試的記憶體中。網站的實際報名、管理員登入仍需下列服務；目前沒有假登入或假報名成功。

本機 `.env.local` 已加入主辦人 Email 與 `APP_URL=http://localhost:3000`，此檔案被 Git 忽略。若在其他電腦使用，從 `.env.example` 建立，保留已有的本機設定，不要覆寫已填入的金鑰。

## 1. 建立 Supabase

1. 建立一個開發用 Supabase 專案，選擇合適區域，妥善保存資料庫密碼。網站目前不使用資料庫連線密碼。
2. 在 SQL Editor 執行一次 `supabase/schema.sql`。這是建立初始結構的腳本，不可在已有資料的專案重跑；未來變更需用 migration。
3. 確認有以下四張表：

| 表格 | 用途 |
| --- | --- |
| `events` | 活動時間、地點、截止時間、名額、費用、禮物預算與狀態 |
| `participants` | 報名資料、書籍、願望與私人修改 token |
| `gift_matches` | 送禮者與收禮者、郵件發送狀態 |
| `match_restrictions` | 雙向禁止配對關係，可先留空 |

四張表皆啟用 RLS，前端沒有直接讀取資料的 policy。三個 RPC `register_participant`、`edit_participant`、`save_matches` 只允許伺服器 service_role 呼叫。不需要為 anon 開放表格或 RPC 權限。

4. 腳本已加入一筆範例活動；此版僅支援單一活動。到 Table Editor 修改這筆資料，不要另建第二筆。日期預設 2026/12/19 14:00–18:00（台北），截止 12/10，50 人、費用 0、禮物 NT$1,000–1,500 都是可修改的範例值；請確認正式地點、費用與名額。
5. 在 Authentication 的使用者管理建立 Email/Password 使用者 `sonderme13@gmail.com`，設定自己的密碼並確認 Email。使用管理介面建立，不開放前台註冊。關閉公開使用者註冊；現有主辦人仍可登入。
6. Auth URL Configuration 的本機 Site URL 設為 `http://localhost:3000`。現有密碼登入不需 OAuth callback，也不需 Google/LINE provider。
7. 在專案 API 設定取得 Project URL、anon key 和 service_role key。此版使用這組傳統 API keys；不要以資料庫密碼代替。service_role key 只放伺服器環境變數。

## 2. 填入環境變數

填入 `.env.local` 或雲端的安全環境變數設定，勿貼到對話、Git 或截圖。

| 變數 | 內容 | 是否敏感 |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase Project URL | 否 |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase anon key | 可供瀏覽器使用，RLS 必須保留 |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service_role key | **是，僅伺服器** |
| `ADMIN_EMAIL` | `sonderme13@gmail.com` | 否 |
| `APP_URL` | 本機先填 `http://localhost:3000` | 否 |
| `RESEND_API_KEY` | Resend API key | **是，僅伺服器** |
| `EMAIL_FROM` | Resend 允許的寄件地址 | 否 |

變更後重啟 `npm run dev`。正式部署時再換成正式 `APP_URL`，不需現在決定網域。

## 3. 建立 Resend

1. 註冊 Resend 並建立用於此專案的 API key，填入 `RESEND_API_KEY`。
2. 尚未有網域時，可使用 Resend 提供的測試寄件地址（通常為 `onboarding@resend.dev`，以帳戶實際允許值為準）填入 `EMAIL_FROM`。測試模式通常只允許寄到該 Resend 帳戶自己的已驗證 Email；不要用其他人的信箱測試。
3. `sonderme13@gmail.com` 可以是收件信箱或 Resend 帳戶 Email，但不能直接當成已驗證自有網域的寄件地址。將來正式寄信時，加入自己的網域，依 Resend 指示設定 DNS（SPF/DKIM 等），驗證成功後再修改 `EMAIL_FROM`。
4. 未設定寄信時，可先測 Supabase 寫入與登入。報名會保存，但畫面會明確說明確認信未寄出，請保留私人修改連結。

Supabase Auth 的管理員密碼登入與 Resend 的活動通知是兩套功能。第一版不需先替 Supabase Auth 設定 Resend SMTP；若之後要正式使用重設密碼/驗證信，可再配置 Auth 郵件服務。

## 4. 服務連接後驗收

- 新增一筆自己的測試報名，確認 Table Editor 的資料與書籍/Wishlist 正確。
- 確認成功頁私人修改連結可修改同一筆資料，重複 Email 不新增第二筆。
- 到 `/admin/login` 使用上述主辦人帳號登入，確認統計、搜尋及篩選。
- 在獨立開發專案準備至少兩筆測試報名，產生配對並預覽；生成不會自動寄信。確認無自己配自己，且參與資格不能再更動。
- 寄信測試只使用自己控制且服務允許的信箱。測試寄件模式受收件人限制；要完整測試兩位參加者的投遞，需服務允許的測試信箱或已驗證寄件網域。
- 明確按 Send 後檢查實際收件匣、私人修改連結、通知狀態與失敗重試。

PGlite 測試不代表正式 Supabase Auth、PostgREST、網路或 Resend 投遞已通過；這些需在服務建立後驗證。
