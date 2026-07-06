-- IPL SQL Analysis
-- Dataset: IPL Matches & Deliveries

CREATE DATABASE ipl_analysis;
USE ipl_analysis;
select * from deliveries LIMIT 5;

-- Q1: Highest Run Scorer.

-- Logic Used:
-- - Calculate total runs scored by each batter.
-- - Group records by batter.
-- - Sort players by total runs in descending order.
-- - Return the highest run-scorers in IPL history.

SELECT 
	batter,
    SUM(batsman_runs) as batsman_total_runs
from deliveries
group by batter
order by batsman_total_runs DESC
LIMIT 1;
	
-- Question 2:
-- Find the Top 10 batsmen with the highest number of sixes in IPL history.

-- Logic Used:
-- - Count every delivery where the batter scored six runs.
-- - Group records by batter.
-- - Calculate total sixes hit by each player.
-- - Rank batters by highest number of sixes.

SELECT
	batter,
    COUNT(*) as total_six
from deliveries
WHERE batsman_runs = 6
group by batter
order by total_six DESC
LIMIT 10;

-- Question3:
-- Find the top 10 bowlers with the highest number of wickets in IPL history.

-- Logic Used:
-- - Count only wickets credited to the bowler.
-- - Exclude run out, retired hurt and obstructing the field dismissals.
-- - Group records by bowler.
-- - Rank bowlers by total wickets taken.

SELECT 
	bowler,
    SUM(is_wicket) as total_wickets
from deliveries
WHERE dismissal_kind NOT IN ('run out', 'retired hurt', 'obstructing the field')
group by bowler
order by total_wickets DESC
LIMIT 10;

-- Question 4:
-- Find the Top 10 bowlers with the best economy rate in IPL history.

-- Logic Used:
-- - Count only legal deliveries to calculate overs bowled.
-- - Calculate runs conceded by excluding byes and leg byes.
-- - Filter bowlers with a sufficient sample size.
-- - Rank bowlers by lowest economy rate.


WITH bowler_stats AS (
    SELECT
        bowler,
        SUM(total_runs -
            CASE
                WHEN extras_type IN ('byes', 'legbyes')
                THEN extra_runs
                ELSE 0
            END
        ) AS runs_conceded,
        SUM(
            CASE
                WHEN extras_type IN ('wides', 'noballs')
                THEN 0
                ELSE 1
            END
        ) AS legal_balls

    FROM deliveries
    GROUP BY bowler
)

SELECT
    bowler,
    runs_conceded,
    ROUND(legal_balls / 6.0, 1) AS overs,
    ROUND(runs_conceded / (legal_balls / 6.0), 2) AS economy

FROM bowler_stats
WHERE (legal_balls / 6.0) >= 100
ORDER BY economy ASC
LIMIT 10;

-- Question 5:
-- Find the Orange Cap Winner for each IPL season.
-- Return: season, batter, total_runs.

-- Logic Used:
-- - Join deliveries with matches to get season information.
-- - Calculate total runs scored by each batter in every season.
-- - Use DENSE_RANK() to rank batters based on total runs.
-- - Return the player with Rank = 1 for each season.
WITH batter_stats AS (
    SELECT
        d.batter,
        m.season,
        SUM(d.batsman_runs) AS season_runs,
        SUM(CASE
                WHEN d.extras_type = 'wides' THEN 0
                ELSE 1 END
        ) AS balls_faced,
        ROUND(
            (SUM(d.batsman_runs) * 100.0) /
            SUM(CASE
                    WHEN d.extras_type = 'wides' THEN 0
                    ELSE 1 END
            ),
            2
        ) AS strike_rate
    FROM deliveries d
    JOIN matches m
        ON m.id = d.match_id
    GROUP BY
        m.season,
        d.batter
)
SELECT
    season,
    batter,
    season_runs,
    strike_rate
FROM (
    SELECT *,
           DENSE_RANK() OVER (
               PARTITION BY season
               ORDER BY season_runs DESC,
                        strike_rate DESC
           ) AS orange_cap_rank
    FROM batter_stats
) t
WHERE orange_cap_rank = 1
ORDER BY season;

-- Question6:
-- Find the Most Improved Batter in IPL history.
-- Compare each batter's runs with their previous season.
-- Return: season, batter, season_runs, previous_season_runs, improvement

-- Logic Used:
-- - Calculate runs and strike rate for every batter in each season.
-- - Use the LAG() function to compare current season runs with the previous season.
-- - Measure improvement season by season.
-- - Rank players based on performance growth.

