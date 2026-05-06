# supabase/policies/

Source-of-truth RLS policy SQL files for review. Each `*.sql` file in this
directory is the authoring copy of the policies for one table.

Policy bodies are inlined into `<timestamp>_enable_rls_default.sql` at apply
time per research [R-02](../../specs/004-supabase-foundation/research.md#r-02--migration-filenames-ordering-and-policy-bundling).
Later phases that change a policy do so by editing the file here AND shipping
a new migration that re-applies it via `DROP POLICY IF EXISTS … CREATE POLICY …`.
