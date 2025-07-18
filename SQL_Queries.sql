/*
	Creating the table
*/
CREATE TABLE IF NOT EXISTS public."Trips_Information"
(
    trip_id integer NOT NULL,
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    bike_id integer,
    trip_duration decimal,
    from_station_id integer,
    from_station_name text COLLATE pg_catalog."default",
    to_station_id integer,
    to_station_name text COLLATE pg_catalog."default",
    user_type character varying COLLATE pg_catalog."default",
    gender character varying COLLATE pg_catalog."default",
    birth_year integer,
    CONSTRAINT "Trips_Information_pkey" PRIMARY KEY (trip_id)
)

/* 
	Fixing the records where the end date was before the start date.
	We use a temporary table to store the affected records IDs and end_time
	Then, we update the original table, adding a extra hour to the end_time and using these IDs for comparison in the WHERE clause	
*/
CREATE TEMP TABLE Temp_Trips (
	trip_id SERIAL PRIMARY KEY,
    end_time timestamp without time zone
);

INSERT INTO Temp_Trips (trip_id, end_time)
	SELECT trip_id, end_time FROM public."Trips_Information"
	WHERE end_time < start_time

SELECT * FROM Temp_Trips

SELECT * FROM public."Trips_Information"
WHERE trip_id IN (SELECT trip_id FROM Temp_Trips)

UPDATE public."Trips_Information" AS ti
	SET end_time = tt.end_time + interval '1 hour'
	FROM Temp_Trips AS tt
	WHERE ti.trip_id = tt.trip_id

/* 
	Check if all the records were fixed - the following query should return zero
*/
SELECT COUNT(*) FROM public."Trips_Information"
WHERE end_time < start_time

/*
	Adding columns:
	ride_length - the total length of the ride in the HH:MM:SS format
	day_of week - the day of the week that the ride happened, in number format (0 = Sunday, 6 = Saturday
*/

ALTER TABLE public."Trips_Information"
	ADD COLUMN ride_length time,
	ADD COLUMN day_of_week integer;

UPDATE public."Trips_Information" 
	SET ride_length = trip_duration * interval '1 sec'
		day_of_week = extract(dow from start_time);

/*
	Analysis queries
*/

/*
	Finding out the average ride length and the most common day for the casual and annual members
*/
SELECT user_type, AVG(ride_length) AS avg_ride_length, mode() WITHIN GROUP(order by day_of_week) AS most_common_day
	FROM public."Trips_Information" GROUP BY user_type

/*
	Finding out how many users of each type use the bike service during each day of the weekend
*/
SELECT user_type, AVG(ride_length) AS avg_ride_length, COUNT(user_type), day_of_week
	FROM public."Trips_Information" 
		GROUP BY day_of_week, user_type
			ORDER BY user_type, day_of_week

/*
	Finding out gender and birth year averages for each type of user
*/
SELECT user_type, COUNT(user_type), gender, CAST(AVG(birth_year) AS integer)
	FROM public."Trips_Information"
		WHERE gender IS NOT NULL
			GROUP BY user_type, gender