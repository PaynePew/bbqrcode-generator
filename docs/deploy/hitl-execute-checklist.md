# HITL 執行清單(照打版)— `bii` GeoLite2 + `ebf` CloudFront/OAC

> 這是「坐下來照做」的精簡版。每步的**理由 / 來源 / 替代方案**見同目錄的
> [`hitl-runbook-geoip-and-cloudfront.md`](./hitl-runbook-geoip-and-cloudfront.md)。
> 兩件都是 PRD `qr_code_generator-ba6` 的 human-in-the-loop slice。
>
> **順序建議**:先做 Part A(`bii`)→ 它解鎖 AFK slice `15l`(掃描記錄)。
> Part B(`ebf`)已解鎖(`mrv` 已合併),可獨立進行。

---

## 先記下這些值(填完再往下)

```
# MaxMind（Part A）
ACCOUNT_ID      = __________
LICENSE_KEY     = __________

# AWS / CloudFront（Part B）—— 既有事實，通常不用改
S3_BUCKET       = qrgen-customized-prod
S3_REGION       = ap-northeast-1
AWS_ACCOUNT     = 489990873558
# 建立 distribution 後填回：
DIST_DOMAIN     = __________.cloudfront.net
DIST_ID         = __________
```

---

## Part A — 地理來源 GeoLite2-City · bd `bii`

> 把掃描者 IP 在 ingest 當下轉成粗略 `country` + `subdivision`(縣市/州省級),**轉完即丟原始 IP 與 city**(ADR 0016，2026-06-12 修訂)。
> 用 **City** edition(不是 Country)——subdivision 只存在於 City DB;city 本身衍生即丟、不落地。
> `device_class` 不屬於這片(純 UA-parser pip 套件，無外部資料)→ **無需動作**。

- [ ] **1. 註冊 MaxMind(免費)** → https://www.maxmind.com/en/geolite2/signup
- [ ] **2. 產生 license key** → https://www.maxmind.com/en/accounts/current/license-key →
      *Generate New License Key*。被問 *"Will this key be used for GeoIP Update?"* 選 **Yes**。
      把 **Account ID** 與 **License Key** 填到上面。
- [ ] **3. 取得 `GeoLite2-City.mmdb`**(建議用 `geoipupdate`，順便保持更新):
      ```bash
      # 安裝 geoipupdate（macOS: brew install geoipupdate / Ubuntu: apt install geoipupdate）
      sudo tee /etc/GeoIP.conf >/dev/null <<'EOF'
      AccountID <ACCOUNT_ID>
      LicenseKey <LICENSE_KEY>
      EditionIDs GeoLite2-City
      EOF
      sudo geoipupdate            # 寫到 DatabaseDirectory（預設 /usr/share/GeoIP/）
      ls -l /usr/share/GeoIP/GeoLite2-City.mmdb
      ```
      (手動替代:account → *Download Files* → **GeoLite2 City** → 解壓 `.tar.gz` 取 `.mmdb`。City DB 約 60 MB+,比 Country 大。)
- [ ] **4. 設定 app 讀取路徑**(本片的 config 產出):
      ```
      GEOIP_DB_PATH=/usr/share/GeoIP/GeoLite2-City.mmdb
      ```
      dev 與 prod 都要可達(bundle 進映像，或 deploy 時 `geoipupdate` 抓)。
- [ ] **5. 加套件**:`geoip2` 寫進 `requirements.txt`(AFK slice `15l` 開 `geoip2.database.Reader(GEOIP_DB_PATH)`,用 `reader.city(ip)` 取 `country.iso_code` + `subdivisions.most_specific`,**忽略** `resp.city`)。
- [ ] **6. 自動更新**(EULA 要求:新版發布後 30 天內刪舊檔)→ 設 **每週 cron** 跑 `geoipupdate`:
      ```bash
      # 例：每週一 03:17 更新
      echo '17 3 * * 1 root /usr/bin/geoipupdate' | sudo tee /etc/cron.d/geoipupdate
      ```
- [ ] **7. 標示歸屬**(EULA 要求)→ 在 About/footer 放一行
      *"This product includes GeoLite2 data created by MaxMind, available from https://www.maxmind.com"*
      (歸 Phase 7 前端，這裡先記著即可)。
