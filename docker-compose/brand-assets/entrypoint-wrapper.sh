#!/bin/sh
# Pre-copy brand assets to where the Blockscout frontend expects them.
# This runs BEFORE the original entrypoint so the download_assets.sh
# will find the files already in place (and skip re-downloading).
mkdir -p /app/public/assets/configs /app/public/assets/favicon

# Logo and icon configs
cp /app/public/brand-assets/network_logo.png      /app/public/assets/configs/network_logo.png      2>/dev/null
cp /app/public/brand-assets/network_logo_dark.png  /app/public/assets/configs/network_logo_dark.png  2>/dev/null
cp /app/public/brand-assets/network_icon.png       /app/public/assets/configs/network_icon.png       2>/dev/null
cp /app/public/brand-assets/network_icon_dark.png  /app/public/assets/configs/network_icon_dark.png  2>/dev/null
cp /app/public/brand-assets/og_image.png           /app/public/assets/configs/og_image.png           2>/dev/null

# Favicons
cp /app/public/brand-assets/favicon/* /app/public/assets/favicon/ 2>/dev/null

# Inject CSS + JS override to make the sidebar logo bigger
# CSS alone isn't enough because Chakra UI parent containers clip the image
for CSS_FILE in /app/.next/static/css/*.css; do
  [ -f "$CSS_FILE" ] || continue
  cat >> "$CSS_FILE" << 'CSSEOF'

/* Lydia Coin branding: force bigger logo in sidebar */
img[src*="network_logo"],
img[src*="network_logo_dark"],
img[src*="network_icon"],
img[src*="network_icon_dark"] {
  max-height: 80px !important;
  height: 80px !important;
  max-width: 220px !important;
  width: auto !important;
  object-fit: contain !important;
}
/* Also override the parent Chakra Box containers that clip the logo */
img[src*="network_logo"] ~ *,
img[src*="network_icon"] ~ *,
div:has(> img[src*="network_logo"]),
div:has(> img[src*="network_icon"]),
a:has(img[src*="network_logo"]),
a:has(img[src*="network_icon"]) {
  max-height: 90px !important;
  height: auto !important;
  overflow: visible !important;
}
CSSEOF
  echo "CSS override injected into $CSS_FILE"
done

# Inject a small JS snippet into the main page HTML to resize the logo after render
# This is a fallback in case CSS alone can't override Chakra's inline styles
cat > /app/public/logo-resize.js << 'JSEOF'
(function() {
  function resizeLogo() {
    document.querySelectorAll('img[src*="network_logo"], img[src*="network_icon"]').forEach(function(img) {
      img.style.setProperty('height', '80px', 'important');
      img.style.setProperty('max-height', '80px', 'important');
      img.style.setProperty('width', 'auto', 'important');
      img.style.setProperty('max-width', '220px', 'important');
      img.style.setProperty('object-fit', 'contain', 'important');
      // Also fix parent container
      var parent = img.parentElement;
      if (parent) {
        parent.style.setProperty('height', 'auto', 'important');
        parent.style.setProperty('max-height', '90px', 'important');
        parent.style.setProperty('overflow', 'visible', 'important');
        parent.style.setProperty('width', 'auto', 'important');
        parent.style.setProperty('max-width', '220px', 'important');
        var grandparent = parent.parentElement;
        if (grandparent) {
          grandparent.style.setProperty('height', 'auto', 'important');
          grandparent.style.setProperty('max-height', '100px', 'important');
          grandparent.style.setProperty('overflow', 'visible', 'important');
        }
      }
    });
  }
  // Run on load and observe for dynamic changes
  var observer = new MutationObserver(resizeLogo);
  observer.observe(document.body || document.documentElement, { childList: true, subtree: true });
  setInterval(resizeLogo, 1000);
})();
JSEOF
echo "Logo resize JS created"

# Inject script tag into the server-rendered pages
# Find and patch the _document or _app HTML to include our script
for HTML_FILE in /app/.next/server/pages/*.html; do
  [ -f "$HTML_FILE" ] || continue
  if ! grep -q "logo-resize.js" "$HTML_FILE" 2>/dev/null; then
    sed -i 's|</head>|<script src="/logo-resize.js" defer></script></head>|' "$HTML_FILE" 2>/dev/null
    echo "Injected script into $HTML_FILE"
  fi
done

exec /app/entrypoint.sh "$@"
