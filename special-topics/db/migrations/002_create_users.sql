-- UniScreen schema: users table
CREATE TABLE IF NOT EXISTS public.users (
    id             BIGSERIAL PRIMARY KEY,
    email          TEXT NOT NULL UNIQUE,
    password_hash  TEXT NOT NULL
);

-- Helpful index for email lookups (redundant with UNIQUE but explicit)
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users (email);
