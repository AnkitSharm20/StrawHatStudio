import { createClient } from '@supabase/supabase-js';
const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || import.meta.env.VITE_SUPABASE_ANON_KEY;
// Keep the same default Supabase storage key so existing signed-in sessions remain readable.
const authStorage = typeof window !== 'undefined' ? window.localStorage : undefined;
export const supabase = url && key ? createClient(url, key, {
  auth: {
    storage: authStorage,
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    flowType: 'pkce'
  }
}) : null;
export const backendReady = Boolean(supabase);