WITH season_runs AS(
	SELECT
		d.batter,
        m.season,
		SUM(d.batsman_runs) AS runs,
        SUM(CASE
                WHEN d.extras_type = 'wides' THEN 0
                ELSE 1 END
        ) AS balls_faced,
        ROUND(
            (SUM(d.batsman_runs) * 100.0) /
            SUM(CASE
                    WHEN d.extras_type = 'wides' THEN 0
                    ELSE 1 END
            ),
            2
        ) AS strike_rate
	FROM deliveries d
    JOIN matches m
        ON m.id = d.match_id
    GROUP BY
        m.season,
        d.batter
),
improvements AS(
		SELECT 
			*,
            LAG(runs) OVER (
				PARTITION BY batter
                ORDER BY season
			) AS previous_runs
		FROM season_runs
)
SELECT 
	season,
    batter,
    runs,
    previous_runs,
    runs - previous_runs AS improvement
FROM improvements
WHERE previous_runs IS NOT NULL 
AND (runs - previous_runs) > 0
ORDER BY improvement DESC;

-- Question7:
-- Find the Top 10 Death Overs Specialists.
-- Death Overs: 16-20
-- Return: bowler, economy, wickets
-- Consider only bowlers who have bowled at least 200 legal deliveries in death overs.

-- Logic Used:
-- - Consider only overs 16–20.
-- - Calculate legal deliveries, wickets and runs conceded.
-- - Filter bowlers with a minimum sample size.
-- - Rank bowlers by lowest economy rate.


WITH death_stats AS (
	SELECT 
		bowler,
        SUM(
			CASE
				WHEN extras_type IN ('wides', 'noballs') THEN 0
					ELSE 1
				END
		) AS legal_balls,
        SUM(batsman_runs +
				CASE WHEN extras_type IN ('wides','noballs') THEN extra_runs
					 ELSE 0
                     END
		) AS run_conceded,
        SUM(
			CASE WHEN is_wicket = 1
             AND dismissal_kind NOT IN (
                 'run out',
                 'retired hurt',
                 'obstructing the field'
             )
				THEN 1
				ELSE 0
		END
	   ) AS wickets
FROM deliveries 
WHERE `over` BETWEEN 16 AND 20
GROUP BY bowler
HAVING legal_balls >= 200
						
)
SELECT
    bowler,
    run_conceded,
    wickets,
    ROUND(legal_balls / 6.0, 1) AS overs,
    ROUND(run_conceded / (legal_balls / 6.0), 2) AS economy 
FROM death_stats
ORDER BY economy ASC
LIMIT 10;

-- Question8:
-- Find the Top 10 Best Finishers in IPL History.
-- Death Overs: 16-20
-- Return:batter,runs,balls_faced,sixes,strike_rate
-- Consider only batters who have faced at least 250 legal deliveries in death overs.

-- Logic Used:
-- - Filter batting performances from overs 16–20.
-- - Calculate runs, sixes, legal balls and strike rate.
-- - Keep only batters with enough balls faced.
-- - Rank finishers based on strike rate.

WITH best_finisher AS (
	SELECT
		batter,
        SUM(batsman_runs) AS runs,
        SUM(CASE
				WHEN extras_type IN( 'wides','noballs') THEN 0
					ELSE 1
				END) AS ball_faced,
		SUM(CASE
				WHEN batsman_runs = 6 THEN 1
                ELSE 0 
			END) AS sixes,
		ROUND(
			(SUM(batsman_runs) * 100.0) / 
            SUM(CASE
				WHEN extras_type IN( 'wides','noballs') THEN 0
					ELSE 1
				END) ,2
			) AS strike_rate
		FROM deliveries
        WHERE `over` BETWEEN 16 AND 20
        GROUP BY batter
        HAVING ball_faced >= 250
)
SELECT
	batter,
	runs,
	ball_faced,
	sixes,
	strike_rate
FROM best_finisher
ORDER BY
    strike_rate DESC,
    runs DESC,
    sixes DESC
LIMIT 10;

-- Question9:
-- Find the Top 10 Powerplay Bowlers.
-- Overs 1-6
-- Return: bowler,wickets,economy
-- Minimum 300 legal deliveries.

-- Logic Used:
-- - Consider only overs 1–6.
-- - Calculate wickets, legal deliveries and runs conceded.
-- - Filter bowlers with sufficient legal deliveries.
-- - Rank bowlers using wickets and economy.
 
