\# MindBloom Recommendation System Documentation



\## 1. Overview



MindBloom contains a therapist recommendation system whose purpose is to rank suitable therapists for a client according to the client's preferences, assessment information, therapist profile data, availability, ratings and previous interactions with the platform.



The recommendation system uses a \*\*Weighted Content-Based Filtering\*\* approach.



The system is deterministic and explainable. It does not use a trained machine-learning model, collaborative filtering model, neural network or probabilistic prediction model. Instead, it represents the client through a preference profile and therapists through profile/content features. Each supported feature produces a normalized match contribution, which is multiplied by a predefined weight.



The weighted contributions are added into a final score in the range \*\*0–100\*\*, which directly represents the recommendation match percentage.



\---



\## 2. Algorithm



\### Algorithm name



\*\*Weighted Content-Based Filtering\*\*



\### Recommender type



\*\*Content-based recommender with weighted feature scoring\*\*



The algorithm compares characteristics of a therapist with characteristics and preferences associated with the current client.



A therapist is represented through features such as:



\- specialization;

\- therapy approaches;

\- profile text relevant to assessment focus areas;

\- weekly availability;

\- session price;

\- professional experience;

\- average rating;

\- overall availability;

\- previous appointment history;

\- favorite status.



The client profile is created from stored onboarding preferences and, where supported, values supplied in the recommendation request.



Each matching criterion produces a partial score. The partial scores are combined into one final recommendation score.



\---



\## 3. Reason for choosing the algorithm



Weighted Content-Based Filtering was selected because therapist recommendation is primarily based on the compatibility between an individual client's requirements and the properties of available therapists.



This approach is appropriate for MindBloom because:



1\. recommendations can be generated without requiring a large historical interaction dataset;

2\. new clients can receive recommendations immediately after providing onboarding preferences;

3\. new therapists can participate in recommendations based on their profile information;

4\. individual recommendation factors can be explicitly weighted;

5\. the result is deterministic;

6\. every awarded point can be explained to the client;

7\. changes in client preferences can immediately affect the recommendation result.



Explainability is particularly important in MindBloom because recommendations concern the selection of a mental-health professional. Therefore, the system avoids presenting the result as an unexplained prediction.



\---



\## 4. Input data



The recommendation engine combines three main groups of information.



\### 4.1 Client profile data



Stored client preferences may include:



\- preferred therapist gender;

\- preferred session type;

\- preferred languages;

\- minimum session price;

\- maximum session price;

\- assessment focus areas;

\- preferred days;

\- preferred therapy approaches.



These preferences are primarily collected during client onboarding.



\### 4.2 Recommendation request data



A recommendation request may additionally contain:



\- preferred specialization IDs;

\- preferred therapy approach IDs;

\- assessment focus areas;

\- preferred days;

\- maximum price per session;

\- minimum therapist experience;

\- maximum number of recommendations to return.



For therapy approaches, assessment focus areas and preferred days, request values are used when supplied. Otherwise, stored client preferences are used as fallback values.



For maximum price, the request value has priority over the stored client maximum price.



\### 4.3 Therapist data and behavioral signals



The engine uses therapist and interaction data including:



\- therapist specialization;

\- therapy approaches;

\- biography;

\- specialization description;

\- session price;

\- years of experience;

\- weekly availability;

\- reviews and ratings;

\- whether the client previously booked the therapist;

\- whether the therapist is currently in the client's favorites.



\---



\## 5. Candidate filtering



Recommendation is performed only after candidate therapists have been filtered.



A therapist must:



\- not be soft-deleted;

\- belong to an active user;

\- belong to a user who is not blocked;

\- have an approved/verified therapist status.



Stored client preferences are also used as hard compatibility filters.



Depending on the client's saved preferences, therapists can be excluded based on:



\- therapist gender;

\- online/in-person session type;

\- preferred languages;

\- minimum session price;

\- maximum session price.



For language filtering, at least one therapist language must overlap with the client's preferred languages.



This filtering phase prevents clearly incompatible therapists from reaching the ranking phase.



\---



\## 6. Scoring model



For every remaining therapist, the engine calculates a weighted content-based score.



The general formula is:



```text

TotalScore =

&#x20;   SpecializationScore

&#x20; + TherapyApproachScore

&#x20; + AssessmentScore

&#x20; + PreferredDaysScore

&#x20; + PriceScore

&#x20; + ExperienceScore

&#x20; + RatingScore

&#x20; + AvailabilityScore

&#x20; + PreviousAppointmentScore

&#x20; + FavoriteScore

```



The final result is clamped to:



```text

0 <= TotalScore <= 100

```



The configured maximum weights are:



| Criterion | Maximum points | Weight |

|---|---:|---:|

| Specialization | 15 | 15% |

| Therapy approach | 10 | 10% |

| Assessment focus | 15 | 15% |

| Preferred days | 15 | 15% |

| Price | 10 | 10% |

| Experience | 10 | 10% |

| Rating | 10 | 10% |

| Availability | 10 | 10% |

| Previous appointment | 3 | 3% |

| Favorite | 2 | 2% |

| \*\*Total\*\* | \*\*100\*\* | \*\*100%\*\* |



The weights intentionally sum to 100. Therefore, the score can directly be interpreted as a match percentage.



\---



\## 7. Specialization score



Maximum contribution:



```text

15 points

```



If the client selected one or more preferred specialization IDs and the therapist has one of those specializations:



```text

SpecializationScore = 15

```



Otherwise:



```text

SpecializationScore = 0

```



If no specialization preference was supplied, the engine assigns a neutral value:



```text

SpecializationScore = 10

```



This prevents the absence of an optional specialization preference from automatically treating all therapists as poor matches.



\---



\## 8. Therapy approach score



Maximum contribution:



```text

10 points

```



Therapy approaches use proportional set overlap.



Let:



```text

matchingApproaches =

&#x20;   number of client's preferred approaches

&#x20;   supported by the therapist

```



Then:



```text

matchRatio =

&#x20;   matchingApproaches / numberOfPreferredApproaches



TherapyApproachScore =

&#x20;   10 \* matchRatio

```



The ratio is limited to the interval `\[0, 1]`.



Example:



```text

Preferred approaches: 2

Matching approaches: 1



matchRatio = 1 / 2 = 0.5

TherapyApproachScore = 10 \* 0.5 = 5

```



If no therapy approach preference is available, a neutral score of:



```text

5 points

```



is assigned.



\---



\## 9. Assessment focus score



Maximum contribution:



```text

15 points

```



Assessment focus areas are normalized and compared against therapist profile content composed from:



\- specialization;

\- specialization name;

\- specialization description;

\- biography.



Text normalization trims values and converts them to lowercase.



For each requested assessment focus area, the engine checks whether the normalized therapist profile contains that focus area.



The score is proportional to the number of matching areas:



```text

matchRatio =

&#x20;   matchedAssessmentAreas / requestedAssessmentAreas



AssessmentScore =

&#x20;   15 \* matchRatio

```



The ratio cannot exceed `1`.



If no assessment focus areas are available, a neutral score of:



```text

7.5 points

```



is used.



\---



\## 10. Preferred days score



Maximum contribution:



```text

15 points

```



The system compares the client's preferred days with the therapist's configured weekly availability.



The formula is:



```text

matchingDays =

&#x20;   therapistAvailableDays ∩ clientPreferredDays



ratio =

&#x20;   matchingDays.Count / preferredDays.Count



PreferredDaysScore =

&#x20;   15 \* ratio

```



Example:



```text

Preferred days:

Monday, Wednesday, Friday



Therapist available:

Monday, Wednesday, Thursday



Matching days:

Monday, Wednesday



ratio = 2 / 3

PreferredDaysScore = 15 \* 2/3 = 10

```



If the client did not specify preferred days:



\- therapist with configured weekly availability receives `7.5` points;

\- therapist without configured weekly availability receives `0` points.



\---



\## 11. Price score



Maximum contribution:



```text

10 points

```



The therapist's `PricePerSession` is used when it is greater than zero. Otherwise, `HourlyRate` is used.



When no valid maximum price preference exists, the therapist receives a neutral:



```text

5 points

```



If:



```text

therapistPrice <= maximumPrice

```



the therapist receives:



```text

10 points

```



For a therapist above the maximum price, the scoring function itself supports a gradual reduction:



