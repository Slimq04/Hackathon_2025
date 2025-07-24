USE WAREHOUSE DBT_HACKATHON_DEV;
USE ROLE DEV_HACKATHON_RW;
USE DATABASE ORANGE_ZONE_DEV_HACKATHON;

-- create table
CREATE or replace TABLE orange_zone_dev_hackathon.gympulse_ai.raw_review (
    review VARCHAR(16777216),
    studio_id VARCHAR,
    source VARCHAR
);

select * from orange_zone_dev_hackathon.gympulse_ai.raw_review;


-- The view ddl
CREATE or replace VIEW orange_zone_dev_hackathon.gympulse_ai.analyzed_review AS
SELECT review,
       studio_id,
       snowflake.cortex.sentiment(review)  AS sentiment_score,
-- 1. Polarization
       CASE
            WHEN ROUND(sentiment_score, 2) <= -0.7 THEN 'Strongly Negative'
            WHEN ROUND(sentiment_score, 2) <= -0.3 THEN 'Negative'
            WHEN ROUND(sentiment_score, 2) <= -0.01 THEN 'Slightly Critical'
            WHEN ROUND(sentiment_score, 2) <= 0.3 THEN 'Slightly Positive'
            WHEN ROUND(sentiment_score, 2) <= 0.7 THEN 'Moderately Positive'
            WHEN ROUND(sentiment_score, 2) <= 1 THEN 'Highly Positive'
            ELSE 'Neutral'
       END AS sentiment_tier,
-- 2. Urgency
      snowflake.cortex.complete(
        'mistral-large2',
        CONCAT(
            'Analyze the urgency of this review and provide a structured response in this exact format: ',
            'URGENCY: [Critical/Moderate/Low]|REASON: [brief explanation]|ACTION: [recommended action] ',
            '\n\nCritical Urgency criteria: ',
            '- Safety concerns, injuries, or health hazards ',
            '- Equipment defects or failures causing immediate risk ',
            '- Urgent refund demands or billing fraud claims ',
            '- Legal threats or discrimination claims ',
            '- Keywords: "urgent", "immediately", "emergency", "danger", "injured", "lawsuit", "fraudulent charge" ',
            '\n\nModerate Urgency criteria: ',
            '- Service failures requiring timely resolution ',
            '- Billing disputes or unexpected charges ',
            '- Staff misconduct or poor customer service ',
            '- Keywords: "disappointed", "unacceptable", "need resolution", "charged incorrectly" ',
            '\n\nLow Urgency criteria: ',
            '- General feedback or suggestions ',
            '- Praise or positive experiences ',
            '- Minor inconveniences ',
            '\n\nReview: "', review, '"'
        )
    ) AS urgency_analysis,
      CASE WHEN SPLIT_PART(urgency_analysis, '|', 1) ilike '%Low%' then 'Low' WHEN SPLIT_PART(urgency_analysis, '|', 1) ilike '%Moderate%' then 'Medium' else 'High' END AS urgency_level,
