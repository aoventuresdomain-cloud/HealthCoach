# Weather swap (board M2-03)

On a day with an outdoor run, opening the app checks the forecast. Bad weather during the run's slot swaps it for the programme's indoor session of the same length (`indoorSwap` in the run's week). The slot, the wake time and the alarm stay exactly as planned. "I'll run anyway" is one tap and lasts for that day.

**Where.** `WeatherSwap.decide(day:programme:forecast:runAnyway:calendar:)` and `WeatherRule` in CoachCore (`Planner/Weather.swift`); `MorningWeather` in the app fetches and holds today's decision for Today.

**When it fetches.** Only on a day whose session is in `placementRules.outdoorSessions` and hasn't ended yet, on app open, at most every 30 minutes. Other days make no network call. The fetch runs after the alarm reconcile and never changes alarms. Once Today and the morning brief notification exist (M2-05), they read `MorningWeather.shared.decision`.

**Bad weather** is any hour that overlaps the session with:

| Reason | Threshold |
|---|---|
| Thunder | WMO codes 95, 96, 99 |
| Snow or ice | freezing drizzle or rain, snow, snow grains or showers (WMO 56, 57, 66, 67, 71, 73, 75, 77, 85, 86) |
| Wind | gusts of 60 km/h or more |
| Rain | 1.0 mm or more in the hour, with a 50% chance or more (amount alone when no chance is given) |
| Cold | −3 °C or below (icy paths) |

Drizzle under 1 mm/h is not bad weather: in London it would swap most runs. The note names the worst reason ("Rain forecast: indoor circuit instead, same time"). These thresholds are an engineering default for the Advisor to confirm.

**Offline.** No forecast, a failed fetch, a bad response or a forecast that doesn't cover the session's hours means no swap and no error (`.keep(.noForecast)`). A failed refetch keeps the morning's earlier forecast.

**Privacy.** Open-Meteo needs no key or account (£0). The request carries only the route's public coordinates (`RouteLocation.known`, Hyde Park), never the owner's location or any health data. The session is ephemeral, so nothing is cached on disk.

**Safety in the data.** Content validation fails if a run's indoor swap is longer than the run, so a swap can never need an earlier alarm.

**Tests.** `WeatherTests` (CoachCore) and `LaunchFlagsUITests.testRainSwapsTuesdaysRunIndoorsAndOfflineChangesNothing` (`-weather rain|dry|offline`; UI tests never use the network).
