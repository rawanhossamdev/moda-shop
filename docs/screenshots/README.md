# MODA screenshots

- home.png: refreshed 2026-10-31 from actual Flutter widget rendering at 360×640
  logical pixels / 2× export, producing 720×1280. Uses the new still-life hero,
  24-product synthetic catalog and mocked authentication/native storage. This is
  a rendered Flutter screen, not a new Android Emulator capture or Figma mockup.
- catalog.png: existing Android Emulator capture at 720×1280, with category
  controls, larger card names/prices and a catalog-level sample disclosure.
- product.png: existing Android Emulator capture of the Brown footwear gallery.
- variants.png: existing Android Emulator capture of Brown footwear sizes and
  the unavailable EU 38 combination.

The old Home capture is quarantined outside the publication set and its hash is
blocked by the publication audit. The current four PNGs were visually reviewed;
no account names, emails, addresses, tokens or private application data are visible.
No PNG text/EXIF metadata was found. Status bars in the older captures show only
generic device UI/time. No real order, email or payment was submitted for captures.

The Home scene and product images are generated fictional content, disclosed in
the UI and provenance records. Provider output-rights terms, account/input rights
and owner approval are separate from screenshot capture. See
[image provenance](../IMAGE_PROVENANCE.md) and the
[replacement registry](../../assets/images/PUBLICATION_REPLACEMENTS.json).
There is no new grant of rights in depicted assets merely because they appear in
a screenshot. Old unverified hero/model bytes are no longer in home.png.

To reproduce Home, use the optional test/asset_rights_visual_test.dart capture test
with MODA_CAPTURE_DIR and local MODA_SERIF_FONT/MODA_SANS_FONT paths. Output is
ignored build data until visually reviewed and deliberately copied here. Do not
capture a real account, address or order, or clear the owner's app data. Other
emulator captures may be refreshed via adb screencap after an approved local build.
