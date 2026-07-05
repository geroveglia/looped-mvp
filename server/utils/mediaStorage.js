/**
 * Image storage abstraction.
 *
 * Multer always lands the file in ./uploads first. If Cloudinary is
 * configured, the file is then pushed there (signed upload via the plain
 * REST API — Node 18+ global fetch/FormData/Blob, no SDK) and the local
 * temp copy is deleted; callers get back an absolute https URL that
 * survives redeploys. Otherwise the local '/uploads/<name>' path is
 * returned (works, but the disk is ephemeral on Railway/Render).
 *
 * Env:
 *   CLOUDINARY_CLOUD_NAME
 *   CLOUDINARY_API_KEY
 *   CLOUDINARY_API_SECRET
 */

const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');

function isConfigured() {
    return Boolean(
        process.env.CLOUDINARY_CLOUD_NAME &&
        process.env.CLOUDINARY_API_KEY &&
        process.env.CLOUDINARY_API_SECRET
    );
}

/**
 * Stores a multer-saved file and returns its public URL.
 * Never throws: on any cloud failure it falls back to the local path.
 *
 * @param {object} file   multer file object (file.path, file.filename)
 * @param {string} folder logical folder, e.g. 'avatars' | 'events'
 * @returns {Promise<string>} absolute https URL (cloud) or '/uploads/<name>' (local)
 */
async function storeImage(file, folder) {
    const localUrl = `/uploads/${file.filename}`;
    if (!isConfigured()) return localUrl;

    try {
        const timestamp = Math.floor(Date.now() / 1000);
        // Signature: sha1 of the sorted params (folder, timestamp) + api_secret
        const toSign = `folder=${folder}&timestamp=${timestamp}${process.env.CLOUDINARY_API_SECRET}`;
        const signature = crypto.createHash('sha1').update(toSign).digest('hex');

        const buffer = await fs.readFile(file.path);
        const form = new FormData();
        form.append('file', new Blob([buffer]), file.filename);
        form.append('api_key', process.env.CLOUDINARY_API_KEY);
        form.append('timestamp', String(timestamp));
        form.append('folder', folder);
        form.append('signature', signature);

        const res = await fetch(
            `https://api.cloudinary.com/v1_1/${process.env.CLOUDINARY_CLOUD_NAME}/image/upload`,
            { method: 'POST', body: form }
        );
        if (!res.ok) {
            const body = await res.text();
            throw new Error(`Cloudinary ${res.status}: ${body.slice(0, 200)}`);
        }
        const data = await res.json();
        if (!data.secure_url) throw new Error('Cloudinary response missing secure_url');

        // Cloud copy exists — the local temp file is no longer needed.
        fs.unlink(path.resolve(file.path)).catch(() => {});

        return data.secure_url;
    } catch (err) {
        console.error('[mediaStorage] Cloud upload failed, keeping local file:', err.message);
        return localUrl;
    }
}

module.exports = { isConfigured, storeImage };