```text

differenceRatio =

&#x20;   (therapistPrice - maximumPrice) / maximumPrice



PriceScore =

&#x20;   10 \* max(0, 1 - differenceRatio)

```



However, in the current recommendation pipeline, the client's effective maximum price is also used during candidate filtering. Therefore, therapists above that effective maximum price are normally excluded before ranking.



This distinction is important: the price scoring function supports proportional scoring, while the current candidate-filtering policy enforces the effective client price range as a hard compatibility constraint.



\---



\## 12. Experience score



Maximum contribution:



```text

10 points

```



When the client specifies minimum required experience and the therapist satisfies it:



```text

ExperienceScore = 10

```



If the therapist has less experience:



```text

ratio =

&#x20;   therapistExperienceYears / minimumExperienceYears



ExperienceScore =

&#x20;   10 \* clamp(ratio, 0, 1)

```



When no minimum experience preference exists, experience is normalized against ten years:



```text

ExperienceScore =

&#x20;   10 \* min(1, therapistExperienceYears / 10)

```



Therefore:



```text

0 years  -> 0 points

5 years  -> 5 points

10 years -> 10 points

15 years -> 10 points

```



\---



\## 13. Rating score



Maximum contribution:



```text

10 points

```



Only non-deleted reviews whose ratings are between `1` and `5` participate in the average.



If a therapist has no valid reviews:



```text

RatingScore = 0

```



Otherwise:



```text

RatingScore =

&#x20;   10 \* clamp(AverageRating / 5, 0, 1)

```



Examples:



```text

Average rating 5.0 -> 10 points

Average rating 4.0 -> 8 points

Average rating 3.5 -> 7 points

```



The number of reviews is exposed in the recommendation result and explanation, but it does not independently change the rating weight.



\---



\## 14. Availability score



Maximum contribution:



```text

10 points

```



The availability score represents how many distinct days per week the therapist has configured availability.



The formula is:



```text

AvailabilityScore =

&#x20;   10 \* clamp(AvailableDayCount / 7, 0, 1)

```



Examples:



```text

0 available days -> 0 points

3 available days -> approximately 4.29 points

7 available days -> 10 points

```



This criterion differs from the preferred-days criterion:



\- \*\*Preferred days\*\* measures compatibility with the client's selected schedule.

\- \*\*Availability\*\* measures the therapist's overall weekly availability.



\---



\## 15. Previous appointment signal



Maximum contribution:



```text

3 points

```



If the client has previously had an appointment record with the therapist:



```text

PreviousAppointmentScore = 3

```



Otherwise:



```text

PreviousAppointmentScore = 0

```



The signal represents previous interaction between the client and therapist.



It is intentionally assigned a relatively small weight so that previous interaction can influence ranking without overriding stronger compatibility factors.



\---



\## 16. Favorite signal



Maximum contribution:



```text

2 points

```



If the therapist is currently in the client's favorites:



```text

FavoriteScore = 2

```



Otherwise:



```text

FavoriteScore = 0

```



Favorite status acts as a lightweight behavioral preference signal.



Its weight is intentionally small so that adding a therapist to favorites cannot dominate specialization, assessment compatibility, schedule, price or other major recommendation factors.



\---



\## 17. Normalization



The recommendation engine does not perform dataset-wide statistical normalization such as z-score normalization or min-max normalization across the therapist population.



Instead, each scoring criterion is individually bounded by its configured maximum contribution.



Examples include:



```text

averageRating / 5

availableDays / 7

experienceYears / requiredExperience

matchingDays / preferredDays

matchingApproaches / preferredApproaches

```



These ratios are constrained where necessary to the range `\[0, 1]` and multiplied by the criterion's maximum weight.



Text values used for assessment matching are normalized by:



\- removing surrounding whitespace;

\- converting text to lowercase.



Duplicate preference values are also removed where appropriate.



\---



\## 18. Explanation system



The recommendation system is explicitly explainable.



Every scoring criterion creates a `RecommendationReasonDto` containing:



```text

Criterion

AwardedPoints

MaximumPoints

Explanation

```



For example:



```text

Criterion: Experience

AwardedPoints: 10

MaximumPoints: 10

Explanation:

"The therapist has 10 years of experience and meets your preference."

```



The explanation entries are sorted by awarded points in descending order.



