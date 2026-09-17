# سامانه‌ی پاسخگویی و ثبت‌نام دبستان هدف بابلسر

سامانه‌ای در n8n که به‌طور هم‌زمان از تلگرام و یک صفحه‌ی وب پیام می‌گیرد، هر دو را به یک
منطق مشترک (WF-CORE) وصل می‌کند و بدون هیچ نود هوش مصنوعی، با درخت منو و تطبیق کلیدواژه،
پاسخ می‌دهد، ثبت‌نام می‌گیرد و تیکت می‌سازد.

## ساختار پروژه

```
schema.sql                 ساخت جدول‌ها و ایندکس‌ها
workflows/
  wf-core.json              هسته‌ی منطق مشترک (Execute Workflow Trigger)
  wf-web.json                دریافت پیام از صفحه‌ی وب (Webhook)
  wf-telegram.json           دریافت و پاسخ در تلگرام
  wf-sla.json                یادآوری/هشدار SLA + گزارش هفتگی
web/
  index.html                 صفحه‌ی وب مستقل (بدون build)
nocodb/
  docker-compose.yml          اجرای NocoDB
  .env.example                نمونه‌ی متغیرهای محیطی NocoDB
  restricted_role.sql         نقش محدود Postgres برای NocoDB (فقط faq و settings)
TESTING.md                    چک‌لیست تست دستی
```

## پیش‌نیازها

- PostgreSQL ۱۴ به بالا، روی همان سروری که n8n روی آن اجرا می‌شود.
- n8n (نسخه‌ی خودمیزبان)، با دسترسی به همان PostgreSQL.
- یک ربات تلگرام (از BotFather).
- Docker و Docker Compose برای NocoDB.

## ۱) ساخت پایگاه‌داده

```bash
createdb hadaf_school
psql -d hadaf_school -f schema.sql
psql -d hadaf_school -f hadaf-school-content.sql
```

اجرای مجدد `hadaf-school-content.sql` بی‌خطر است (`ON CONFLICT ... DO UPDATE`) — همان‌طور که در
خودِ فایل هم نوشته شده، مدیر هر بار متن را عوض کرد، همین فایل را دوباره اجرا کند.

جدول‌های `students` و `staff` را باید دفتر مدرسه به‌صورت دستی (یا با یک اسکریپت جدا) پر کند؛
این پروژه چیزی برای این دو جدول درج نمی‌کند. حداقل کاری که باید قبل از راه‌اندازی انجام شود:

```sql
-- نمونه: افزودن چند عضو دفتر برای مسیریابی تیکت و اعلان‌ها
INSERT INTO staff (name, telegram_chat_id, category) VALUES
  ('مدیر مدرسه', '<chat_id تلگرام مدیر>', 'مدیر'),
  ('مسئول مالی', '<chat_id>', 'مالی'),
  ('مسئول آموزشی', '<chat_id>', 'آموزشی'),
  ('مسئول انضباطی', '<chat_id>', 'انضباطی'),
  ('مسئول مرخصی', '<chat_id>', 'مرخصی'),
  ('مسئول سایر امور', '<chat_id>', 'سایر');

-- نمونه: افزودن دانش‌آموز و کد رهگیری برای ولی
INSERT INTO students (name, grade, class, parent_phone, unique_code) VALUES
  ('علی رضایی', 'دوم', 'دوم-الف', '09120000000', '1234');
```

برای گرفتن `chat_id` هر عضو دفتر: کافی است آن شخص یک پیام به ربات بدهد و شما آن را از
`getUpdates` بات یا از اجرای آزمایشی WF-TELEGRAM بخوانید.

## ۲) ساخت ربات تلگرام

۱. در تلگرام به `@BotFather` پیام دهید، `/newbot` را بزنید و یک نام و username انتخاب کنید.
۲. توکنی که می‌دهد را در n8n به‌عنوان credential از نوع **Telegram API** ذخیره کنید — نام
   پیشنهادی: `Telegram Bot - هدف` (دقیقاً همین نام در فایل‌های JSON مرجع credential است؛ اگر
   نام دیگری گذاشتید، بعد از ایمپورت باید در نودهای مربوطه دوباره انتخابش کنید).

## ۳-الف) وضعیت استقرار فعلی (n8n Cloud)

هر چهار workflow روی نمونه‌ی ابری `arezoo000.app.n8n.cloud` ساخته شده‌اند:

| workflow | شناسه | لینک |
|---|---|---|
| WF-CORE | `wUQi023hO1sB8oTI` | https://arezoo000.app.n8n.cloud/workflow/wUQi023hO1sB8oTI |
| WF-WEB | `xZOW8s72N3NFkCJA` | https://arezoo000.app.n8n.cloud/workflow/xZOW8s72N3NFkCJA |
| WF-TELEGRAM | `m2vlruCUSKjCglN2` | https://arezoo000.app.n8n.cloud/workflow/m2vlruCUSKjCglN2 |
| WF-SLA | `wPyj7aXqXETkISo7` | https://arezoo000.app.n8n.cloud/workflow/wPyj7aXqXETkISo7` |

نودهای «فراخوانی CORE» در WF-WEB و WF-TELEGRAM از قبل به شناسه‌ی واقعی WF-CORE اشاره
می‌کنند، پس نیازی به انتخاب دستی workflow نیست.

**کارهای باقی‌مانده پیش از فعال‌سازی:**

۱. **PostgreSQL — ساخته شد (Supabase)**

   چون روی n8n Cloud سروری برای نصب دیتابیس وجود ندارد، دیتابیس روی Supabase ساخته شد:

   - نام پروژه: `hadaf-school`
   - شناسه (ref): `blehwjzrnroryrljklna`
   - منطقه: `eu-central-1`
   - داشبورد: https://supabase.com/dashboard/project/blehwjzrnroryrljklna

   `schema.sql` و `hadaf-school-content.sql` روی آن اجرا شده‌اند: ۱۲ جدول، ۱۱ ردیف
   `settings` و ۱۵ ردیف `faq` (۵ ردیف دارای `menu_path` که دکمه‌های منوی اصلی می‌شوند).

   **امنیت:** Supabase به‌صورت پیش‌فرض هر جدول schema عمومی را از طریق API و کلید anon
   در دسترس می‌گذارد. چون این سامانه اصلاً از آن API استفاده نمی‌کند (n8n با اتصال
   مستقیم Postgres کار می‌کند)، روی هر ۱۲ جدول RLS بدون هیچ policy فعال شد و دسترسی
   نقش‌های `anon` و `authenticated` پس گرفته شد. نتیجه: API عمومی به هیچ داده‌ای
   دسترسی ندارد، ولی n8n بدون تغییر کار می‌کند (نقش `postgres` از RLS عبور می‌کند).

   **ساخت credential در n8n:** در داشبورد Supabase دکمه‌ی **Connect** را بزنید و رشته‌ی
   اتصال **Session pooler** را بردارید (نه Direct connection — اتصال مستقیم روی پلن
   رایگان فقط IPv6 است و n8n Cloud به آن وصل نمی‌شود). مقادیر را در یک credential از
   نوع Postgres در n8n بگذارید:

   | فیلد | مقدار |
   |---|---|
   | Host | `aws-0-eu-central-1.pooler.supabase.com` (دقیقاً از Connect کپی کنید) |
   | Database | `postgres` |
   | User | `postgres.blehwjzrnroryrljklna` |
   | Password | رمز دیتابیس — از Settings → Database → Reset database password |
   | Port | `5432` (حالت Session) |
   | SSL | `require` |

   رمز دیتابیس هنگام ساخت پروژه تولید شده و در دسترس من نبود؛ باید یک بار از داشبورد
   آن را Reset کنید تا رمز جدید را ببینید.
۲. **نودهای HTTP Request** (ارسال پیام تلگرام، اعلان دفتر، پیام‌های SLA) هنگام ساخت
   خودکار credential نگرفتند. در هر کدام باید Authentication را روی
   «Predefined Credential Type» → «Telegram API» بگذارید و credential ربات را انتخاب کنید.
۳. **credentialهای انتخاب‌شده‌ی خودکار را بررسی کنید**: n8n به Telegram Trigger کردنشیال
   `Telegram account` و به Webhook کردنشیال `Header Auth account` را خودش وصل کرده است —
   مطمئن شوید همان ربات و همان کلید موردنظر شماست.

## ۳) ایمپورت workflowها در n8n (روش دستی، برای نصب خودمیزبان)

هر ۴ فایل زیر پوشه‌ی `workflows/` را از منوی **Import from File** در n8n وارد کنید:
`wf-core.json`، `wf-web.json`، `wf-telegram.json`، `wf-sla.json`.

بعد از ایمپورت، به‌ازای هر فایل:

- **credential Postgres** را در همه‌ی نودهای Postgres انتخاب کنید (نام مرجع:
  `Postgres - دبستان هدف`).
- **credential Telegram API** را در نودهای HTTP Request که به Bot API وصل می‌شوند و در نود
  Telegram Trigger انتخاب کنید (نام مرجع: `Telegram Bot - هدف`).
- در نودهای **Execute Workflow** داخل `WF-WEB` و `WF-TELEGRAM` (به نام «فراخوانی CORE»)،
  چون شناسه‌ی داخلی WF-CORE بعد از ایمپورت عوض می‌شود، باید workflow را دوباره از لیست
  انتخاب کنید (فیلد «From list» را باز کنید و WF-CORE را پیدا کنید).
- در `WF-WEB`، نود «دریافت پیام وب» به یک credential از نوع **Header Auth** نیاز دارد
  (نام مرجع: `X-API-Key وبسایت هدف`) که در آن Name را `X-API-Key` و Value را یک رشته‌ی
  تصادفی و طولانی بگذارید — همین مقدار باید در `web/index.html` هم قرار بگیرد (پایین‌تر).

هر ۴ workflow باید **Active** شوند تا Telegram Trigger/Webhook/Schedule واقعاً کار کنند.

## ۴) ثبت Webhook وب

بعد از فعال‌سازی `WF-WEB`، آدرس Webhook آن (چیزی شبیه
`https://<دامنه‌ی-n8n-شما>/webhook/hadaf-web-chat`) را کپی کنید و در `web/index.html` این دو
مقدار را جایگزین کنید:

```js
const WEBHOOK_URL = 'REPLACE_WITH_N8N_WEBHOOK_URL';
const API_KEY = 'REPLACE_WITH_X_API_KEY';
```

سپس `web/index.html` را روی هاست سایت مدرسه یا هر وب‌سرور استاتیک قرار دهید.

> **نکته‌ی امنیتی مهم:** چون `web/index.html` یک فایل استاتیک بدون بک‌اند است، هر مقداری که
> داخل جاوااسکریپت آن باشد (از جمله `API_KEY`) از طریق ابزار Network مرورگر قابل مشاهده است.
> این کلید فقط جلوی درخواست‌های ناخواسته‌ی ساده را می‌گیرد؛ محافظت واقعی در برابر
> سوءاستفاده، نرخ‌محدودسازی سمت `WF-WEB` است (فعلاً حداکثر ۲۰ درخواست در دقیقه به ازای هر IP).
> برای محرمانگی واقعی کلید، باید یک پراکسی سبک سمت سرور جلوی Webhook قرار گیرد که خودش
> هدر را تزریق کند — این پروژه چنین پراکسی‌ای نمی‌سازد چون خارج از محدوده‌ی «بدون سرویس
> خارجی جز Bot API تلگرام» تعریف نشده بود.

**دامنه‌ی CORS**: چون در زمان ساخت این پروژه دامنه‌ی سایت مدرسه مشخص نبود، فیلد
`options.allowedOrigins` در نود «دریافت پیام وب» فعلاً `*` (همه‌ی دامنه‌ها مجاز) گذاشته شده.
وقتی سایت روی دامنه‌ی نهایی مستقر شد، حتماً این مقدار را به همان دامنه (مثلاً
`https://hadafschool.ir`) محدود کنید تا فقط همان سایت بتواند به Webhook پیام بزند.

## ۵) نصب NocoDB (پنل ویرایش محتوا)

```bash
cd nocodb
cp .env.example .env
# مقادیر NC_DB و NC_AUTH_JWT_SECRET را در .env با مقادیر واقعی جایگزین کنید
psql -d hadaf_school -f restricted_role.sql   # ساخت کاربر محدود Postgres
docker compose up -d
```

بعد از بالا آمدن، NocoDB روی `http://<سرور>:8090` در دسترس است (پیشنهاد می‌شود پشت یک
ریورس‌پراکسی با HTTPS و احراز هویت قرار گیرد، چون شامل رمز اتصال دیتابیس است).

کاربر Postgres که NocoDB با آن وصل می‌شود (`hadaf_nocodb_user`) فقط به دو جدول `faq` و
`settings` دسترسی دارد؛ به `students`، `tickets`، `conversations` و بقیه‌ی جدول‌ها دسترسی ندارد.

### مدیر چطور یک پرسش جدید اضافه می‌کند

