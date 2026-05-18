.PHONY: og-image

## og-image: regenerate docs/og.png from docs/og-card.html
og-image:
	"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
		--headless \
		--disable-gpu \
		--screenshot="$(shell pwd)/docs/og.png" \
		--window-size=1200,627 \
		--hide-scrollbars \
		"file://$(shell pwd)/docs/og-card.html"
	@echo "Generated: docs/og.png"
