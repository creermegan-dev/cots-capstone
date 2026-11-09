begin;

-- PostgREST invokes this gate as the caller before entering the worker RPCs.
-- BYPASSRLS does not grant schema USAGE or function EXECUTE. The gate already
-- accepts service-role requests and retains its trusted-device checks for users.
grant usage on schema cots_private to service_role;
grant execute on function cots_private.check_request() to service_role;

commit;