This makes it possible to inspect not only the final score but also the contribution of every recommendation criterion.



The sum of the individual awarded scoring contributions represents the final score before final rounding/clamping rules.



\---



\## 19. Match percentage



The final decimal score is rounded to two decimal places.



Example:



```text

Score = 82.43

```



The integer match percentage is calculated by rounding the total score using:



```text

MidpointRounding.AwayFromZero

```



Example:



```text

Score = 82.43

MatchPercentage = 82

```



Because the maximum scoring weights total exactly 100 points, no additional percentage conversion is required.



\---



\## 20. Sorting and deterministic behavior



Recommendations are sorted using the following deterministic ordering:



```text

1\. Score descending

2\. AverageRating descending

3\. ExperienceYears descending

4\. PricePerSession ascending

5\. TherapistId ascending

```



The therapist identifier is the final tie-breaker.



Therefore, therapists with otherwise identical ranking values still have a stable ordering.



The algorithm does not use:



\- randomness;

\- stochastic sampling;

\- model inference;

\- time-dependent random values.



For the same database state, client profile and recommendation request, the system therefore returns the same recommendation ordering and scores.



\---



\## 21. Preference changes



The recommendation engine is responsive to changes in client preferences.



For example, if a client's stored maximum session price changes from:



```text

150

```



to:



```text

70

```



a therapist whose session price is `120` may be removed from the candidate set, while an affordable therapist remains.



The recommendation result is therefore recalculated from the current client profile rather than being permanently cached as a static recommendation.



\---



\## 22. Cold-start behavior



\### New client



The system supports client cold-start without requiring historical appointments, ratings or favorites.



A new client can receive recommendations using:



\- onboarding preferences;

\- assessment focus areas;

\- preferred therapy approaches;

\- schedule preferences;

\- price preferences;

\- therapist profile information.



When optional preferences are missing, defined neutral scores are used for several criteria instead of automatically assigning zero.



Examples:



```text

No specialization preference -> 10 / 15

No therapy approach preference -> 5 / 10

No assessment focus -> 7.5 / 15

No maximum price -> 5 / 10

```



For preferred days, a therapist with configured availability receives a neutral `7.5 / 15` when the client did not specify preferred days.



\### New therapist



A new therapist can also participate in recommendations without previous appointments or favorites.



Such a therapist receives:



```text

Previous appointment = 0 / 3

Favorite = 0 / 2

```



A therapist without reviews receives:



```text

Rating = 0 / 10

```



However, the therapist can still receive points from profile-based criteria such as specialization, therapy approach, assessment compatibility, price, experience and availability.



This reduces the classic interaction-history cold-start problem.



\---



\## 23. Fallback behavior



Fallback is implemented through a combination of:



1\. stored client preferences;

2\. request-level preferences;

3\. neutral scores when optional preference information is unavailable;

4\. profile-based therapist signals that do not depend on user history.



Request preferences have priority for supported fields, while stored onboarding preferences provide fallback values where implemented.



The recommendation endpoint also limits the number of returned recommendations:



```text

Default: 10

Maximum: 50

```



If a requested `Take` value is less than or equal to zero, the default value is used. Values above 50 are capped at 50.



\---



\## 24. Example recommendation calculation



Consider a simplified therapist/client match with the following contributions:



| Criterion | Result | Points |

|---|---|---:|

| Specialization | exact match | 15 / 15 |

| Therapy approach | 1 of 2 preferred approaches | 5 / 10 |

| Assessment focus | 2 of 3 focus areas | 10 / 15 |

| Preferred days | 2 of 3 preferred days | 10 / 15 |

| Price | within budget | 10 / 10 |

| Experience | meets minimum | 10 / 10 |

| Rating | average 4.5 / 5 | 9 / 10 |

| Availability | 4 of 7 days | 5.71 / 10 |

| Previous appointment | yes | 3 / 3 |

| Favorite | yes | 2 / 2 |



The total score is:



```text

15

\+ 5

\+ 10

\+ 10

\+ 10

\+ 10

\+ 9

\+ 5.71

\+ 3

\+ 2

= 79.71

```



Therefore:



```text

Score = 79.71

MatchPercentage = 80%

```



