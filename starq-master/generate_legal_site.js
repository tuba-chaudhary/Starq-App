const fs = require('fs');
const path = require('path');

const template = (title, content) => `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>STARQ - ${title}</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1, h2, h3 { color: #1a1a1a; }
        h1 { border-bottom: 2px solid #0052cc; padding-bottom: 10px; }
        .alert { background-color: #fff3cd; color: #856404; padding: 15px; border-radius: 4px; margin-bottom: 20px; border-left: 5px solid #ffeeba; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; text-align: center; color: #666; font-size: 0.9em; }
        a { color: #0052cc; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div style="text-align: center; margin-bottom: 30px;">
        <h2 style="color: #0052cc; margin: 0;">STARQ</h2>
        <p style="margin: 0; color: #666;">Doorstep Vehicle Cleaning</p>
    </div>
    
    ${content}
    
    <div class="footer">
        &copy; ${new Date().getFullYear()} [Legal Company Name Placeholder]. All rights reserved.<br>
        <a href="index.html">Back to Legal Home</a>
    </div>
</body>
</html>`;

function parseMarkdown(md) {
    let html = md
        .replace(/^### (.*$)/gim, '<h3>$1</h3>')
        .replace(/^## (.*$)/gim, '<h2>$1</h2>')
        .replace(/^# (.*$)/gim, '<h1>$1</h1>')
        .replace(/^\*\*NOTE:(.*?)\*\*/gim, '<div class="alert"><strong>NOTE:</strong>$1</div>')
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.*?)\*/g, '<em>$1</em>')
        .replace(/^- (.*$)/gim, '<li>$1</li>')
        .replace(/\n\n/g, '<br><br>');
    
    // Wrap consecutive li tags in ul
    html = html.replace(/(<li>.*<\/li>)/s, '<ul>$1</ul>');
    return html;
}

const files = [
    { in: 'TERMS_AND_CONDITIONS.md', out: 'terms.html', title: 'Terms and Conditions' },
    { in: 'PRIVACY_POLICY.md', out: 'privacy.html', title: 'Privacy Policy' },
    { in: 'CANCELLATION_REFUND_POLICY.md', out: 'refund.html', title: 'Cancellation & Refund Policy' },
    { in: 'VEHICLE_CONDITION_CONSENT.md', out: 'consent.html', title: 'Vehicle Condition Consent' },
];

let indexLinks = '<h1>STARQ Legal & Privacy</h1><ul>';

files.forEach(f => {
    const md = fs.readFileSync(path.join('docs', 'legal', f.in), 'utf8');
    const contentHtml = parseMarkdown(md);
    fs.writeFileSync(path.join('legal-site', f.out), template(f.title, contentHtml));
    indexLinks += `<li><a href="${f.out}">${f.title}</a></li>`;
});

// Create explicit Account Deletion Instructions
const deletionContent = `
<h1>Account Deletion Instructions</h1>
<div class="alert"><strong>Data Retention Notice:</strong> While your personal identifiers will be anonymized/erased, financial transaction logs are legally retained for tax and accounting purposes.</div>
<h2>How to request account deletion in the app:</h2>
<ol>
    <li>Open the STARQ App on your Android device.</li>
    <li>Navigate to the <strong>Profile</strong> tab in the bottom navigation bar.</li>
    <li>Scroll down and tap on <strong>Delete Account</strong>.</li>
    <li>Read the confirmation dialogue carefully and tap <strong>Delete</strong>.</li>
    <li>Your personal data will be immediately anonymized, your push notification tokens will be revoked, and you will be logged out.</li>
</ol>
<h2>Request deletion via email:</h2>
<p>If you no longer have access to the app, you may email our Grievance Officer at <strong>[Contact Email]</strong> with the subject "Account Deletion Request". Please include the phone number associated with your account.</p>
`;
fs.writeFileSync(path.join('legal-site', 'delete-account.html'), template('Account Deletion', deletionContent));
indexLinks += `<li><a href="delete-account.html">Account Deletion Instructions</a> (Required by Google Play)</li></ul>`;

fs.writeFileSync(path.join('legal-site', 'index.html'), template('Legal Directory', indexLinks));

console.log('Legal site generated successfully.');
