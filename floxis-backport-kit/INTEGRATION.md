# Floxis Adapter Integration Guide — Older Prebid.js Versions (Backport Kit)

This kit lets publishers running an **older Prebid.js wrapper** integrate the **current Floxis bid
adapter** without upgrading their Prebid version. It follows the same pattern other SSPs use for
old-wrapper support: drop the adapter module plus its small utility library into your existing
Prebid.js source tree and rebuild your bundle with the `floxisBidAdapter` module enabled.

**Key requirement:** the adapter alone is not enough. The `libraries/floxisUtils/` folder is
mandatory — it carries a helper (`politeTriggerPixel`) that newer Prebid cores ship natively but
older cores do not.

## Verified Prebid.js versions

Each version below was verified end-to-end: kit installed into a pristine checkout of the tag,
`npm ci`, bundle built with `--modules=floxisBidAdapter`, adapter present in the bundle (including
`gvlid:1609`), and the full adapter test suite run with **0 failures**.

| Prebid.js | Build | Adapter test suite | User sync / billing / telemetry hooks |
| --------- | ----- | ------------------ | ------------------------------------- |
| 8.52.2  | ✅ | ✅ 98 passed, 0 failed | ✅ all supported by core |
| 9.27.0  | ✅ | ✅ 98 passed, 0 failed | ✅ all supported by core |
| 9.53.0  | ✅ | ✅ 0 failed            | ✅ all supported by core |
| 10.6.0  | ✅ | ✅ 98 passed, 0 failed | ✅ all supported by core |
| 10.29.1 | ✅ | ✅ 98 passed, 0 failed | ✅ all supported by core |

Versions between these tags are expected to work as well; you can confirm yours in minutes by
running the adapter test suite (step 4) after installing the kit. Prebid.js 11+ does **not** need
this kit — the Floxis adapter ships natively in current Prebid.js (`--modules=floxisBidAdapter`).

## 1. Required files & setup

Copy the following files into your Prebid.js source tree, same paths:

| File | Target path |
| ---- | ----------- |
| `modules/floxisBidAdapter.js` | `modules/floxisBidAdapter.js` |
| `modules/floxisBidAdapter.md` | `modules/floxisBidAdapter.md` |
| `libraries/floxisUtils/politePixel.js` | `libraries/floxisUtils/politePixel.js` |
| `test/spec/modules/floxisBidAdapter_spec.js` | `test/spec/modules/floxisBidAdapter_spec.js` |

Or run the installer:

```bash
./install.sh /path/to/your/Prebid.js
```

## 2. Building the project

```bash
cd /path/to/your/Prebid.js
npm ci
node_modules/.bin/gulp build --modules=floxisBidAdapter
```

Append your existing module list to `--modules` (comma-separated) so the rest of your wrapper is
unchanged — only the Floxis adapter is added.

Notes:
- Use `node_modules/.bin/gulp` (the repo-local gulp). On older Prebid tags a bare `npx gulp` can
  resolve to a newer global gulp and fail with `Local modules not found`.
- On macOS Apple Silicon, Prebid 10.x `npm ci` may fail in puppeteer's postinstall; use
  `PUPPETEER_SKIP_DOWNLOAD=true npm ci`.

## 3. Ad unit implementation

```javascript
pbjs.addAdUnits([{
  code: 'ad',
  mediaTypes: {
    banner: {
      sizes: [[300, 250]]
    }
  },
  bids: [{
    bidder: 'floxis',
    params: {
      seat: 'SEAT',          // required — your Floxis seat ID
      region: 'us-e',        // optional — defaults to us-e
      bidFloor: 0.01         // optional — static floor fallback when the Floors module is absent
    }
  }]
}]);
```

`seat` is the only required parameter. Banner, video (instream) and native are supported. GDPR/TCF
(Floxis is IAB Europe TCF **Vendor ID 1609**), US Privacy, GPP and COPPA signals are handled by
Prebid.js core and forwarded automatically.

## 4. Enable iframe user sync (on by default in this integration)

The Floxis adapter is **iframe-first**: an iframe cookie sync chains multiple demand-partner matches
in a single call, so it materially out-matches a single image pixel — and match rate is revenue.
Prebid core ships with iframe syncs **off** unless the publisher enables them, so the standard
Floxis integration turns them **on** for Floxis. Add this to your Prebid configuration:

```javascript
pbjs.setConfig({
  userSync: {
    filterSettings: {
      iframe: { bidders: ['floxis'], filter: 'include' }
    }
  }
});
```

- Scoped to `bidders: ['floxis']` — it does **not** change sync behavior for your other SSPs.
- **Already using `filterSettings.all`?** You're done — iframe is already enabled for every bidder.
  Do **not** add the block above: Prebid core treats `filterSettings.all` and `filterSettings.iframe`
  as mutually exclusive, and mixing them disables **all** syncs.

**Turning it off (opt-out).** To disable Floxis iframe sync, set `filter: 'exclude'` (or drop
`floxis` from the iframe `bidders` list) — Floxis then falls back to an image-pixel sync. To disable
Floxis syncs entirely, exclude `floxis` from both `iframe` and `image`; `userSync.syncEnabled: false`
disables syncs for all bidders.

## 5. Enable first-party fallback id (recommended)

The adapter mints a random UUID in the publisher's own page context (`localStorage` + cookie, scoped to the publisher's origin) and sends it at `user.ext.floxisId`. This is an identity-of-last-resort for Safari, Firefox and other browsers where the Floxis third-party cookie (`__fxId`) is blocked — it does not affect Chrome/Edge, where the third-party cookie takes precedence on the backend.

Since Prebid.js 7.x, bidder-level storage access is **denied by default**. Without the opt-in below, no id is generated and no storage is touched — a safe no-op, not an error. To enable it:

```javascript
pbjs.bidderSettings = {
  floxis: {
    storageAllowed: true
  }
};
```

This is scoped to the Floxis bidder only and does not affect storage permissions for your other SSPs. Storage access is further gated by Prebid.js core's `deviceAccess` config and GDPR purpose-1 consent under Floxis's registered gvlid (1609).

## 6. Verification & troubleshooting

- **Enable debugging:** `pbjs.setConfig({ debug: true })` and watch the console.
- **Module check:** confirm `floxisBidAdapter` appears in `pbjs.installedModules`.
- **Traffic check:** look for `POST https://<region>.floxis.tech/pbjs?seat=...` requests and check
  `pbjs.getBidResponses()`.
- **Iframe sync check:** after an auction, confirm an **iframe** to `https://px-<region>.floxis.tech/sync?seat=...`
  loads (Network tab, type `document`/`iframe`). If you see an image pixel instead of an iframe, the
  iframe `filterSettings` from step 4 is missing or excludes `floxis`.
- **No requests fired?** Verify `libraries/floxisUtils/` was copied — a missing utility folder is
  the most common integration error.
- **Run the adapter test suite** against your tree (needs Chrome; if the launcher can't find it,
  set `CHROME_BIN` to your Chrome binary):

```bash
node_modules/.bin/gulp test --nolint --file test/spec/modules/floxisBidAdapter_spec.js
```

## Support

Maintainer: prebid@floxis.tech
