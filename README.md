# Hackathon_2025
GymPulse Analytics with AI is a project that leverages Snowflake's Cortex Large Language Models (LLMs) to analyze customer reviews of a gym. It uses AI-driven sentiment analysis to classify reviews as positive, negative, or neutral, extracts relevant tags (e.g., "coach," "treadmill"), assesses the urgency of issues (immediate, can hold, or no action), and categorizes negative reviews as highly or slightly negative. By processing review data within Snowflake's secure environment, the project provides actionable insights to improve gym operations and customer satisfaction.

## Files in this Repository

- [`vw_analyzed_review.sql`](vw_analyzed_review.sql): SQL scripts to create the `raw_review` table and the `analyzed_review` view, which uses Snowflake Cortex models to analyze gym reviews for sentiment, urgency, and categorized tags.

---

## `analyzed_review` View Documentation

The `analyzed_review` view processes raw gym review text and uses Snowflake Cortex AI models to extract sentiment, urgency, and detailed aspect tags for each review.

### Source Table

- **`raw_review`**
  - `review` (VARCHAR): The original review text.
  - `studio_id` (VARCHAR): Identifier for the gym/studio.
  - `source` (VARCHAR): Source of the review.

### Output Columns

| Column Name        | Type    | Description                                                                                                 |
|--------------------|---------|-------------------------------------------------------------------------------------------------------------|
| `review`           | VARCHAR | The original review text.                                                                                   |
| `studio_id`        | VARCHAR | Identifier for the gym/studio.                                                                              |
| `sentiment_score`  | FLOAT   | Sentiment score from Snowflake Cortex (`-1` = negative, `1` = positive).                                    |
| `sentiment_tier`   | STRING  | Categorized sentiment: Strongly Negative, Negative, Slightly Critical, Slightly Positive, etc.              |
| `urgency_analysis` | STRING  | Structured AI output: `URGENCY: [level]|REASON: [explanation]|ACTION: [recommendation]`.                   |
| `urgency_level`    | STRING  | Simplified urgency: High, Medium, or Low.                                                                   |
| `categorized_tags` | STRING  | Raw AI output with tags for each aspect (7 lines, one per aspect).                                          |
| `cleaned_tags`     | STRING  | Cleaned, concatenated tags for each aspect (one per line, fallback to "None" if not present).               |
| `studio_exp`       | INT     | 1 if studio experience tags found, else 0.                                                                  |
| `class_exp`        | INT     | 1 if class experience tags found, else 0.                                                                   |
| `coach_exp`        | INT     | 1 if coach tags found, else 0.                                                                              |
| `staff`            | INT     | 1 if studio staff tags found, else 0.                                                                       |
| `price`            | INT     | 1 if pricing tags found, else 0.                                                                            |
| `equipment`        | INT     | 1 if equipment tags found, else 0.                                                                          |
| `injury`           | INT     | 1 if injury tags found, else 0.                                                                             |

### Tagging Categories

- **STUDIO EXPERIENCE:** Atmosphere, cleanliness, crowding.
- **CLASS EXPERIENCE:** Classes, workouts, results.
- **COACH:** Coaching, instruction.
- **STUDIO STAFF:** Staff behavior, communication, policies.
- **PRICING:** Cost, fees, value.
- **EQUIPMENT:** Equipment, monitors, technology.
- **INJURY:** Injury mentions.

### Example Output (exludes the `review` column, and some intermediate columns)

|STUDIO_ID|SENTIMENT_TIER     |URGENCY_LEVEL|STUDIO_EXP|CLASS_EXP|COACH|STAFF|EQUIPMENT|
|---------|-------------------|-------------|----------|---------|-----|-----|---------|
|1192     |Highly Positive    |High         |1         |1        |1    |1    |0        |
|2097     |Strongly Negative  |Medium       |0         |0        |0    |1    |0        |
|14373    |Negative           |Medium       |0         |0        |1    |0    |0        |
|1164     |Slightly Critical  |Medium       |1         |1        |1    |1    |0        |
|3101     |Slightly Critical  |Medium       |0         |1        |0    |1    |1        |
|2160     |Slightly Critical  |Medium       |0         |1        |1    |0    |0        |
|2368     |Highly Positive    |Low          |1         |1        |1    |1    |1        |
|2154     |Moderately Positive|Low          |1         |1        |1    |1    |0        |
|2976     |Negative           |Low          |0         |0        |0    |0    |0        |
|2897     |Negative           |Low          |1         |1        |0    |1    |0        |
|1222     |Slightly Critical  |Low          |1         |0        |0    |1    |0        |
|1964     |Slightly Critical  |Low          |0         |0        |0    |1    |0        |
|1974     |Moderately Positive|Low          |1         |1        |1    |1    |1        |
|2160     |Moderately Positive|Low          |1         |1        |0    |1    |0        |
|2357     |Moderately Positive|Low          |1         |1        |1    |1    |0        |
