-- نقش محدود PostgreSQL برای NocoDB — فقط خواندن/نوشتن روی faq و settings
-- این اسکریپت را یک‌بار با کاربر postgres (یا هر نقش دارای دسترسی مدیریتی) اجرا کنید.
-- رمز عبور را قبل از اجرا جایگزین کنید و همان را در nocodb/.env به NC_DB بدهید.

CREATE ROLE hadaf_nocodb_user LOGIN PASSWORD 'REPLACE_WITH_STRONG_PASSWORD';

GRANT CONNECT ON DATABASE hadaf_school TO hadaf_nocodb_user;
GRANT USAGE ON SCHEMA public TO hadaf_nocodb_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON faq TO hadaf_nocodb_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON settings TO hadaf_nocodb_user;

-- دسترسی به sequence مربوط به کلید faq.id برای درج ردیف جدید از طریق NocoDB
GRANT USAGE, SELECT ON SEQUENCE faq_id_seq TO hadaf_nocodb_user;

-- هیچ دسترسی‌ای به بقیه‌ی جدول‌ها داده نمی‌شود (students, tickets, conversations و ...)
-- چون این جدول‌ها اطلاعات دانش‌آموز/اولیا دارند و نباید از طریق پنل محتوا قابل مشاهده باشند.
