-- Create the shop_closures table
CREATE TABLE IF NOT EXISTS public.shop_closures (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    date TEXT NOT NULL, -- Format: YYYY-MM-DD
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS (Row Level Security) if needed
ALTER TABLE public.shop_closures ENABLE ROW LEVEL SECURITY;

-- Allow read access to everyone
CREATE POLICY "Allow read access to all users" ON public.shop_closures
    FOR SELECT
    USING (true);

-- Allow insert access
CREATE POLICY "Allow insert access to all users" ON public.shop_closures
    FOR INSERT
    WITH CHECK (true);

-- Allow update access
CREATE POLICY "Allow update access to all users" ON public.shop_closures
    FOR UPDATE
    USING (true)
    WITH CHECK (true);

-- Allow delete access
CREATE POLICY "Allow delete access to all users" ON public.shop_closures
    FOR DELETE
    USING (true);
