-- =====================================================================
-- schema.sql — ساخت جدول‌ها و ایندکس‌های سامانه‌ی پاسخگویی و ثبت‌نام
-- دبستان پسرانه غیردولتی هدف بابلسر
-- این فایل فقط ساختار است. محتوا از hadaf-school-content.sql می‌آید.
-- ترتیب اجرا: schema.sql سپس hadaf-school-content.sql
-- =====================================================================

-- برای تولید public_ref کوتاه در تیکت‌ها لازم است
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------- تنظیمات ثابت مدرسه (تک‌مقداری، کلید/مقدار) ----------
CREATE TABLE IF NOT EXISTS settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- ---------- پرسش‌های متداول ----------
CREATE TABLE IF NOT EXISTS faq (
  id         SERIAL PRIMARY KEY,
  keywords   TEXT[] NOT NULL DEFAULT '{}',
  answer     TEXT   NOT NULL,
  menu_path  TEXT   NOT NULL DEFAULT '',   -- خالی یعنی فقط از طریق تطبیق کلیدواژه
  sort_order INT    NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_faq_menu_path
  ON faq (sort_order)
  WHERE menu_path <> '';

CREATE INDEX IF NOT EXISTS idx_faq_keywords_gin
  ON faq USING GIN (keywords);

-- ---------- دانش‌آموزان ----------
CREATE TABLE IF NOT EXISTS students (
  id           SERIAL PRIMARY KEY,
  name         TEXT NOT NULL,
  grade        TEXT NOT NULL,
  class        TEXT,
  parent_phone TEXT,
  unique_code  TEXT NOT NULL UNIQUE
);

-- ---------- اولیا (پیوند به دانش‌آموز از طریق کانال) ----------
CREATE TABLE IF NOT EXISTS parents (
  id              SERIAL PRIMARY KEY,
  student_id      INT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  channel         TEXT NOT NULL CHECK (channel IN ('telegram', 'web')),
  channel_user_id TEXT NOT NULL,
  verified_at     TIMESTAMPTZ,            -- تا وقتی NULL است، هیچ داده‌ی دانش‌آموزی برنمی‌گردد
  UNIQUE (channel, channel_user_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_parents_channel_user
  ON parents (channel, channel_user_id);

-- ---------- وضعیت مکالمه (منبع حقیقت state machine، نه حافظه‌ی workflow) ----------
CREATE TABLE IF NOT EXISTS conversations (
  id         SERIAL PRIMARY KEY,
  channel    TEXT NOT NULL CHECK (channel IN ('telegram', 'web')),
  channel_user_id TEXT NOT NULL,
  state      JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (channel, channel_user_id)
);

-- ---------- کارکنان دفتر ----------
CREATE TABLE IF NOT EXISTS staff (
  id                SERIAL PRIMARY KEY,
  name              TEXT NOT NULL,
  telegram_chat_id  TEXT,
  category          TEXT NOT NULL   -- مالی/آموزشی/انضباطی/مرخصی/سایر/مدیر
);

-- ---------- تیکت‌ها ----------
CREATE TABLE IF NOT EXISTS tickets (
  id             SERIAL PRIMARY KEY,
  student_id     INT REFERENCES students(id),
  channel        TEXT NOT NULL CHECK (channel IN ('telegram', 'web')),
  channel_user_id TEXT NOT NULL,
  category       TEXT NOT NULL,   -- مالی/آموزشی/انضباطی/مرخصی/سایر یا 'سؤال_آزاد'
  body           TEXT NOT NULL,
  status         TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'answered', 'closed')),
  assignee_id    INT REFERENCES staff(id),
  public_ref     TEXT NOT NULL UNIQUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  first_reply_at TIMESTAMPTZ,
  closed_at      TIMESTAMPTZ,
  rating         INT CHECK (rating BETWEEN 1 AND 5)
);

CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets (status);
CREATE INDEX IF NOT EXISTS idx_tickets_category ON tickets (category);
CREATE INDEX IF NOT EXISTS idx_tickets_assignee ON tickets (assignee_id);
CREATE INDEX IF NOT EXISTS idx_tickets_created_at ON tickets (created_at);

-- ---------- پیام‌های هر تیکت ----------
CREATE TABLE IF NOT EXISTS messages (
  id         SERIAL PRIMARY KEY,
  ticket_id  INT NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  direction  TEXT NOT NULL CHECK (direction IN ('in', 'out')),
  body       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_messages_ticket ON messages (ticket_id);

-- ---------- سرنخ‌های ثبت‌نام ----------
CREATE TABLE IF NOT EXISTS leads (
  id           SERIAL PRIMARY KEY,
  student_name TEXT NOT NULL,
  grade        TEXT NOT NULL,
  parent_name  TEXT NOT NULL,
  phone        TEXT NOT NULL CHECK (phone ~ '^09\d{9}$'),
  note         TEXT,
  channel      TEXT NOT NULL CHECK (channel IN ('telegram', 'web')),
  status       TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'closed')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- مراحل تکمیل‌شده‌ی ثبت‌نام (برای ادامه‌ی گفتگو از همان مرحله) ----------
CREATE TABLE IF NOT EXISTS registrations (
  id           SERIAL PRIMARY KEY,
  lead_id      INT REFERENCES leads(id) ON DELETE CASCADE,
  step         TEXT NOT NULL,
  payload      JSONB NOT NULL DEFAULT '{}',
  completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_registrations_lead ON registrations (lead_id);

-- ---------- سؤال‌های بی‌پاسخ (زیر آستانه‌ی تطبیق) ----------
CREATE TABLE IF NOT EXISTS unanswered (
  id              SERIAL PRIMARY KEY,
  channel         TEXT NOT NULL CHECK (channel IN ('telegram', 'web')),
  channel_user_id TEXT NOT NULL,
  text            TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_unanswered_created_at ON unanswered (created_at);

-- ---------- idempotency آپدیت‌های تلگرام ----------
CREATE TABLE IF NOT EXISTS processed_updates (
  update_id  BIGINT PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
