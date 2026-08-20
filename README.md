# Shakti Vyavhar v1.8.0

Digital Khata + Bhavya voice assistant, with strict Customer/Supplier separation.

## Included
- Separate Customer and Supplier tabs.
- Customer balance, supplier payable balance and transaction history.
- Multiple business profiles with business-isolated customers, transactions and stock.
- Bhavya Hindi/Hinglish/English speech commands.
- Multi-word Hindi name extraction and pronunciation-tolerant matching.
- Tap-to-start / tap-to-stop speech recognition with partial-result recovery.
- Indian Hindi TTS selection with female voice preference when the installed engine exposes one.
- WhatsApp/SMS customer payment reminders.
- Supplier-only material/order WhatsApp/SMS reminders.
- Customer-only UPI collection with saved business UPI ID support.
- Customer-only PDF statement, invoice, GST invoice and print.
- Date-filtered reports, PDF report sharing and CSV export.
- Inventory/stock manager with business-scoped stock adjustments.
- Backup/restore with validation and safe restore order.
- Supplied Shakti Vyavhar branding/logo/icon.

## Production boundary
The app does **not** fake SaaS infrastructure. Real login, automatic multi-device cloud sync and ₹299/year Play Store/App Store billing need a production backend and store billing configuration. The codebase is local-first and backup-safe until those credentials/configuration are supplied.


## Bhavya v1.8 Advanced Conversation Engine
- Conversation context remembers the last resolved customer/supplier for follow-up commands.
- Commands such as "isme 50000 credit karo", "usko reminder bhejo", and "uska balance batao" can use the previous party.
- Multi-word party names can be followed by `ko`, `ka`, `ke`, `mein`, `me`, `se`, etc.
- Indian amount phrases such as `50 hazaar`, `1 lakh`, `2 crore` are converted correctly.
- Hindi/Hinglish/English confirmations (`haan`, `yes`, `kar do`, `cancel`) are supported for sensitive financial voice actions.
- Duplicate financial commands are protected by a pending-confirmation state.
- Pronunciation-tolerant matching remains active for Hindi/Indian STT variants.
- The app version shown in Settings is synchronized with the package version (1.8.0).