The recommendation response additionally contains an explanation entry for every criterion showing the awarded points, maximum points and human-readable reason.



This is an illustrative calculation using the actual scoring formulas and configured weights.



\---



\## 25. Testing



The recommendation system is covered by unit and integration tests.



The behavior tests verify important algorithmic properties including:



\### Determinism



The same input is processed twice and the test verifies identical:



\- therapist order;

\- therapist IDs;

\- scores;

\- match percentages;

\- explanation criteria;

\- awarded points;

\- maximum points;

\- explanation text.



\### Explanation



Tests verify that recommendation reasons:



\- exist;

\- contain a criterion;

\- contain explanation text;

\- have non-negative awarded points;

\- do not exceed their maximum score.



\### Score validity



Tests verify:



```text

0 <= Score <= 100

```



and confirm that the match percentage corresponds to the rounded score.



A test also verifies that, for its controlled setup, the sum of explanation contributions equals the final recommendation score.



\### Sorting



Tests verify that stronger matches are ordered before weaker matches and that recommendations are sorted by score descending.



\### Preference sensitivity



Tests modify a stored client preference and verify that the recommendation result changes accordingly.



\### Candidate filtering



Existing recommendation tests additionally verify that only approved and active therapists are returned and that price constraints can exclude therapists.



\### API security



Integration tests verify that:



\- unauthenticated users cannot access recommendations;

\- therapist-role users cannot access the client recommendation endpoint;

\- authenticated clients can successfully request recommendations.



\---



\## 26. Limitations



The current implementation intentionally favors transparency and deterministic behavior over model complexity.



Important limitations are:



1\. \*\*No trained ML model\*\*  

&#x20;  The system does not learn weights automatically from historical outcomes.



2\. \*\*Static weights\*\*  

&#x20;  The criterion weights are predefined in the application rather than learned separately for each client.



3\. \*\*Simple assessment text matching\*\*  

&#x20;  Assessment focus areas use normalized substring matching against therapist profile text rather than semantic embeddings or NLP similarity.



4\. \*\*No collaborative filtering\*\*  

&#x20;  Recommendations do not use patterns such as "clients similar to this client preferred these therapists."



5\. \*\*No automatic feedback learning\*\*  

&#x20;  Favorites and previous appointments influence the current score, but the system does not retrain itself based on those interactions.



6\. \*\*Rating confidence is not modeled\*\*  

&#x20;  A therapist's average rating affects the score, while review count is exposed in the result but is not used as a separate confidence adjustment.



7\. \*\*Availability uses day-level information\*\*  

&#x20;  The ranking uses distinct available weekdays rather than detailed real-time appointment-slot density.



8\. \*\*Price is also a hard filter\*\*  

&#x20;  The current pipeline can exclude therapists outside the client's effective stored/requested price range before the price scoring function is evaluated.



These limitations are acceptable for the current scope because the primary goal is to provide explainable, deterministic and preference-sensitive therapist recommendations.



\---



\## 27. Classification of the system



The MindBloom recommender should be described as:



> \*\*An explainable weighted content-based recommendation system with deterministic multi-feature scoring and lightweight behavioral signals.\*\*



It should \*\*not\*\* be described as:



\- a trained machine-learning model;

\- collaborative filtering;

\- a neural-network recommender;

\- AI prediction;

\- deep learning.



The algorithm belongs to the family of \*\*content-based recommendation approaches\*\*, because recommendation is primarily calculated from similarity/compatibility between a user's preference profile and therapist content/profile features.



Previous appointments and favorites are additional behavioral signals, but they do not change the fundamental content-based nature of the recommender.



\---



\## 28. Summary



MindBloom uses Weighted Content-Based Filtering to recommend therapists.



The algorithm:



\- builds recommendation criteria from client preferences;

\- evaluates therapist profile/content features;

\- filters incompatible candidates;

\- calculates ten weighted scoring components;

\- normalizes individual components to predefined ranges;

\- combines them into a score between 0 and 100;

\- generates a human-readable explanation for every scoring criterion;

\- applies deterministic tie-breaking;

\- supports clients and therapists with little or no interaction history;

\- responds immediately to preference changes.



The resulting system prioritizes transparency, reproducibility and explainability while remaining suitable for the available MindBloom dataset and application scope.

