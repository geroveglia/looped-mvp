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
 * Env (cualquiera de las dos formas):
 *   CLOUDINARY_CLOUD_NAME + CLOUDINARY_API_KEY + CLOUDINARY_API_SECRET
 *   CLOUDINARY_URL = cloudinary://<api_key>:<api_secret>@<cloud_name>
 */

const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');

/**
 * Extrae cloudinary://<api_key>:<api_secret>@<cloud_name>.
 * Busca la URL en cualquier parte del valor, no sólo al principio: el
 * dashboard de Cloudinary muestra la línea entera `CLOUDINARY_URL=cloudinary://…`
 * y es muy fácil copiarla completa dentro del valor de la variable.
 */
function parseCloudinaryUrl(value) {
    if (!value) return {};
    const m = /cloudinary:\/\/([^:@\s]+):([^@\s]+)@([^\s/]+)/.exec(String(value));
    if (!m) return {};
    return { apiKey: m[1], apiSecret: m[2], cloudName: m[3] };
}

const clean = v => (typeof v === 'string' ? v.trim() : v) || undefined;

/**
 * Credenciales desde las tres variables sueltas o desde CLOUDINARY_URL.
 * Aceptar las dos evita el error silencioso de cargar sólo la URL: las
 * imágenes seguían yendo al disco efímero sin que nada lo dijera.
 * @returns {{cloudName:string, apiKey:string, apiSecret:string}|null}
 */
function credentials() {
    const url = parseCloudinaryUrl(process.env.CLOUDINARY_URL);

    // Pegar la URL entera dentro de CLOUDINARY_API_SECRET es un error de
    // copiado habitual, y Cloudinary lo devuelve como "Invalid Signature"
    // sin ninguna pista de cuál de los tres valores está mal.
    const secretRaw = clean(process.env.CLOUDINARY_API_SECRET);
    const secretInside = parseCloudinaryUrl(secretRaw).apiSecret;
    if (secretInside && secretInside !== secretRaw) {
        console.warn(
            '[media] CLOUDINARY_API_SECRET traia la URL completa; se uso el secret de adentro. Conviene dejar solo el secret.'
        );
    }

    const cloudName = clean(process.env.CLOUDINARY_CLOUD_NAME) || url.cloudName;
    const apiKey = clean(process.env.CLOUDINARY_API_KEY) || url.apiKey;
    const apiSecret = secretInside || secretRaw || url.apiSecret;
    if (!cloudName || !apiKey || !apiSecret) return null;
    return { cloudName, apiKey, apiSecret };
}

function isConfigured() {
    return credentials() !== null;
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
    const creds = credentials();
    if (!creds) return localUrl;

    try {
        const timestamp = Math.floor(Date.now() / 1000);
        // Signature: sha1 of the sorted params (folder, timestamp) + api_secret
        const toSign = `folder=${folder}&timestamp=${timestamp}${creds.apiSecret}`;
        const signature = crypto.createHash('sha1').update(toSign).digest('hex');

        const buffer = await fs.readFile(file.path);
        const form = new FormData();
        form.append('file', new Blob([buffer]), file.filename);
        form.append('api_key', creds.apiKey);
        form.append('timestamp', String(timestamp));
        form.append('folder', folder);
        form.append('signature', signature);

        const res = await fetch(
            `https://api.cloudinary.com/v1_1/${creds.cloudName}/image/upload`,
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