۱. وارد NocoDB شوید و جدول `faq` را باز کنید.
۲. یک ردیف جدید بسازید و این ستون‌ها را پر کنید:
   - `keywords`: فهرستی از کلمات/عبارت‌هایی که کاربر ممکن است تایپ کند (با غلط‌های رایج و
     با/بدون فاصله؛ هرچه بیشتر باشد، تشخیص بهتر است).
   - `answer`: متن پاسخ (پیشنهاد: زیر ۴۰ کلمه، بدون ایموجی).
   - `menu_path`: اگر می‌خواهید این پرسش به‌عنوان یک دکمه در منوی اصلی ظاهر شود، عنوان دکمه
     را اینجا بنویسید؛ اگر خالی بماند، پرسش فقط از طریق تایپ آزاد کاربر پیدا می‌شود.
   - `sort_order`: عددی که ترتیب دکمه‌ها در منو را مشخص می‌کند (کوچک‌تر = بالاتر).
۳. ذخیره کنید. **نیازی به تغییر هیچ workflow یا کد نیست** — دفعه‌ی بعد که کاربری منو را باز
   کند یا سؤال بپرسد، تغییر را می‌بیند، چون WF-CORE هر بار مستقیم از دیتابیس می‌خواند.

برای تغییر متن‌های ثابت (نام مدرسه، تلفن، شعار، آدرس و ...) همین کار را در جدول `settings`
روی ستون `value` انجام دهید.

آستانه‌ی تشخیص سؤال (`faq_match_threshold`) هم یک ردیف در `settings` است؛ اگر ساخته نشود،
پیش‌فرض کد آن را ۱ در نظر می‌گیرد (یعنی حداقل یک کلیدواژه باید در سؤال کاربر پیدا شود).

## متغیرها و credentialهای لازم در n8n

| credential | نوع | استفاده در |
|---|---|---|
| `Postgres - دبستان هدف` | Postgres | همه‌ی نودهای Postgres در هر ۴ workflow |
| `Telegram Bot - هدف` | Telegram API | Telegram Trigger + همه‌ی نودهای HTTP Request به Bot API |
| `X-API-Key وبسایت هدف` | Header Auth | نود Webhook در WF-WEB |

## محدودیت‌ها و فرض‌های صریح (برای شفافیت)

- فهرست پایه‌های تحصیلی (پیش‌دبستان تا ششم) در کد WF-CORE به‌صورت ثابت نوشته شده، چون در
  `faq`/`settings` ساختار داده‌ای برایش وجود نداشت. اگر لازم شد قابل‌ویرایش از NocoDB باشد،
  باید یک جدول یا ستون جدید برای آن اضافه شود (خارج از قید «بدون تغییر schema فعلی»).
- اعلان فوری ثبت‌نام به دفتر و ارسال پیام‌های تلگرام همه از طریق نود **HTTP Request** به
  Bot API تلگرام انجام می‌شود، نه نود اختصاصی Telegram — این‌طوری هم قید «بدون نود تلگرام
  داخل CORE» رعایت شده، هم رفتار در WF-TELEGRAM قابل‌پیش‌بینی و یکسان مانده است.
- تاریخ‌های نمایش‌داده‌شده به کارکنان (یادآوری SLA، گزارش هفتگی) با تقویم فارسی داخلی
  Node.js (`Intl` با `ca-persian`) ساخته می‌شوند؛ این ویژگی روی Node.js استاندارد (nodejs.org،
  از نسخه‌ی ۱۳ به بعد) و روی ایمیج رسمی Docker مربوط به n8n به‌طور پیش‌فرض فعال است.
- در پنل NocoDB، ستون‌های تاریخ (اگر جدولی با تاریخ به آن دسترسی داده شود) همان مقدار خام
  UTC دیتابیس را نشان می‌دهند؛ NocoDB بدون تنظیم دستی فرمتر، تبدیل شمسی انجام نمی‌دهد.
- همه‌ی فایل‌های workflow با اجرای واقعی یک نمونه‌ی n8n (نسخه‌ی ۲.۳۵.۷) تست ایمپورت شدند و
  بدون خطا وارد شدند؛ منطق WF-CORE با یک اسکریپت Node.js جداگانه که همان کدهای داخل نودها
  را اجرا می‌کند، برای سناریوهای اصلی شبیه‌سازی و تأیید شد (به `TESTING.md` نگاه کنید).

برای چک‌لیست تست دستی کامل (هر جریان، حالت‌های خطا، تست برابری خروجی دو کانال)، فایل
`TESTING.md` را ببینید.