-- 3. Tags
       snowflake.cortex.complete(
               'mistral-large2',
               CONCAT(
                       'Analyze EVERY aspect of this review and assign ALL applicable tags.\n',
                       'IMPORTANT: Check for BOTH positive AND negative mentions in each category.\n\n',
                       'Output format (exactly 7 lines):\n',
                       'STUDIO EXPERIENCE: [tags or None]\n',
                       'CLASS EXPERIENCE: [tags or None]\n',
                       'COACH: [tags or None]\n',
                       'STUDIO STAFF: [tags or None]\n',
                       'PRICING: [tags or None]\n',
                       'EQUIPMENT: [tags or None]\n',
                       'INJURY: [tags or None]\n\n',
                       'Instructions for each category:\n',
                       '- STUDIO_EXPERIENCE: Look for mentions of atmosphere, cleanliness, crowding\n',
                       '  Tags: Motivating Atmosphere, Clean Studio, Dirty Studio, Overcrowded\n\n',

                       '- CLASS_EXPERIENCE: Look for ANY mention of classes, workouts, results\n',
                       '  Positive tags: Great Workout, Effective Results\n',
                       '  Negative tags: Overwhelming Classes, Too Intense, No Results\n',
                       '  NOTE: "classes are good" = Great Workout\n\n',

                       '- COACH: Look for mentions of coaching, instruction\n',
                       '  Tags: Excellent Coaching, Poor Instruction\n\n',

                       '- STUDIO_STAFF: Look for mentions of staff behavior, communication, policies, employee mentions\n',
                       '  Tags: Friendly Staff, Professional Trainers, Responsive Support, Rude Staff, Unprofessional Behavior, Poor Communication, Pushy Sales\n',
                       '  NOTE: Poor policy communication = Poor Communication\n\n',

                       '- PRICING: Look for mentions of cost, fees, charges, value\n',
                       '  Tags: Worth the Cost, Good Value, Fair Pricing, Too Expensive, Hidden Fees, Billing Issues, Not Worth It\n\n',

                       '- EQUIPMENT: Look for mentions of equipment, monitors, technology\n',
                       '  Tags: Quality Equipment, Well-Maintained, Good Technology, Broken Equipment, Inaccurate Monitors, Technical Issues\n\n',

                       '- INJURY: Look for injury mentions\n',
                       '  Tags: Injury Concerns\n\n',
                       'Review: "', review, '"\n\n',
                       'Use EXACTLY the format shown in the example. Remember: Tag ALL aspects mentioned, both positive and negative. Return should be EITHER tags OR leave empty!'
               )
       ) AS categorized_tags,
       CONCAT_WS('\n',
                 COALESCE(REGEXP_SUBSTR(categorized_tags, 'STUDIO EXPERIENCE:[^\\n]+'), 'STUDIO EXPERIENCE: None'),
                 COALESCE(REGEXP_SUBSTR(categorized_tags, 'CLASS EXPERIENCE:[^\\n]+'), 'CLASS EXPERIENCE: None'),
                 COALESCE(REGEXP_SUBSTR(categorized_tags, 'COACH:[^\\n]+'), 'COACH: None'),
                 COALESCE(REGEXP_SUBSTR(categorized_tags, 'STUDIO STAFF:[^\\n]+'), 'STUDIO STAFF: None'),
                 COALESCE(REGEXP_SUBSTR(categorized_tags, 'PRICING:[^\\n]+'), 'PRICING: None'),
                 COALESCE(REGEXP_SUBSTR(categorized_tags, 'EQUIPMENT:[^\\n]+'), 'EQUIPMENT: None'),
                 COALESCE(REGEXP_SUBSTR(categorized_tags, 'INJURY:[^\\n]+'), 'INJURY: None')
       )                                                                                AS cleaned_tags,

       CASE WHEN SPLIT_PART(cleaned_tags, '\n', 1) NOT ILIKE '%None%' THEN 1 ELSE 0 END AS studio_exp,
       CASE WHEN SPLIT_PART(cleaned_tags, '\n', 2) NOT ILIKE '%None%' THEN 1 ELSE 0 END AS class_exp,
       CASE WHEN SPLIT_PART(cleaned_tags, '\n', 3) NOT ILIKE '%None%' THEN 1 ELSE 0 END AS coach_exp,
       CASE WHEN SPLIT_PART(cleaned_tags, '\n', 4) NOT ILIKE '%None%' THEN 1 ELSE 0 END AS staff,
       CASE WHEN SPLIT_PART(cleaned_tags, '\n', 5) NOT ILIKE '%None%' THEN 1 ELSE 0 END AS price,
       CASE WHEN SPLIT_PART(cleaned_tags, '\n', 6) NOT ILIKE '%None%' THEN 1 ELSE 0 END AS equipment,
       CASE WHEN SPLIT_PART(cleaned_tags, '\n', 7) NOT ILIKE '%None%' THEN 1 ELSE 0 END AS injury
