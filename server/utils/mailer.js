/**
 * Minimal transactional mailer backed by Resend's REST API (no SDK needed,
 * axios is already a dependency).
 *
 * Configure via env:
 *   RESEND_API_KEY  — https://resend.com API key
 *   MAIL_FROM       — e.g. "Looped <no-reply@yourdomain.com>"
 *                     (defaults to Resend's shared onboarding sender, which
 *                      only delivers to the account owner's inbox — fine for
 *                      testing, set a verified domain for production)
 *
 * If RESEND_API_KEY is missing, isConfigured() is false and callers should
 * fall back to dev behavior (console logging).
 */

const axios = require('axios');

function isConfigured() {
    return Boolean(process.env.RESEND_API_KEY);
}

/**
 * Sends an email. Returns true on success, false on failure (never throws:
 * password-reset flows must not leak provider errors to the client).
 */
async function sendMail({ to, subject, html }) {
    if (!isConfigured()) return false;
    try {
        await axios.post(
            'https://api.resend.com/emails',
            {
                from: process.env.MAIL_FROM || 'Looped <onboarding@resend.dev>',
                to: [to],
                subject,
                html,
            },
            {
                headers: {
                    Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
                    'Content-Type': 'application/json',
                },
                timeout: 10000,
            }
        );
        return true;
    } catch (err) {
        console.error('[mailer] Send failed:', err.response?.data?.message || err.message);
        return false;
    }
}

function passwordResetEmail(code) {
    return {
        subject: `${code} es tu código de Looped`,
        html: `
<div style="font-family:Arial,Helvetica,sans-serif;max-width:440px;margin:0 auto;background:#0a0a0a;color:#e8e8e8;border-radius:16px;padding:32px;">
  <h2 style="margin:0 0 8px;color:#00D9A5;">Looped</h2>
  <p style="margin:0 0 24px;color:#aaaaaa;">Recibimos un pedido para restablecer tu contraseña.</p>
  <div style="background:#161616;border:1px solid #2a2a2a;border-radius:12px;padding:20px;text-align:center;">
    <div style="font-size:12px;letter-spacing:2px;color:#888888;margin-bottom:8px;">TU CÓDIGO</div>
    <div style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#ffffff;">${code}</div>
  </div>
  <p style="margin:24px 0 0;font-size:12px;color:#888888;">
    El código vence en 1 hora. Si no fuiste vos, ignorá este correo — tu contraseña no cambia.
  </p>
</div>`,
    };
}

module.exports = { isConfigured, sendMail, passwordResetEmail };
