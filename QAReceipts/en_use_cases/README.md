# English Real-Source QA Receipts

This folder contains English receipt/order/payment/travel/document samples from public sources. The locally generated synthetic fixtures from the previous pass were deleted.

## Coverage

| Website claim | Covered by |
| --- | --- |
| Shopping | Amazon, eBay, Shopify, Walmart, Target, online order screenshots/receipts |
| Payments | Apple/Apple Pay screenshot, PayPal payment screenshot, Stripe receipt, card receipt |
| Travel | Airline, hotel, Uber, rental car invoice |
| Daily Life | Restaurant receipts, medical bill, utility bill, Walmart/grocery-style receipts |
| Documents | Email receipt, invoice, order detail/order confirmation |
| Paper Receipts | SROIE scanned receipts, Walmart paper receipt photos, OCR.space receipt |

## Notes

- `manifest.csv` lists every QA image, source URL, source type, and notes.
- `_sources/` keeps downloaded PDFs/ZIPs used to render some images.
- Some images contain public personal/order details because they came from public PDFs or public articles.
- Some files are WebP because the source image was WebP; this is useful for import compatibility testing.
- Taxi and fuel-specific English samples were not added in this pass because I did not find a clean public real-source image quickly enough. Uber, Walmart/grocery, restaurant, and card receipts cover similar OCR layouts, but taxi/fuel should still be filled later.

## QA Checklist

1. Import each file from Files/Photos.
2. Confirm OCR text is non-empty.
3. Check merchant/title, date, total amount, currency, payment method, and category suggestion.
4. Save and reopen the receipt to verify persistence.
5. Record failures by file path from `manifest.csv`.
