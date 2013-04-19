-- PostgreSQL Tuning 101
--
-- November 15, 2012
-- Ruby on Rails Lightning Talks
-- matt@apartmentlist.com


-- Part 1
-- Getting the numbers

-- They say you should make sure that Postgres memory is large enough to host your active data set. How do you
-- know it is large enough? Lets assume you know how much memory you have, so the next question is how large
-- is you active data set.

-- How large is your total data set?

select pg_database_size('de2nq092qkqfxll');
select pg_size_pretty(pg_database_size('de2nq092qkqfxll'));

-- How large is your table?

select pg_size_pretty(pg_relation_size('communities'));

-- Same thing works for indexes of all types (Btree, Gin, Gist)

select pg_size_pretty(pg_relation_size('index_communities_on_coordinates'));

-- How large is your table with all the indexes combined?

select pg_size_pretty(pg_total_relation_size('communities'));

-- Show 10 largest tables or indices

select relname, relpages from pg_class order by relpages desc limit 10;


-- Even if all your data fits in memory, if Postgres needs to sort through thousands entries for each query
-- it will be slow. This is where indices come in.

-- More advanced version of the above. Show top 10 largest tables and percentage of index usage. Note, that
-- unlike the above queries, this query need to be run on live queries to be useful.

select
  relname,
  100.0 * idx_scan / (seq_scan + idx_scan) percent_of_times_index_used,
  n_live_tup rows_in_table
from
  pg_stat_user_tables
where
    seq_scan + idx_scan > 0
order by
  n_live_tup desc
limit 10;


-- Just because you think you have enough memory, doesn't mean Postgres agree. We can check what actually is going
-- on by performing some statistics queries.

-- What is your Index cache hit rate? If this is not in upper 90's you are in trouble.

select
  sum(idx_blks_read) as idx_read,
  sum(idx_blks_hit)  as idx_hit,
  (sum(idx_blks_hit) - sum(idx_blks_read)) / sum(idx_blks_hit) as ratio
FROM
  pg_statio_user_indexes;

-- What is your Table cache hit rate? This depends on an application, there is no golden rule for good/bad.

select
  sum(heap_blks_read) as heap_read,
  sum(heap_blks_hit)  as heap_hit,
  (sum(heap_blks_hit) - sum(heap_blks_read)) / sum(heap_blks_hit) as ratio
from
  pg_statio_user_tables;


-- Finally an "Oh Crap" scenario. My db is super slow RIGHT NOW. What the hell is it doing?

select procpid, query_start, current_query from pg_stat_activity order by procpid;

-- The following usually follows the above :)

select pg_cancel_backend(procpid);
select pg_cancel_backend(procpid)
   from pg_stat_activity
   where current_query like '%your giant accidental query%';

-- Heroku extras
-- https://github.com/quarterdome/heroku-pg-extras
-- Most of the above commands wrapped into




-- Part 2
-- Some basic tips on fixing the numbers

-- Prerequisite: Use indices. No matter how you tune the rest, if you do not use indices it will be slow.

create index index_communities_for_search btree (community_id);

-- A tip, add indices concurrently. Pro: no table lock. Cons: longer, can't be run from transaction (e.g. Rails
-- migration).

create index concurrently index_communities_for_search btree (community_id);

-- Make your indices partial indices when possible. Less data leads to smaller active data set.

create index index_communities_for_search btree (id)
 where active and not over_limit and has_photo;

-- Cluster a table on an index. Will help with the Range queries.

cluster communities on index_communities_for_search;


-- Credits

-- http://postgres.heroku.com/blog
-- http://www.thegeekstuff.com/2009/05/15-advanced-postgresql-commands-with-examples/
-- http://craigkerstiens.com/2012/10/01/understanding-postgres-performance/
-- https://devcenter.heroku.com/articles/cache-size
