/// Address of your free Cloudflare Worker (see SETUP_PUSH_AND_CALLS.md, step 2).
/// Paste the URL Cloudflare shows after you deploy it, with no trailing slash.
const String kPushWorkerUrl = 'https://chatvibe-push.YOUR-SUBDOMAIN.workers.dev';

/// False until you replace the placeholder above. While false, the app simply
/// skips push requests instead of failing.
bool get kPushConfigured => !kPushWorkerUrl.contains('YOUR-SUBDOMAIN');
