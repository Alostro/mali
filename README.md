# Mali 💸

A budget app made for how money works in South Africa: it runs **payday to payday** (not 1st to 31st), counts in rands, and knows about taxi fare, data, prepaid electricity, stokvels and money sent home.

## What it does

- **Home:** what's left until payday, how much is safe to spend per day, days until payday, each category's progress, and everything you logged this month.
- **Add:** type the amount, tap a category, done. Notes and dates are optional; tap any item to edit or delete it.
- **Insights:** a donut of where the money went, day-by-day bars against your daily allowance, and the biggest changes compared to the month before. Swipe back through older months with the arrows.
- **Budget:**
  - Your income and payday (e.g. the 25th). If payday lands on a weekend, Mali moves it to the Friday before, like most employers do.
  - A limit per category, or one tap on **Use last month** to set limits from your real spending.
  - Debit orders and fixed costs (phone contract, insurance, rent, stokvel), logged automatically on the day they go off.
- **Heads-ups:**
  - When a category hits 80% and when it goes over.
  - When you've used 80% of your money.
  - 3 days before payday, with what's left.
  - Payday morning.
  - An optional daily "log your spending" nudge.

Everything stays on your phone. No bank login, no accounts.

## Get the APK

1. Create a new GitHub repo called `mali` (empty, nothing ticked).
2. Push this folder:
   ```bash
   git init && git add . && git commit -m "Mali"
   git branch -M main
   git remote add origin https://github.com/<you>/mali.git
   git push -u origin main
   ```
3. Open **Actions → Build APK**. When it's green, download **Mali-apk**, unzip, and install `app-release.apk` on your phone.

## Build on your PC instead

```bash
flutter create --platforms=android --org com.dintle --project-name mali .
dart tool/setup_android.dart
flutter pub get
flutter build apk --release
```
