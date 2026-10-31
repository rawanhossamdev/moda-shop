const escape = (value) => String(value).replace(/[&<>"']/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);
function layout({ preheader, eyebrow, title, introduction, code, instruction, safety }) {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escape(title)} | MODA Shop</title></head>
<body style="margin:0;padding:0;background-color:#FAF7F2;color:#252320;font-family:Arial,Helvetica,sans-serif;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">${escape(preheader)}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#FAF7F2;"><tr><td align="center" style="padding:36px 16px;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:580px;">
<tr><td align="center" style="padding:0 0 30px;font-family:Georgia,'Times New Roman',serif;font-size:32px;letter-spacing:8px;">MODA</td></tr>
<tr><td style="padding:32px 24px;border:1px solid #DED5C8;border-radius:18px;background-color:#FFFFFF;">
<p style="margin:0 0 18px;color:#716A61;font-size:11px;letter-spacing:2px;">${escape(eyebrow)}</p>
<h1 style="margin:0 0 18px;font-family:Georgia,'Times New Roman',serif;font-weight:normal;font-size:34px;line-height:1.2;">${escape(title)}</h1>
<div style="height:2px;width:44px;background-color:#A58A57;margin:0 0 24px;"></div>
<p style="margin:0 0 24px;font-size:16px;line-height:1.7;">${escape(introduction)}</p>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td align="center" style="padding:24px 16px;background-color:#F2ECE3;border:1px solid #DED5C8;border-radius:14px;">
<p style="margin:0 0 12px;color:#716A61;font-size:11px;letter-spacing:2px;">YOUR PRIVATE CODE</p>
<code style="font-family:'Courier New',monospace;font-size:${code.length === 6 ? '30' : '16'}px;line-height:1.8;letter-spacing:${code.length === 6 ? '5' : '0'}px;word-break:break-all;overflow-wrap:anywhere;color:#252320;">${escape(code)}</code>
</td></tr></table>
<p style="margin:22px 0 12px;font-size:15px;line-height:1.7;">${escape(instruction)}</p>
<p style="margin:0;color:#716A61;font-size:13px;line-height:1.7;">This code expires in <strong>15 minutes</strong> and can be used once. Never share it.</p>
<div style="height:1px;background-color:#DED5C8;margin:26px 0 20px;"></div>
<p style="margin:0;color:#716A61;font-size:13px;line-height:1.7;">${escape(safety)} MODA will never ask for your password by email.</p>
</td></tr>
<tr><td align="center" style="padding:26px 16px;color:#716A61;font-size:12px;line-height:1.8;">Selected by MODA. Styled by you.<br>MODA Shop · Your account, thoughtfully protected.</td></tr>
</table></td></tr></table></body></html>`;
}
export function verificationEmail(code) {
  if (typeof code !== 'string' || !/^\d{6}$/.test(code)) throw new Error('Invalid verification email payload.');
  return {
    subject: 'Verify your MODA email',
    html: layout({ preheader: 'A private code to verify your MODA account.', eyebrow: 'YOUR MODA ACCOUNT', title: 'A little reassurance.',
      introduction: 'Welcome to MODA. Verify your email to make your considered selection yours.', code,
      instruction: 'Enter this six-digit code on the Verify Email screen in MODA Shop.',
      safety: 'If you did not create an account or request a new code, you can ignore this email.' }),
    text: `MODA Shop — Verify your email\n\nYour verification code: ${code}\n\nEnter it on MODA Shop's Verify Email screen. It expires in 15 minutes and can be used once. Never share this code.\n\nIf you did not create an account or request a new code, ignore this email. MODA will never ask for your password by email.`,
  };
}
export function passwordResetEmail(code) {
  if (typeof code !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(code)) throw new Error('Invalid password reset email payload.');
  return {
    subject: 'Reset your MODA password',
    html: layout({ preheader: 'A private, single-use code for a fresh start.', eyebrow: 'ACCOUNT RECOVERY', title: 'A fresh start.',
      introduction: 'We received a request to reset your MODA password. Use the private code below to choose a new one.', code,
      instruction: 'Open Forgot Password in MODA Shop, choose “I have a reset code”, then copy and paste the complete code.',
      safety: 'If you did not request a password reset, ignore this email. Your password stays unchanged until a valid reset is completed.' }),
    text: `MODA Shop — Reset your password\n\nPaste this complete code into MODA Shop's Reset Password screen:\n\n${code}\n\nOpen Forgot Password and choose "I have a reset code". The code expires in 15 minutes and can be used once. Never share it.\n\nIf you did not request this, ignore this email. Your password stays unchanged until a valid reset is completed. MODA will never ask for your password by email.`,
  };
}