FROM orange_zone_dev_hackathon.gympulse_ai.raw_review
ORDER BY CASE urgency_level WHEN'High' THEN 1
                            WHEN 'Medium' THEN 2
                            WHEN 'Low' THEN 3
                            ELSE 4 END ASC,
         CASE sentiment_tier WHEN'Strongly Negative' THEN 1
                          WHEN 'Negative' THEN 2
                          WHEN 'Slightly Critical' THEN 3
                          WHEN 'Slightly Positive' THEN 4
                          WHEN 'Moderately Positive' THEN 5
                          WHEN 'Highly Positive' THEN 6
                          ELSE 7 END ASC;
--     SPLIT_PART(review_tags, '.', 1) AS tags,


select *
FROM orange_zone_dev_hackathon.gympulse_ai.analyzed_review where studio_id = 2357 ;


select 'The hearrate monitor is too expensive. Coach is high energey, helpful and encouraging. The studio is clean. I enjoy the overall workout. The equipment is high quality. The coach or staff address my concerns. I liked the music selection. The studio staff is friendly, welcoming. enjoy the energizing fun atmosphere. I enjoy the mix or cardio and strength training. I recieve clear, satisfactory instructions. I push myself harder here. The coach corrects my form. I appreciate the physical and mental benefits. The pre-workout instruction was helpful. ' as review,
       snowflake.cortex.complete(
        'mistral-7b',
    CONCAT(
        'Analyze EVERY aspect of this review and assign ALL applicable tags.\n',
        'IMPORTANT: Check for BOTH positive AND negative mentions in each category.\n\n',

        'Output format (exactly 7 lines):\n',
        'STUDIO EXPERIENCE: [tags, if no tags found then "None"]\n',
        'CLASS EXPERIENCE: [tags , if no tags found then "None"]\n',
        'COACH: [tags , if no tags found then "None"]\n',
        'STUDIO STAFF: [tags , if no tags found then "None"]\n',
        'PRICING: [tags , if no tags found then "None"]\n',
        'EQUIPMENT: [tags , if no tags found then "None"]\n',
        'INJURY: [tags , if no tags found then "None"]\n\n',

        'Instructions for each category:\n',
        '- STUDIO_EXPERIENCE: Look for mentions of atmosphere, cleanliness, crowding\n',
        '  Tags: Motivating Atmosphere, Clean Studio, Dirty Studio, Overcrowded\n\n',

        '- CLASS_EXPERIENCE: Look for ANY mention of classes, workouts, results\n',
        '  Positive tags: Great Workout, Effective Results\n',
        '  Negative tags: Overwhelming Classes, Too Intense, No Results\n',
        '  NOTE: "classes are good" = Great Workout\n\n',

        '- COACH: Look for mentions of coaching, instruction\n',
        '  Tags: Excellent Coaching, Poor Instruction\n\n',

        '- STUDIO_STAFF: Look for mentions of staff behavior, communication, policies, employee mentions\n',
        '  Tags: Friendly Staff, Professional Trainers, Responsive Support, Rude Staff, Unprofessional Behavior, Poor Communication, Pushy Sales\n',
        '  NOTE: Poor policy communication = Poor Communication\n\n',

        '- PRICING: Look for mentions of cost, fees, charges, value\n',
        '  Tags: Worth the Cost, Good Value, Fair Pricing, Too Expensive, Hidden Fees, Billing Issues, Not Worth It\n\n',

        '- EQUIPMENT: Look for mentions of equipment, monitors, technology\n',
        '  Tags: Quality Equipment, Well-Maintained, Good Technology, Broken Equipment, Inaccurate Monitors, Technical Issues\n\n',

        '- INJURY: Look for injury mentions\n',
        '  Tags: Injury Concerns\n\n',

        'Review: "', review, '"\n\n',
        'Use EXACTLY the format shown in the example. Remember: Tag ALL aspects mentioned, both positive and negative!'
    )
      ) AS categorized_tags;
