const fs = require('fs');
const path = require('path');

const screens = [
  'about_us.dart',
  'contact_us.dart',
  'delete_account.dart',
  'edit_profile.dart',
  'notifications.dart',
  'privacy.dart',
  'reports_page.dart',
  'settings_page.dart',
  'profile_page.dart',
  'logout_page.dart',
  'technology_stack_page.dart',
  'evidence_video_player_screen.dart',
  'analyze_page.dart',
  'verify.dart',
  'on_bording.dart',
  'media_modality_selection_page.dart',
  'home_page.dart'
];

screens.forEach(s => {
  const p = path.join('lib/screens', s);
  if (fs.existsSync(p)) {
    const c = fs.readFileSync(p, 'utf8');
    const usesLoc = c.includes('AppLocalizations.of') || c.includes('loc.');
    const matches = c.match(/Text\(\s*['"][A-Za-z\s]+['"]/g) || [];
    console.log(s.padEnd(35) + ' usesLoc: ' + String(usesLoc).padEnd(6) + ' | hardcoded Text counts: ' + matches.length);
  } else {
    console.log(s + ' does NOT exist');
  }
});