WITH best_powerplay_bowlers AS (
	SELECT 
		bowler,
        SUM(
			CASE WHEN extras_type IN ('wides','noballs') THEN 0
				ELSE 1
			END) AS legal_balls,
		SUM(batsman_runs +
					CASE WHEN extras_type IN ('wides','noballs') THEN extra_runs
						ELSE 0
					END) AS run_conceded,
		SUM(
			CASE WHEN is_wicket = 1
             AND dismissal_kind NOT IN (
                 'run out',
                 'retired hurt',
                 'obstructing the field'
             )
				THEN 1
				ELSE 0
		END
	   ) AS wickets
	FROM deliveries
    WHERE `over` BETWEEN 1 AND 6
    GROUP BY bowler
    HAVING legal_balls >= 300
)
SELECT 
	bowler,
    legal_balls,
    run_conceded,
    wickets,
    ROUND(legal_balls / 6.0, 1) AS overs,
    ROUND(run_conceded / (legal_balls / 6.0), 2) AS economy 
FROM best_powerplay_bowlers
ORDER BY 
		wickets DESC,
        economy ASC
LIMIT 10;


-- Question10:
-- Find the Purple Cap Winner for Every IPL Season.
-- Return:
-- season
-- bowler
-- wickets
-- legal_balls
-- economy


-- Logic Used:
-- - Join deliveries with matches to identify each season.
-- - Count only bowler-attributed wickets (exclude run out, retired hurt, obstructing the field).
-- - Calculate bowling economy using legal deliveries and runs conceded.
-- - Use DENSE_RANK() to find the highest wicket-taker in every season.

WITH purple_cap AS (
	SELECT 
		d.bowler,
        m.season,
        SUM(
			CASE WHEN extras_type IN ('wides','noballs') THEN 0
					ELSE 1
				END) AS legal_balls,
		SUM(
            batsman_runs +
            CASE
                WHEN extras_type IN ('wides','noballs') THEN extra_runs
                ELSE 0
            END
        ) AS run_conceded,
		
		SUM(
			CASE WHEN is_wicket = 1
             AND dismissal_kind NOT IN (
                 'run out',
                 'retired hurt',
                 'obstructing the field'
             )
				THEN 1
				ELSE 0
		END) AS wickets
       FROM deliveries d
       JOIN matches m
        ON m.id = d.match_id
	   GROUP BY
			m.season,
			d.bowler
	   HAVING legal_balls >= 120
 )
SELECT 
	bowler,
	wickets,
    legal_balls,
    ROUND(legal_balls / 6.0, 1) AS overs,
    ROUND(run_conceded / (legal_balls / 6.0), 2) AS economy
FROM (
    SELECT *,
           DENSE_RANK() OVER (
               PARTITION BY season
               ORDER BY wickets DESC,
                       (run_conceded / (legal_balls / 6.0)) ASC
           ) AS purple_cap_rank
    FROM purple_cap
) t
WHERE purple_cap_rank = 1
ORDER BY season;

-- Question11:
-- Find the Top 10 Best All-Rounders in IPL History.
-- Return:
-- player,
-- runs,
-- batting_strike_rate,
-- wickets,
-- bowling_economy

-- Logic Used:
-- - Create separate batting and bowling statistics using CTEs.
-- - Calculate batting strike rate and bowling economy.
-- - Filter players with at least 1000 runs and 50 wickets.
-- - Join both CTEs and rank players based on overall all-round performance.

WITH batting_stats AS (
	SELECT 
		batter,
        SUM(batsman_runs) AS runs,
        SUM(
			CASE WHEN extras_type IN ('wides','noballs') THEN 0
					ELSE 1
			END) legal_balls,
		ROUND(
			(SUM(batsman_runs) * 100.0) / 
            SUM(CASE
				WHEN extras_type IN( 'wides','noballs') THEN 0
					ELSE 1
				END) ,2
			) AS strike_rate
	FROM deliveries
    GROUP BY batter
    HAVING runs >= 1000
),
bowling_stats AS (
	SELECT
		d.bowler,
        SUM(
			CASE WHEN extras_type IN ('wides','noballs') THEN 0
					ELSE 1
				END) AS legal_balls,
		SUM(
            batsman_runs +
            CASE
                WHEN extras_type IN ('wides','noballs') THEN extra_runs
                ELSE 0
            END
        ) AS run_conceded,
		
		SUM(
			CASE WHEN is_wicket = 1
             AND dismissal_kind NOT IN (
                 'run out',
                 'retired hurt',
                 'obstructing the field'
             )
				THEN 1
				ELSE 0
		END) AS wickets
	FROM deliveries d
    JOIN matches m
		ON m.id = d.match_id
	GROUP BY bowler
    HAVING wickets >= 50
)
SELECT 
	b.batter,
    b.runs,
    b.strike_rate,
    bw.wickets,
    ROUND(bw.run_conceded / (bw.legal_balls / 6.0), 2) AS economy
FROM batting_stats b
JOIN bowling_stats bw
    ON b.batter = bw.bowler
ORDER BY 
	b.runs DESC,
    bw.wickets DESC;