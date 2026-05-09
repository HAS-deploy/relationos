# App Privacy (nutrition label) answers — RelationOS

> The App Privacy nutrition label is the ONE thing Apple still makes you
> click through by hand (Stage 8). This file is the answer sheet — when
> you're clicking, this is what to type. Reviewers compare these answers
> to the code, the privacy policy, and the risk profile. Mismatches =
> rejection.

## Top-level question

**Do you or your third-party partners collect data from this app?**

- [ ] **No, we do not collect data from this app.**
      Choose this if and only if:
      - The app has no accounts + no signed-in users
      - No analytics SDK (no Firebase, no PostHog, no Mixpanel, no Amplitude)
      - No crash-reporting SDK (no Sentry, no Crashlytics)
      - No third-party ad networks
      - No user-generated content sent to any server
      - OAuth tokens stored locally for BYOK use do not count as "collected"

- [ ] **Yes, we or our partners collect data.**
      Answer the data-type matrix below.

**For RelationOS: Yes, we collect data.** PostHog is wired (canonical portfolio pattern; same key as 12 sibling apps). Privacy-strict configuration — no person profiles, no session replay, no screen views, no app lifecycle events. Anonymous events only.

### Required answers in ASC App Privacy questionnaire

Click "Yes, we collect data," then answer the matrix exactly as below:

#### Identifiers
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| User ID | **Yes** (PostHog assigns a random per-install identifier) | **No** (not linked to real-user identity) | **No** | Analytics |
| Device ID | No | — | — | — |
| Advertising ID (IDFA) | No | — | — | — |

#### Usage data
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Product interaction | **Yes** (paywall taps, feature taps) | **No** | **No** | Analytics |
| Advertising data | No | — | — | — |
| Other usage data | No | — | — | — |

#### Diagnostics
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Crash data | **Yes** (PostHog crash diagnostics) | **No** | **No** | App functionality, Analytics |
| Performance data | No | — | — | — |
| Other diagnostic data | No | — | — | — |

All other categories: **Not Collected.** No name/email/phone, no health, no financial, no location, no contacts (the user's iPhone contacts are read on-device only — never transmitted), no user content (notes/tags stay on-device), no browsing/search history, no purchase history (StoreKit-managed, not collected by us), no environment/body, no sensitive info.

**Apple Tracking Transparency:** the app is NOT tracking — no IDFA, no cross-app/website linkage. Do NOT request the ATT prompt.

---

## If "Yes" — data type matrix

For every data type below, answer:
1. Is it collected? (yes/no)
2. Is it **linked** to the user's identity? (yes/no)
3. Is it used for **tracking** (cross-app/website tracking per ATT)? (yes/no)
4. What purposes? (analytics, app functionality, product personalization, etc.)

### Contact info
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Name |  |  |  |  |
| Email |  |  |  |  |
| Phone |  |  |  |  |
| Physical address |  |  |  |  |

### Health & fitness
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Health (HealthKit) |  |  |  |  |
| Fitness (motion/activity) |  |  |  |  |

### Financial
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Payment info |  |  |  |  |
| Credit info |  |  |  |  |

### Location
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Precise location |  |  |  |  |
| Coarse location |  |  |  |  |

### Sensitive info
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Sensitive info (e.g. ethnicity, orientation, health) |  |  |  |  |

### Contacts
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Contacts |  |  |  |  |

### User content
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Emails or text messages |  |  |  |  |
| Photos or videos |  |  |  |  |
| Audio |  |  |  |  |
| Gameplay content |  |  |  |  |
| Customer support |  |  |  |  |
| Other user content |  |  |  |  |

### Browsing history
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Browsing history |  |  |  |  |

### Search history
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Search history |  |  |  |  |

### Identifiers
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| User ID |  |  |  |  |
| Device ID |  |  |  |  |
| Advertising ID (IDFA) |  |  |  |  |

### Purchases
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Purchase history |  |  |  |  |

### Usage data
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Product interaction |  |  |  |  |
| Advertising data |  |  |  |  |
| Other usage data |  |  |  |  |

### Diagnostics
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Crash data |  |  |  |  |
| Performance data |  |  |  |  |
| Other diagnostic data |  |  |  |  |

### Surroundings / body
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Environment scanning |  |  |  |  |
| Hands |  |  |  |  |
| Head |  |  |  |  |

### Other
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Other |  |  |  |  |

---

## Consistency self-check

Apple's reviewer will cross-reference these answers against:

1. `docs/apple-review-risk-profile.md` section 5 (data table) — they must match
2. `docs/privacy.html` — "What the app collects" section must match
3. `privacy-sdk-audit.py` output — declared SDK privacy manifests must match
4. Code — `grep -r` for analytics calls, keychain access, URLSession to
   external hosts. Every `POST` / `PUT` / `PATCH` off the device is a "yes"
   for *some* data type.

If any of the four disagrees with the matrix above, fix the matrix first,
then propagate the fix.
