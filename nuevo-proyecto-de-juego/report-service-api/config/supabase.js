import dotenv from 'dotenv';
dotenv.config();

export const SUPABASE_URL = process.env.SUPABASE_URL || 'https://placeholder.supabase.co';
export const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'placeholder-key';
