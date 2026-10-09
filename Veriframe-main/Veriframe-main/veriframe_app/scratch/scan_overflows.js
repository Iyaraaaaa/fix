const fs = require('fs');
const path = require('path');

function getFiles(dir) {
  let res = [];
  fs.readdirSync(dir).forEach(f => {
    const p = path.join(dir, f);
    if (fs.statSync(p).isDirectory()) res = res.concat(getFiles(p));
    else if (f.endsWith('.dart')) res.push(p);
  });
  return res;
}

const files = getFiles('lib');
const rowIssues = [];
const fixedHeightIssues = [];

files.forEach(f => {
  const content = fs.readFileSync(f, 'utf8');
  const lines = content.split('\n');

  lines.forEach((l, idx) => {
    // Check for fixed height containers with children
    if (/height:\s*\d+,\s*$/.test(l) && idx < lines.length - 1) {
      // see if next lines have Column or Text
      const chunk = lines.slice(idx, idx + 15).join('\n');
      if (chunk.includes('child: Column(') || chunk.includes('child: Row(')) {
        fixedHeightIssues.push(`${f}:${idx + 1}: ${l.trim()}`);
      }
    }
  });
});

console.log('Fixed height containers with Column/Row: ' + fixedHeightIssues.length);
fixedHeightIssues.slice(0, 30).forEach(x => console.log(x));
