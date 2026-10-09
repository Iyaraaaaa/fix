const fs = require('fs');

const content = fs.readFileSync('lib/screens/verify.dart', 'utf8');
const lines = content.split('\n');

const hardcoded = [];
lines.forEach((l, i) => {
  if (l.includes('Text(') || l.includes('title:') || l.includes('label:') || l.includes('hintText:') || l.includes('tooltip:')) {
    if (!l.includes('loc.') && !l.includes('AppLocalizations')) {
      // Check if it has a string literal
      if (/['"][A-Za-z]{2,}/.test(l)) {
        hardcoded.push((i + 1) + ': ' + l.trim());
      }
    }
  }
});

console.log('Total potential hardcoded in verify.dart: ' + hardcoded.length);
hardcoded.slice(0, 40).forEach(h => console.log(h));