- [ ] **8. 完成 → 關 bead**:
      ```bash
      bd close qr_code_generator-bii --reason="GeoLite2-City chosen (country+subdivision, city discarded); mmdb at GEOIP_DB_PATH; weekly geoipupdate cron; geoip2 added"
      bd github push qr_code_generator-bii
      ```
      ✅ 這會解鎖 AFK slice `15l`。之後可再跑 slice-orchestrator 自動接 `15l`。

---

## Part B — CloudFront + OAC 罩在 composite bucket 前 · bd `ebf`(已解鎖)

> 用 OAC 的 CloudFront 罩 `qrgen-customized-prod`，把 bucket 改私有(只准 CloudFront 讀)，
> app 透過 `CDN_BASE_URL` 出 CloudFront 圖片網址。**只罩圖片 bucket，絕不罩 app/redirect**(302 不可被 CDN 快取，ADR 0017)。
> 前置已滿足:bucket Object Ownership = *Bucket owner enforced*(OAC 需求)。

- [ ] **1. 建立 distribution**(CloudFront → *Create distribution*):
      - **Origin domain** = `qrgen-customized-prod.s3.ap-northeast-1.amazonaws.com`
        ⚠️ 用 **REST** endpoint,**不要** S3 *website* endpoint(OAC 不支援 website endpoint)。
      - **Origin access** → **Origin access control settings** → *Create control setting*:
        名稱 `qrgen-composites-oac`、**Origin type = S3**、**Signing behavior = Sign requests**。
      - **Viewer protocol policy** = *Redirect HTTP to HTTPS*;**Allowed methods** = `GET, HEAD`。
      - **Cache policy** = **CachingOptimized**(會尊重來源的 `Cache-Control: public, max-age=31536000, immutable`,版本化 key 永久邊緣快取、免 invalidation)。
      - **Default root object** 留空。
      - **Create** → 把 **distribution domain** 與 **distribution ID** 填到上面。
- [ ] **2. 換 bucket policy 成「只准這個 CloudFront」**(S3 → bucket → *Permissions* → *Bucket policy* → *Edit*)。
      把 `<DIST_ID>` 換成你的 distribution ID;`Resource` 只放 composite 前綴(logo 維持私有):
      ```json
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Sid": "AllowCloudFrontServicePrincipalReadOnly",
            "Effect": "Allow",
            "Principal": { "Service": "cloudfront.amazonaws.com" },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::qrgen-customized-prod/qr/*/composite_*",
            "Condition": {
              "StringEquals": {
                "AWS:SourceArn": "arn:aws:cloudfront::489990873558:distribution/<DIST_ID>"
              }
            }
          }
        ]
      }
      ```
- [ ] **3. 把 bucket 改私有** → *Permissions* → **Block Public Access** 開 **ON**,並**移除**舊的
      `PublicReadComposites` 公開 statement。(app 的 IAM user `qrgen-app` 不受影響——Block Public Access 只擋匿名,不擋 IAM 認證的上傳/私有 logo 讀取。)
- [ ] **4. 接上 app** → deploy env 設(`storage.url_for` 會用它):
      ```
      CDN_BASE_URL=https://<DIST_DOMAIN>
      ```
      重新部署。(沒設時 app 退回直連 S3 URL,所以 `mrv` 早就能先上線測試。)
- [ ] **5. 驗證**:
      ```bash
      # 200 via CloudFront
      curl -I https://<DIST_DOMAIN>/qr/<token>/composite_<uuid>.png
      # 403 直連 S3（已私有）
      curl -I https://qrgen-customized-prod.s3.ap-northeast-1.amazonaws.com/qr/<token>/composite_<uuid>.png
      ```
      再確認 app 的 `GET /api/qr/{token}/image`(已自訂的 Link)**302 到 CloudFront URL**。
- [ ] **6. 完成 → 關 bead**:
      ```bash
      bd close qr_code_generator-ebf --reason="CloudFront+OAC fronting qrgen-customized-prod; bucket private; CDN_BASE_URL set; verified 200 via CF / 403 direct S3"
      bd github push qr_code_generator-ebf
      ```

> 自訂網域 `cdn.qrcode.paynepew.dev` **延後**(需 us-east-1 ACM 憑證 + platform-owned DNS;反正藏在 app 302 後面)。預設 `*.cloudfront.net` 就夠。

---

## 兩件都完成後

- `15l`(掃描記錄)依賴 `bii` → 解鎖;`6bk`/`ba6` 在 `15l` 之後依序解鎖。
- 回來跑 `slice-orchestrator`(`autoMerge:true`)就會自動接力做下游 AFK slice。
