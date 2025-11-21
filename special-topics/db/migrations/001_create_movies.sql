-- UniScreen schema: movies table
CREATE TABLE IF NOT EXISTS public.movies (
    id           BIGSERIAL PRIMARY KEY,
    title        TEXT NOT NULL,
    year         INT,
    director     TEXT,
    actors       TEXT,
    plot         TEXT,
    poster_url   TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_movies_title ON public.movies (title);
CREATE INDEX IF NOT EXISTS idx_movies_year ON public.movies (year);

-- Optional uniqueness to avoid duplicates (same title + year)
-- Comment this out if you expect remakes or different entries with same title/year.
-- ALTER TABLE public.movies ADD CONSTRAINT uq_movies_title_year UNIQUE (title, year);
