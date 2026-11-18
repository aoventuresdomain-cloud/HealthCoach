# S5 · Amazon basket spike: the link test (N11, Planner part)

Status 18 Nov: **not proven, and it doesn't look worth building now. The recommendation is to keep the top-up list and leave the basket deferred.** This is a desk test only. The Researcher's staples list is in `s5-amazon-staples.md`.

## What N11 had to answer

1. Does a single multi-item link open amazon.co.uk with the right items and quantities in the basket, without a paid service?
2. Does fresh delivery reach W2?

## 1. The multi-item cart link

**The mechanism.** Amazon's only documented way to put several items in a customer's basket from outside Amazon is the "Add to Cart form", a GET to the marketplace's cart-add page:

```
…/gp/aws/cart/add.html?ASIN.1=<asin>&Quantity.1=<n>&ASIN.2=<asin>&Quantity.2=<n>…&AssociateTag=<tag>&AWSAccessKeyId=<key>
```

- Each item is `ASIN.x` (or `OfferListingId.x`) plus `Quantity.x`, where `x` is 1, 2 and so on. The documentation says "any number of items" and gives no stated limit.
- `AssociateTag` and `AWSAccessKeyId` are both listed as **required**.
- The customer lands on Amazon and checks out themselves, which is what N11 wanted.

**Why it doesn't clear the bar:**

- **It needs an account in the CEO's name.** The required `AssociateTag` means an Amazon Associates account. That account is free, but it is an account in the CEO's name, which the gap plan routes through the Setup Desk. `AWSAccessKeyId` is a Product Advertising API key.
- **The API behind it is being retired.** PA-API 5 is now deprecated in favour of the "Creators API", and calls to it return 403. Amazon's deprecation page doesn't say whether the cart form survives. So even with an account, the link's future is uncertain.
- **Leaving the key out isn't a safe route.** Older third-party write-ups suggest the form sometimes works without the tag. That is undocumented, so it could stop at any time, and the app shouldn't depend on it.
- **It wasn't run live.** This environment can't reach amazon.co.uk: the network proxy refuses the host. That is the same block the Researcher hit when mapping ASINs. No real ASINs are mapped yet either (`s5-amazon-staples.md`).

**Verdict on 1: not proven, and the documented route needs an account plus an API that is being retired.** That fails the "no paid service, no account without the CEO's go-ahead" bar as it stands.

## 2. Fresh delivery to W2

- Amazon's same-day fresh groceries (fruit and veg, meat, fish, dairy, bread, eggs and frozen) launched on 4 June 2026 in "parts of Central and East London", with more postcodes "in the coming months".
- No membership is needed. Prime members get free delivery over £20; everyone else pays £5.99.
- Amazon's page doesn't list postcodes, and doesn't name W2, Paddington or Westminster.

**Verdict on 2: unknown for W2.** Settling it means typing the postcode on amazon.co.uk, a 1-minute check on a machine that can reach the site.

## Recommendation

- **Keep the top-up list**: search links to the chosen shop (N4) and Reminders (N5). It works today, costs nothing and needs no account.
- **Keep the basket deferred.** Revisit it only if the CEO wants Amazon specifically and is happy to open a free Associates account through the Setup Desk. Even then, build it only after a live test of the cart link on amazon.co.uk with three real ASINs, plus the W2 postcode check. That would take about 30 minutes on a phone or laptop, plus the 20-minute ASIN mapping in `s5-amazon-staples.md`.
- Nothing is built in the app for N11. Without the basket, no code would have a user.

## If it is ever picked up

- **The link.** The link builder is a pure function in CoachCore: the week's staples (from `ShoppingList.week`, filtered to items with a mapped ASIN) become `ASIN.n` and `Quantity.n` pairs. Quantities are rounded up to whole packs.
- **Privacy.** Only ASINs and quantities leave the phone (gap plan §4.7): no names, calories or health data.
- **The test.** A unit test checks the URL shape, and the manual live test above decides whether it ships.

Sources: [Add to Cart form (PA-API 5 docs)](https://webservices.amazon.co.jp/paapi5/documentation/add-to-cart-form.html), [PA-API 5 deprecation](https://affiliate-program.amazon.com/creatorsapi/docs/en-us/paapiv5-deprecation), [Amazon same-day fresh groceries in London, 4 June 2026](https://www.aboutamazon.com/news/retail/amazon-grocery-same-day-delivery-uk), [Retail Gazette, June 2026](https://www.retailgazette.co.uk/blog/2026/06/amazon-expands-same-day-fresh-grocery-delivery-after-fresh-store-closures/).
