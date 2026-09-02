// Supabase config — publishable key es seguro exponer en cliente (RLS protege escritura)
// Override via --dart-define si necesitas otro proyecto: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://hcmkuzeypsadxxdxglxf.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_G0pTHMLYcL2tEgPm_PneIg_WBaw2rpt',
);

bool get isSupabaseConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
