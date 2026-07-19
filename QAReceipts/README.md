# QA Receipt Samples

This folder contains public or synthetic receipt/invoice/payment samples for OCR and import QA.

Use these only for internal QA. Do not ship these assets inside the app bundle unless each source's license/terms are reviewed separately.

## Summary

| Language | Count | Folder | Notes |
| --- | ---: | --- | --- |
| English | 4 | `en/` | Real scanned receipts from SROIE plus one repository sample image. |
| German | 2 | `de/` | Real-life German receipt images from ielanguages. |
| French | 2 | `fr/` | Real-life French receipt images from ielanguages. |
| Japanese | 3 | `ja/` | Synthetic Japanese receipt benchmark images, including clean and noisy samples. |
| Chinese | 2 | `zh/` | Public taxi/VAT invoice dataset samples. |
| Spanish | 2 | `es/` | Public Spanish invoice/payment PDF samples rendered to PNG. |

Total image files: 15

## Manifest

| File | Language | Type | Source | Notes |
| --- | --- | --- | --- | --- |
| `en/en_sroie_000.jpg` | English | Receipt | https://github.com/zzzDavid/ICDAR-2019-SROIE/raw/master/data/img/000.jpg | Real scanned receipt from SROIE. |
| `en/en_sroie_001.jpg` | English | Receipt | https://github.com/zzzDavid/ICDAR-2019-SROIE/raw/master/data/img/001.jpg | Real scanned receipt from SROIE. |
| `en/en_sroie_002.jpg` | English | Receipt | https://github.com/zzzDavid/ICDAR-2019-SROIE/raw/master/data/img/002.jpg | Real scanned receipt from SROIE. |
| `en/en_sroie_starbucks.jpg` | English | Receipt | https://github.com/zzzDavid/ICDAR-2019-SROIE/raw/master/Media/data_sample.jpg | SROIE sample image shown in project media. |
| `de/de_groceryreceipt.jpg` | German | Receipt | https://ielanguages.com/real/German/images/groceryreceipt_jpg.jpg | Real-life German grocery receipt. |
| `de/de_gasreceipt.jpg` | German | Receipt | https://ielanguages.com/real/German/images/gasreceipt_jpg.jpg | Real-life German gas receipt. |
| `fr/fr_receipt.jpg` | French | Receipt | https://ielanguages.com/real/French/images/receipt_jpg.jpg | Real-life French receipt. |
| `fr/fr_receipt2.jpg` | French | Receipt | https://ielanguages.com/real/French/images/receipt2_jpg.jpg | Real-life French receipt. |
| `ja/ja_supermarket_clean.png` | Japanese | Receipt | https://github.com/K10124/japan-ocr-mini-benchmark-public | Synthetic clean Japanese supermarket receipt. |
| `ja/ja_restaurant_clean.png` | Japanese | Receipt | https://github.com/K10124/japan-ocr-mini-benchmark-public | Synthetic clean Japanese restaurant receipt. |
| `ja/ja_convenience_noisy.png` | Japanese | Receipt | https://github.com/K10124/japan-ocr-mini-benchmark-public | Synthetic noisy Japanese convenience-store receipt. |
| `zh/zh_taxi_0001.bmp` | Chinese | Taxi invoice | https://github.com/FuxiJia/InvoiceDatasets/raw/master/taxi_0001.jpg | Source file is named jpg upstream, but actual file content is BMP. |
| `zh/zh_vat_0001.jpg` | Chinese | VAT invoice | https://github.com/FuxiJia/InvoiceDatasets/raw/master/vat_0001.jpg | Public Chinese VAT invoice dataset sample. |
| `es/es_factura_sencilla.png` | Spanish | Invoice | https://www.infointel.es/descargas/FacturaSencilla.pdf | Rendered from downloaded PDF at 180 DPI. |
| `es/es_invoice_receipt_3x.png` | Spanish | Invoice/receipt | https://online-billing-service.com/sample-invoice-pdf/invoice-and-receipt-3x-on-a4-%28usd%2Beur%29-spanish.pdf | Rendered from downloaded PDF at 180 DPI. |

## Source Notes

- SROIE repository license file is MIT. The dataset is commonly used for receipt OCR evaluation.
- Japan OCR Mini Benchmark states that its receipt images are fictional/synthetic and intended for OCR/VLM evaluation; its README states CC BY 4.0 for the public alpha payload.
- ielanguages images are public website realia; use for QA reference, not redistribution.
- Chinese InvoiceDatasets README describes public camera-captured taxi and VAT invoice datasets for text detection and key-word spotting.
- Spanish PDFs are retained in `_sources/` so the rendered PNGs can be reproduced.

## Suggested QA Pass

For each image:

1. Import from Photos/files and confirm the app accepts the file type.
2. Run OCR and confirm text is not empty.
3. Check whether merchant/title, date, total amount, currency/tax keywords, and language-specific text are captured.
4. Check category suggestion and amount parsing.
5. Save the receipt and reopen details to confirm persistence.

