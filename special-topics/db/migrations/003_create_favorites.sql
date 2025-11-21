-- UniScreen schema: favorites table
CREATE TABLE IF NOT EXISTS public.favorites (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    movie_id   BIGINT NOT NULL REFERENCES public.movies(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_favorites_user_movie UNIQUE (user_id, movie_id)
);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON public.favorites (user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_movie_id ON public.favorites (movie_id);
